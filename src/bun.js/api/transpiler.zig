const std = @import("std");
const Api = @import("../../api/schema.zig").Api;
const http = @import("../../http.zig");
const JavaScript = @import("../javascript.zig");
const QueryStringMap = @import("../../url.zig").QueryStringMap;
const CombinedScanner = @import("../../url.zig").CombinedScanner;
const bun = @import("bun");
const string = bun.string;
const JSC = @import("bun").JSC;
const js = JSC.C;
const WebCore = @import("../webcore/response.zig");
const Bundler = @import("../../bundler.zig");
const options = @import("../../options.zig");
const VirtualMachine = JavaScript.VirtualMachine;
const ScriptSrcStream = std.io.FixedBufferStream([]u8);
const ZigString = JSC.ZigString;
const Fs = @import("../../fs.zig");
const Base = @import("../base.zig");
const getAllocator = Base.getAllocator;
const JSObject = JSC.JSObject;
const JSError = Base.JSError;
const JSValue = JSC.JSValue;
const JSGlobalObject = JSC.JSGlobalObject;
const strings = @import("bun").strings;
const NewClass = Base.NewClass;
const To = Base.To;
const Request = WebCore.Request;

const FetchEvent = WebCore.FetchEvent;
const MacroMap = @import("../../resolver/package_json.zig").MacroMap;
const TSConfigJSON = @import("../../resolver/tsconfig_json.zig").TSConfigJSON;
const PackageJSON = @import("../../resolver/package_json.zig").PackageJSON;
const logger = @import("bun").logger;
const Loader = options.Loader;
const Platform = options.Platform;
const JSAst = @import("../../js_ast.zig");
const Transpiler = @This();
const JSParser = @import("../../js_parser.zig");
const JSPrinter = @import("../../js_printer.zig");
const ScanPassResult = JSParser.ScanPassResult;
const Mimalloc = @import("../../mimalloc_arena.zig");
const Runtime = @import("../../runtime.zig").Runtime;
const JSLexer = @import("../../js_lexer.zig");
const Expr = JSAst.Expr;

bundler: Bundler.Bundler,
arena: std.heap.ArenaAllocator,
transpiler_options: TranspilerOptions,
scan_pass_result: ScanPassResult,
buffer_writer: ?JSPrinter.BufferWriter = null,

pub const Class = NewClass(
    Transpiler,
    .{ .name = "Transpiler" },
    .{
        .scanImports = .{
            .rfn = scanImports,
        },
        .scan = .{
            .rfn = scan,
        },
        .transform = .{
            .rfn = transform,
        },
        .transformSync = .{
            .rfn = transformSync,
        },
        // .resolve = .{
        //     .rfn = resolve,
        // },
        // .buildSync = .{
        //     .rfn = buildSync,
        // },
        .finalize = finalize,
    },
    .{},
);

pub const Constructor = JSC.NewConstructor(
    @This(),
    .{
        .constructor = .{ .rfn = constructor },
    },
    .{},
);

const default_transform_options: Api.TransformOptions = brk: {
    var opts = std.mem.zeroes(Api.TransformOptions);
    opts.disable_hmr = true;
    opts.platform = Api.Platform.browser;
    opts.serve = false;
    break :brk opts;
};

const TranspilerOptions = struct {
    transform: Api.TransformOptions = default_transform_options,
    default_loader: options.Loader = options.Loader.jsx,
    macro_map: MacroMap = MacroMap{},
    tsconfig: ?*TSConfigJSON = null,
    tsconfig_buf: []const u8 = "",
    macros_buf: []const u8 = "",
    log: logger.Log,
    runtime: Runtime.Features = Runtime.Features{ .top_level_await = true },
    tree_shaking: bool = false,
    trim_unused_imports: ?bool = null,
};

// Mimalloc gets unstable if we try to move this to a different thread
// threadlocal var transform_buffer: bun.MutableString = undefined;
// threadlocal var transform_buffer_loaded: bool = false;

// This is going to be hard to not leak
pub const TransformTask = struct {
    input_code: ZigString = ZigString.init(""),
    protected_input_value: JSC.JSValue = @intToEnum(JSC.JSValue, 0),
    output_code: ZigString = ZigString.init(""),
    bundler: Bundler.Bundler = undefined,
    log: logger.Log,
    err: ?anyerror = null,
    macro_map: MacroMap = MacroMap{},
    tsconfig: ?*TSConfigJSON = null,
    loader: Loader,
    global: *JSGlobalObject,
    replace_exports: Runtime.Features.ReplaceableExport.Map = .{},

    pub const AsyncTransformTask = JSC.ConcurrentPromiseTask(TransformTask);
    pub const AsyncTransformEventLoopTask = AsyncTransformTask.EventLoopTask;

    pub fn create(transpiler: *Transpiler, protected_input_value: JSC.C.JSValueRef, globalThis: *JSGlobalObject, input_code: ZigString, loader: Loader) !*AsyncTransformTask {
        var transform_task = try bun.default_allocator.create(TransformTask);
        transform_task.* = .{
            .input_code = input_code,
            .protected_input_value = if (protected_input_value != null) JSC.JSValue.fromRef(protected_input_value) else @intToEnum(JSC.JSValue, 0),
            .bundler = undefined,
            .global = globalThis,
            .macro_map = transpiler.transpiler_options.macro_map,
            .tsconfig = transpiler.transpiler_options.tsconfig,
            .log = logger.Log.init(bun.default_allocator),
            .loader = loader,
            .replace_exports = transpiler.transpiler_options.runtime.replace_exports,
        };
        transform_task.bundler = transpiler.bundler;
        transform_task.bundler.linker.resolver = &transform_task.bundler.resolver;

        transform_task.bundler.setLog(&transform_task.log);
        transform_task.bundler.setAllocator(bun.default_allocator);
        return try AsyncTransformTask.createOnJSThread(bun.default_allocator, globalThis, transform_task);
    }

    pub fn run(this: *TransformTask) void {
        const name = this.loader.stdinName();
        const source = logger.Source.initPathString(name, this.input_code.slice());

        JSAst.Stmt.Data.Store.create(bun.default_allocator);
        JSAst.Expr.Data.Store.create(bun.default_allocator);

        var arena = Mimalloc.Arena.init() catch unreachable;

        const allocator = arena.allocator();

        defer {
            JSAst.Stmt.Data.Store.reset();
            JSAst.Expr.Data.Store.reset();
            arena.deinit();
        }

        this.bundler.setAllocator(allocator);
        const jsx = if (this.tsconfig != null)
            this.tsconfig.?.mergeJSX(this.bundler.options.jsx)
        else
            this.bundler.options.jsx;

        const parse_options = Bundler.Bundler.ParseOptions{
            .allocator = allocator,
            .macro_remappings = this.macro_map,
            .dirname_fd = 0,
            .file_descriptor = null,
            .loader = this.loader,
            .jsx = jsx,
            .path = source.path,
            .virtual_source = &source,
            .replace_exports = this.replace_exports,
            // .allocator = this.
        };

        const parse_result = this.bundler.parse(parse_options, null) orelse {
            this.err = error.ParseError;
            return;
        };

        if (parse_result.empty) {
            this.output_code = ZigString.init("");
            return;
        }

        var global_allocator = arena.backingAllocator();
        var buffer_writer = JSPrinter.BufferWriter.init(global_allocator) catch |err| {
            this.err = err;
            return;
        };
        buffer_writer.buffer.list.ensureTotalCapacity(global_allocator, 512) catch unreachable;
        buffer_writer.reset();

        // defer {
        //     transform_buffer = buffer_writer.buffer;
        // }

        var printer = JSPrinter.BufferPrinter.init(buffer_writer);
        const printed = this.bundler.print(parse_result, @TypeOf(&printer), &printer, .esm_ascii) catch |err| {
            this.err = err;
            return;
        };

        if (printed > 0) {
            buffer_writer = printer.ctx;
            buffer_writer.buffer.list.items = buffer_writer.written;

            var output = JSC.ZigString.init(buffer_writer.written);
            output.mark();
            this.output_code = output;
        } else {
            this.output_code = ZigString.init("");
        }
    }

    pub fn then(this: *TransformTask, promise: *JSC.JSPromise) void {
        if (this.log.hasAny() or this.err != null) {
            const error_value: JSValue = brk: {
                if (this.err) |err| {
                    if (!this.log.hasAny()) {
                        break :brk JSC.JSValue.fromRef(JSC.BuildError.create(
                            this.global,
                            bun.default_allocator,
                            logger.Msg{
                                .data = logger.Data{ .text = std.mem.span(@errorName(err)) },
                            },
                        ));
                    }
                }

                break :brk this.log.toJS(this.global, bun.default_allocator, "Transform failed");
            };

            promise.reject(this.global, error_value);
            return;
        }

        finish(this.output_code, this.global, promise);

        if (@enumToInt(this.protected_input_value) != 0) {
            this.protected_input_value = @intToEnum(JSC.JSValue, 0);
        }
        this.deinit();
    }

    noinline fn finish(code: ZigString, global: *JSGlobalObject, promise: *JSC.JSPromise) void {
        promise.resolve(global, code.toValueGC(global));
    }

    pub fn deinit(this: *TransformTask) void {
        var should_cleanup = false;
        defer if (should_cleanup) bun.Global.mimalloc_cleanup(false);

        this.log.deinit();
        if (this.input_code.isGloballyAllocated()) {
            this.input_code.deinitGlobal();
        }

        if (this.output_code.isGloballyAllocated()) {
            should_cleanup = this.output_code.len > 512_000;
            this.output_code.deinitGlobal();
        }

        bun.default_allocator.destroy(this);
    }
};

fn exportReplacementValue(value: JSValue, globalThis: *JSGlobalObject) ?JSAst.Expr {
    if (value.isBoolean()) {
        return Expr{
            .data = .{
                .e_boolean = .{
                    .value = value.toBoolean(),
                },
            },
            .loc = logger.Loc.Empty,
        };
    }

    if (value.isNumber()) {
        return Expr{
            .data = .{
                .e_number = .{ .value = value.asNumber() },
            },
            .loc = logger.Loc.Empty,
        };
    }

    if (value.isNull()) {
        return Expr{
            .data = .{
                .e_null = .{},
            },
            .loc = logger.Loc.Empty,
        };
    }

    if (value.isUndefined()) {
        return Expr{
            .data = .{
                .e_undefined = .{},
            },
            .loc = logger.Loc.Empty,
        };
    }

    if (value.isString()) {
        var str = JSAst.E.String{
            .data = std.fmt.allocPrint(bun.default_allocator, "{}", .{value.getZigString(globalThis)}) catch unreachable,
        };
        var out = bun.default_allocator.create(JSAst.E.String) catch unreachable;
        out.* = str;
        return Expr{
            .data = .{
                .e_string = out,
            },
            .loc = logger.Loc.Empty,
        };
    }

    return null;
}

fn transformOptionsFromJSC(ctx: JSC.C.JSContextRef, temp_allocator: std.mem.Allocator, args: *JSC.Node.ArgumentsSlice, exception: JSC.C.ExceptionRef) !TranspilerOptions {
    var globalThis = ctx.ptr();
    const object = args.next() orelse return TranspilerOptions{ .log = logger.Log.init(temp_allocator) };
    if (object.isUndefinedOrNull()) return TranspilerOptions{ .log = logger.Log.init(temp_allocator) };

    args.eat();
    var allocator = args.arena.allocator();

    var transpiler = TranspilerOptions{
        .default_loader = .jsx,
        .transform = default_transform_options,
        .log = logger.Log.init(allocator),
    };
    transpiler.log.level = .warn;

    if (!object.isObject()) {
        JSC.throwInvalidArguments("Expected an object", .{}, ctx, exception);
        return transpiler;
    }

    if (object.getIfPropertyExists(ctx.ptr(), "define")) |define| {
        define: {
            if (define.isUndefinedOrNull()) {
                break :define;
            }

            if (!define.isObject()) {
                JSC.throwInvalidArguments("define must be an object", .{}, ctx, exception);
                return transpiler;
            }

            var define_iter = JSC.JSPropertyIterator(.{
                .skip_empty_name = true,

                .include_value = true,
            }).init(globalThis, define.asObjectRef());
            defer define_iter.deinit();

            // cannot be a temporary because it may be loaded on different threads.
            var map_entries = allocator.alloc([]u8, define_iter.len * 2) catch unreachable;
            var names = map_entries[0..define_iter.len];

            var values = map_entries[define_iter.len..];

            while (define_iter.next()) |prop| {
                const property_value = define_iter.value;
                const value_type = property_value.jsType();

                if (!value_type.isStringLike()) {
                    JSC.throwInvalidArguments("define \"{s}\" must be a JSON string", .{prop}, ctx, exception);
                    return transpiler;
                }

                names[define_iter.i] = prop.toOwnedSlice(allocator) catch unreachable;
                var val = JSC.ZigString.init("");
                property_value.toZigString(&val, globalThis);
                if (val.len == 0) {
                    val = JSC.ZigString.init("\"\"");
                }
                values[define_iter.i] = std.fmt.allocPrint(allocator, "{}", .{val}) catch unreachable;
            }

            transpiler.transform.define = Api.StringMap{
                .keys = names,
                .values = values,
            };
        }
    }

    if (object.get(globalThis, "external")) |external| {
        external: {
            if (external.isUndefinedOrNull()) break :external;

            const toplevel_type = external.jsType();
            if (toplevel_type.isStringLike()) {
                var zig_str = JSC.ZigString.init("");
                external.toZigString(&zig_str, globalThis);
                if (zig_str.len == 0) break :external;
                var single_external = allocator.alloc(string, 1) catch unreachable;
                single_external[0] = std.fmt.allocPrint(allocator, "{}", .{external}) catch unreachable;
                transpiler.transform.external = single_external;
            } else if (toplevel_type.isArray()) {
                const count = external.getLengthOfArray(globalThis);
                if (count == 0) break :external;

                var externals = allocator.alloc(string, count) catch unreachable;
                var iter = external.arrayIterator(globalThis);
                var i: usize = 0;
                while (iter.next()) |entry| {
                    if (!entry.jsType().isStringLike()) {
                        JSC.throwInvalidArguments("external must be a string or string[]", .{}, ctx, exception);
                        return transpiler;
                    }

                    var zig_str = JSC.ZigString.init("");
                    entry.toZigString(&zig_str, globalThis);
                    if (zig_str.len == 0) continue;
                    externals[i] = std.fmt.allocPrint(allocator, "{}", .{external}) catch unreachable;
                    i += 1;
                }

                transpiler.transform.external = externals[0..i];
            } else {
                JSC.throwInvalidArguments("external must be a string or string[]", .{}, ctx, exception);
                return transpiler;
            }
        }
    }

    if (object.get(globalThis, "loader")) |loader| {
        if (Loader.fromJS(globalThis, loader, exception)) |resolved| {
            if (!resolved.isJavaScriptLike()) {
                JSC.throwInvalidArguments("only JavaScript-like loaders supported for now", .{}, ctx, exception);
                return transpiler;
            }

            transpiler.default_loader = resolved;
        }

        if (exception.* != null) {
            return transpiler;
        }
    }

    if (object.get(globalThis, "platform")) |platform| {
        if (Platform.fromJS(globalThis, platform, exception)) |resolved| {
            transpiler.transform.platform = resolved.toAPI();
        }

        if (exception.* != null) {
            return transpiler;
        }
    }

    if (object.get(globalThis, "tsconfig")) |tsconfig| {
        tsconfig: {
            if (tsconfig.isUndefinedOrNull()) break :tsconfig;
            const kind = tsconfig.jsType();
            var out = JSC.ZigString.init("");

            if (kind.isArray()) {
                JSC.throwInvalidArguments("tsconfig must be a string or object", .{}, ctx, exception);
                return transpiler;
            }

            if (!kind.isStringLike()) {
                tsconfig.jsonStringify(globalThis, 0, &out);
            } else {
                tsconfig.toZigString(&out, globalThis);
            }

            if (out.len == 0) break :tsconfig;
            transpiler.tsconfig_buf = std.fmt.allocPrint(allocator, "{}", .{out}) catch unreachable;

            // TODO: JSC -> Ast conversion
            if (TSConfigJSON.parse(
                allocator,
                &transpiler.log,
                logger.Source.initPathString("tsconfig.json", transpiler.tsconfig_buf),
                &VirtualMachine.vm.bundler.resolver.caches.json,
                true,
            ) catch null) |parsed_tsconfig| {
                transpiler.tsconfig = parsed_tsconfig;
            }
        }
    }

    transpiler.runtime.allow_runtime = false;
    transpiler.runtime.dynamic_require = switch (transpiler.transform.platform orelse .browser) {
        .bun, .bun_macro => true,
        else => false,
    };

    if (object.getIfPropertyExists(globalThis, "macro")) |macros| {
        macros: {
            if (macros.isUndefinedOrNull()) break :macros;
            const kind = macros.jsType();
            const is_object = kind.isObject();
            if (!(kind.isStringLike() or is_object)) {
                JSC.throwInvalidArguments("macro must be an object", .{}, ctx, exception);
                return transpiler;
            }

            var out: ZigString = ZigString.init("");
            // TODO: write a converter between JSC types and Bun AST types
            if (is_object) {
                macros.jsonStringify(globalThis, 0, &out);
            } else {
                macros.toZigString(&out, globalThis);
            }

            if (out.len == 0) break :macros;
            transpiler.macros_buf = std.fmt.allocPrint(allocator, "{}", .{out}) catch unreachable;
            const source = logger.Source.initPathString("macros.json", transpiler.macros_buf);
            const json = (VirtualMachine.vm.bundler.resolver.caches.json.parseJSON(
                &transpiler.log,
                source,
                allocator,
            ) catch null) orelse break :macros;
            transpiler.macro_map = PackageJSON.parseMacrosJSON(allocator, json, &transpiler.log, &source);
        }
    }

    if (object.get(globalThis, "autoImportJSX")) |flag| {
        transpiler.runtime.auto_import_jsx = flag.toBoolean();
    }

    if (object.get(globalThis, "allowBunRuntime")) |flag| {
        transpiler.runtime.allow_runtime = flag.toBoolean();
    }

    if (object.get(globalThis, "jsxOptimizationInline")) |flag| {
        transpiler.runtime.jsx_optimization_inline = flag.toBoolean();
    }

    if (object.get(globalThis, "jsxOptimizationHoist")) |flag| {
        transpiler.runtime.jsx_optimization_hoist = flag.toBoolean();

        if (!transpiler.runtime.jsx_optimization_inline and transpiler.runtime.jsx_optimization_hoist) {
            JSC.throwInvalidArguments("jsxOptimizationHoist requires jsxOptimizationInline", .{}, ctx, exception);
            return transpiler;
        }
    }

    if (object.get(globalThis, "sourcemap")) |flag| {
        if (flag.isBoolean() or flag.isUndefinedOrNull()) {
            if (flag.toBoolean()) {
                transpiler.transform.source_map = Api.SourceMapMode.external;
            } else {
                transpiler.transform.source_map = Api.SourceMapMode.inline_into_file;
            }
        } else {
            var sourcemap = flag.toSlice(globalThis, allocator);
            if (options.SourceMapOption.map.get(sourcemap.slice())) |source| {
                transpiler.transform.source_map = source.toAPI();
            } else {
                JSC.throwInvalidArguments("sourcemap must be one of \"inline\", \"external\", or \"none\"", .{}, ctx, exception);
                return transpiler;
            }
        }
    }

    var tree_shaking: ?bool = null;
    if (object.get(globalThis, "treeShaking")) |treeShaking| {
        tree_shaking = treeShaking.toBoolean();
    }

    var trim_unused_imports: ?bool = null;
    if (object.get(globalThis, "trimUnusedImports")) |trimUnusedImports| {
        trim_unused_imports = trimUnusedImports.toBoolean();
    }

    if (object.getTruthy(globalThis, "exports")) |exports| {
        if (!exports.isObject()) {
            JSC.throwInvalidArguments("exports must be an object", .{}, ctx, exception);
            return transpiler;
        }

        var replacements = Runtime.Features.ReplaceableExport.Map{};
        errdefer replacements.clearAndFree(bun.default_allocator);

        if (exports.getTruthy(globalThis, "eliminate")) |eliminate| {
            if (!eliminate.jsType().isArray()) {
                JSC.throwInvalidArguments("exports.eliminate must be an array", .{}, ctx, exception);
                return transpiler;
            }

            var total_name_buf_len: u32 = 0;
            var string_count: u32 = 0;
            var iter = JSC.JSArrayIterator.init(eliminate, globalThis);
            {
                var length_iter = iter;
                while (length_iter.next()) |value| {
                    if (value.isString()) {
                        const length = @truncate(u32, value.getLengthOfArray(globalThis));
                        string_count += @as(u32, @boolToInt(length > 0));
                        total_name_buf_len += length;
                    }
                }
            }

            if (total_name_buf_len > 0) {
                var buf = try std.ArrayListUnmanaged(u8).initCapacity(bun.default_allocator, total_name_buf_len);
                try replacements.ensureUnusedCapacity(bun.default_allocator, string_count);
                {
                    var length_iter = iter;
                    while (length_iter.next()) |value| {
                        if (!value.isString()) continue;
                        var str = value.getZigString(globalThis);
                        if (str.len == 0) continue;
                        const name = std.fmt.bufPrint(buf.items.ptr[buf.items.len..buf.capacity], "{}", .{str}) catch {
                            JSC.throwInvalidArguments("Error reading exports.eliminate. TODO: utf-16", .{}, ctx, exception);
                            return transpiler;
                        };
                        buf.items.len += name.len;
                        if (name.len > 0) {
                            replacements.putAssumeCapacity(name, .{ .delete = .{} });
                        }
                    }
                }
            }
        }

        if (exports.getTruthy(globalThis, "replace")) |replace| {
            if (!replace.isObject()) {
                JSC.throwInvalidArguments("replace must be an object", .{}, ctx, exception);
                return transpiler;
            }

            var iter = JSC.JSPropertyIterator(.{
                .skip_empty_name = true,
                .include_value = true,
            }).init(globalThis, replace.asObjectRef());

            if (iter.len > 0) {
                errdefer iter.deinit();
                try replacements.ensureUnusedCapacity(bun.default_allocator, iter.len);

                // We cannot set the exception before `try` because it could be
                // a double free with the `errdefer`.
                defer if (exception.* != null) {
                    iter.deinit();
                    for (replacements.keys()) |key| {
                        bun.default_allocator.free(bun.constStrToU8(key));
                    }
                    replacements.clearAndFree(bun.default_allocator);
                };

                while (iter.next()) |key_| {
                    const value = iter.value;
                    if (value.isEmpty()) continue;

                    var key = try key_.toOwnedSlice(bun.default_allocator);

                    if (!JSLexer.isIdentifier(key)) {
                        JSC.throwInvalidArguments("\"{s}\" is not a valid ECMAScript identifier", .{key}, ctx, exception);
                        bun.default_allocator.free(key);
                        return transpiler;
                    }

                    var entry = replacements.getOrPutAssumeCapacity(key);

                    if (exportReplacementValue(value, globalThis)) |expr| {
                        entry.value_ptr.* = .{ .replace = expr };
                        continue;
                    }

                    if (value.isObject() and value.getLengthOfArray(ctx.ptr()) == 2) {
                        const replacementValue = JSC.JSObject.getIndex(value, globalThis, 1);
                        if (exportReplacementValue(replacementValue, globalThis)) |to_replace| {
                            const replacementKey = JSC.JSObject.getIndex(value, globalThis, 0);
                            var slice = (try replacementKey.toSlice(globalThis, bun.default_allocator).cloneIfNeeded(bun.default_allocator));
                            var replacement_name = slice.slice();

                            if (!JSLexer.isIdentifier(replacement_name)) {
                                JSC.throwInvalidArguments("\"{s}\" is not a valid ECMAScript identifier", .{replacement_name}, ctx, exception);
                                slice.deinit();
                                return transpiler;
                            }

                            entry.value_ptr.* = .{
                                .inject = .{
                                    .name = replacement_name,
                                    .value = to_replace,
                                },
                            };
                            continue;
                        }
                    }

                    JSC.throwInvalidArguments("exports.replace values can only be string, null, undefined, number or boolean", .{}, ctx, exception);
                    return transpiler;
                }
            }
        }

        tree_shaking = tree_shaking orelse (replacements.count() > 0);
        transpiler.runtime.replace_exports = replacements;
    }

    transpiler.tree_shaking = tree_shaking orelse false;
    transpiler.trim_unused_imports = trim_unused_imports orelse transpiler.tree_shaking;

    return transpiler;
}

pub fn constructor(
    ctx: js.JSContextRef,
    _: js.JSObjectRef,
    arguments: []const js.JSValueRef,
    exception: js.ExceptionRef,
) js.JSObjectRef {
    var temp = std.heap.ArenaAllocator.init(getAllocator(ctx));
    var args = JSC.Node.ArgumentsSlice.init(ctx.bunVM(), @ptrCast([*]const JSC.JSValue, arguments.ptr)[0..arguments.len]);
    defer temp.deinit();
    const transpiler_options: TranspilerOptions = if (arguments.len > 0)
        transformOptionsFromJSC(ctx, temp.allocator(), &args, exception) catch {
            JSC.throwInvalidArguments("Failed to create transpiler", .{}, ctx, exception);
            return null;
        }
    else
        TranspilerOptions{ .log = logger.Log.init(getAllocator(ctx)) };

    if (exception.* != null) {
        return null;
    }

    if ((transpiler_options.log.warnings + transpiler_options.log.errors) > 0) {
        var out_exception = transpiler_options.log.toJS(ctx.ptr(), getAllocator(ctx), "Failed to create transpiler");
        exception.* = out_exception.asObjectRef();
        return null;
    }

    var log = getAllocator(ctx).create(logger.Log) catch unreachable;
    log.* = transpiler_options.log;
    var bundler = Bundler.Bundler.init(
        getAllocator(ctx),
        log,
        transpiler_options.transform,
        null,
        JavaScript.VirtualMachine.vm.bundler.env,
    ) catch |err| {
        if ((log.warnings + log.errors) > 0) {
            var out_exception = log.toJS(ctx.ptr(), getAllocator(ctx), "Failed to create transpiler");
            exception.* = out_exception.asObjectRef();
            return null;
        }

        JSC.throwInvalidArguments("Error creating transpiler: {s}", .{@errorName(err)}, ctx, exception);
        return null;
    };

    bundler.configureLinkerWithAutoJSX(false);
    bundler.options.env.behavior = .disable;
    bundler.configureDefines() catch |err| {
        if ((log.warnings + log.errors) > 0) {
            var out_exception = log.toJS(ctx.ptr(), getAllocator(ctx), "Failed to load define");
            exception.* = out_exception.asObjectRef();
            return null;
        }

        JSC.throwInvalidArguments("Failed to load define: {s}", .{@errorName(err)}, ctx, exception);
        return null;
    };

    if (transpiler_options.macro_map.count() > 0) {
        bundler.options.macro_remap = transpiler_options.macro_map;
    }

    bundler.options.tree_shaking = transpiler_options.tree_shaking;
    bundler.options.trim_unused_imports = transpiler_options.trim_unused_imports;
    bundler.options.allow_runtime = transpiler_options.runtime.allow_runtime;
    bundler.options.auto_import_jsx = transpiler_options.runtime.auto_import_jsx;
    bundler.options.hot_module_reloading = transpiler_options.runtime.hot_module_reloading;
    bundler.options.jsx.supports_fast_refresh = bundler.options.hot_module_reloading and
        bundler.options.allow_runtime and transpiler_options.runtime.react_fast_refresh;

    var transpiler = getAllocator(ctx).create(Transpiler) catch unreachable;
    transpiler.* = Transpiler{
        .transpiler_options = transpiler_options,
        .bundler = bundler,
        .arena = args.arena,
        .scan_pass_result = ScanPassResult.init(getAllocator(ctx)),
    };

    return Class.make(ctx, transpiler);
}

pub fn finalize(
    this: *Transpiler,
) void {
    this.bundler.log.deinit();
    this.scan_pass_result.named_imports.deinit();
    this.scan_pass_result.import_records.deinit();
    this.scan_pass_result.used_symbols.deinit();
    if (this.buffer_writer != null) {
        this.buffer_writer.?.buffer.deinit();
    }

    // bun.default_allocator.free(this.transpiler_options.tsconfig_buf);
    // bun.default_allocator.free(this.transpiler_options.macros_buf);
    this.arena.deinit();
}

fn getParseResult(this: *Transpiler, allocator: std.mem.Allocator, code: []const u8, loader: ?Loader, macro_js_ctx: Bundler.MacroJSValueType) ?Bundler.ParseResult {
    const name = this.transpiler_options.default_loader.stdinName();
    const source = logger.Source.initPathString(name, code);

    const jsx = if (this.transpiler_options.tsconfig != null)
        this.transpiler_options.tsconfig.?.mergeJSX(this.bundler.options.jsx)
    else
        this.bundler.options.jsx;

    const parse_options = Bundler.Bundler.ParseOptions{
        .allocator = allocator,
        .macro_remappings = this.transpiler_options.macro_map,
        .dirname_fd = 0,
        .file_descriptor = null,
        .loader = loader orelse this.transpiler_options.default_loader,
        .jsx = jsx,
        .path = source.path,
        .virtual_source = &source,
        .replace_exports = this.transpiler_options.runtime.replace_exports,
        .macro_js_ctx = macro_js_ctx,
        // .allocator = this.
    };

    var parse_result = this.bundler.parse(parse_options, null);

    // necessary because we don't run the linker
    if (parse_result) |*res| {
        for (res.ast.import_records) |*import| {
            if (import.kind.isCommonJS()) {
                import.do_commonjs_transform_in_printer = true;
                import.module_id = @truncate(u32, std.hash.Wyhash.hash(0, import.path.pretty));
            }
        }
    }

    return parse_result;
}

pub fn scan(
    this: *Transpiler,
    ctx: js.JSContextRef,
    _: js.JSObjectRef,
    _: js.JSObjectRef,
    arguments: []const js.JSValueRef,
    exception: js.ExceptionRef,
) JSC.C.JSObjectRef {
    JSC.markBinding(@src());
    var args = JSC.Node.ArgumentsSlice.init(ctx.bunVM(), @ptrCast([*]const JSC.JSValue, arguments.ptr)[0..arguments.len]);
    defer args.arena.deinit();
    const code_arg = args.next() orelse {
        JSC.throwInvalidArguments("Expected a string or Uint8Array", .{}, ctx, exception);
        return null;
    };

    const code_holder = JSC.Node.StringOrBuffer.fromJS(ctx.ptr(), args.arena.allocator(), code_arg, exception) orelse {
        if (exception.* == null) JSC.throwInvalidArguments("Expected a string or Uint8Array", .{}, ctx, exception);
        return null;
    };

    const code = code_holder.slice();
    args.eat();
    const loader: ?Loader = brk: {
        if (args.next()) |arg| {
            args.eat();
            break :brk Loader.fromJS(ctx.ptr(), arg, exception);
        }

        break :brk null;
    };

    if (exception.* != null) return null;

    var arena = Mimalloc.Arena.init() catch unreachable;
    var prev_allocator = this.bundler.allocator;
    this.bundler.setAllocator(arena.allocator());
    var log = logger.Log.init(arena.backingAllocator());
    defer log.deinit();
    this.bundler.setLog(&log);
    defer {
        this.bundler.setLog(&this.transpiler_options.log);
        this.bundler.setAllocator(prev_allocator);
        arena.deinit();
    }

    defer {
        JSAst.Stmt.Data.Store.reset();
        JSAst.Expr.Data.Store.reset();
    }

    const parse_result = getParseResult(this, arena.allocator(), code, loader, Bundler.MacroJSValueType.zero) orelse {
        if ((this.bundler.log.warnings + this.bundler.log.errors) > 0) {
            var out_exception = this.bundler.log.toJS(ctx.ptr(), getAllocator(ctx), "Parse error");
            exception.* = out_exception.asObjectRef();
            return null;
        }

        JSC.throwInvalidArguments("Failed to parse", .{}, ctx, exception);
        return null;
    };

    if ((this.bundler.log.warnings + this.bundler.log.errors) > 0) {
        var out_exception = this.bundler.log.toJS(ctx.ptr(), getAllocator(ctx), "Parse error");
        exception.* = out_exception.asObjectRef();
        return null;
    }

    const exports_label = JSC.ZigString.init("exports");
    const imports_label = JSC.ZigString.init("imports");
    const named_imports_value = namedImportsToJS(
        ctx.ptr(),
        parse_result.ast.import_records,
        exception,
    );
    if (exception.* != null) return null;
    var named_exports_value = namedExportsToJS(
        ctx.ptr(),
        parse_result.ast.named_exports,
    );
    return JSC.JSValue.createObject2(ctx.ptr(), &imports_label, &exports_label, named_imports_value, named_exports_value).asObjectRef();
}

// pub fn build(
//     this: *Transpiler,
//     ctx: js.JSContextRef,
//     _: js.JSObjectRef,
//     _: js.JSObjectRef,
//     arguments: []const js.JSValueRef,
//     exception: js.ExceptionRef,
// ) JSC.C.JSObjectRef {}

pub fn transform(
    this: *Transpiler,
    ctx: js.JSContextRef,
    _: js.JSObjectRef,
    _: js.JSObjectRef,
    arguments: []const js.JSValueRef,
    exception: js.ExceptionRef,
) JSC.C.JSObjectRef {
    JSC.markBinding(@src());

    var args = JSC.Node.ArgumentsSlice.init(ctx.bunVM(), @ptrCast([*]const JSC.JSValue, arguments.ptr)[0..arguments.len]);
    defer args.arena.deinit();
    const code_arg = args.next() orelse {
        JSC.throwInvalidArguments("Expected a string or Uint8Array", .{}, ctx, exception);
        return null;
    };

    const code_holder = JSC.Node.StringOrBuffer.fromJS(ctx.ptr(), this.arena.allocator(), code_arg, exception) orelse {
        if (exception.* == null) JSC.throwInvalidArguments("Expected a string or Uint8Array", .{}, ctx, exception);
        return null;
    };

    const code = code_holder.slice();
    args.eat();
    const loader: ?Loader = brk: {
        if (args.next()) |arg| {
            args.eat();
            break :brk Loader.fromJS(ctx.ptr(), arg, exception);
        }

        break :brk null;
    };

    if (exception.* != null) return null;
    if (code_holder == .string) {
        JSC.C.JSValueProtect(ctx, arguments[0]);
    }

    var task = TransformTask.create(this, if (code_holder == .string) arguments[0] else null, ctx.ptr(), ZigString.init(code), loader orelse this.transpiler_options.default_loader) catch return null;
    task.schedule();
    return task.promise.value().asObjectRef();
}

pub fn transformSync(
    this: *Transpiler,
    ctx: js.JSContextRef,
    _: js.JSObjectRef,
    _: js.JSObjectRef,
    arguments: []const js.JSValueRef,
    exception: js.ExceptionRef,
) JSC.C.JSObjectRef {
    var args = JSC.Node.ArgumentsSlice.init(ctx.bunVM(), @ptrCast([*]const JSC.JSValue, arguments.ptr)[0..arguments.len]);
    defer args.arena.deinit();
    const code_arg = args.next() orelse {
        JSC.throwInvalidArguments("Expected a string or Uint8Array", .{}, ctx, exception);
        return null;
    };

    var arena = Mimalloc.Arena.init() catch unreachable;
    defer arena.deinit();
    const code_holder = JSC.Node.StringOrBuffer.fromJS(ctx.ptr(), arena.allocator(), code_arg, exception) orelse {
        if (exception.* == null) JSC.throwInvalidArguments("Expected a string or Uint8Array", .{}, ctx, exception);
        return null;
    };

    const code = code_holder.slice();
    JSC.JSValue.c(arguments[0]).ensureStillAlive();
    defer JSC.JSValue.c(arguments[0]).ensureStillAlive();

    args.eat();
    var js_ctx_value: JSC.JSValue = JSC.JSValue.zero;
    const loader: ?Loader = brk: {
        if (args.next()) |arg| {
            args.eat();
            if (arg.isNumber() or arg.isString()) {
                break :brk Loader.fromJS(ctx.ptr(), arg, exception);
            }

            if (arg.isObject()) {
                js_ctx_value = arg;
                break :brk null;
            }
        }

        break :brk null;
    };

    if (args.nextEat()) |arg| {
        if (arg.isObject()) {
            js_ctx_value = arg;
        } else {
            JSC.throwInvalidArguments("Expected a Loader or object", .{}, ctx, exception);
            return null;
        }
    }
    if (!js_ctx_value.isEmpty()) {
        js_ctx_value.ensureStillAlive();
    }

    defer {
        if (!js_ctx_value.isEmpty()) {
            js_ctx_value.ensureStillAlive();
        }
    }

    if (exception.* != null) return null;

    JSAst.Stmt.Data.Store.reset();
    JSAst.Expr.Data.Store.reset();
    defer {
        JSAst.Stmt.Data.Store.reset();
        JSAst.Expr.Data.Store.reset();
    }

    var prev_bundler = this.bundler;
    this.bundler.setAllocator(arena.allocator());
    this.bundler.macro_context = null;
    var log = logger.Log.init(arena.backingAllocator());
    this.bundler.setLog(&log);

    defer {
        this.bundler = prev_bundler;
    }
    var parse_result = getParseResult(
        this,
        arena.allocator(),
        code,
        loader,
        if (comptime JSC.is_bindgen) Bundler.MacroJSValueType.zero else js_ctx_value,
    ) orelse {
        if ((this.bundler.log.warnings + this.bundler.log.errors) > 0) {
            var out_exception = this.bundler.log.toJS(ctx.ptr(), getAllocator(ctx), "Parse error");
            exception.* = out_exception.asObjectRef();
            return null;
        }

        JSC.throwInvalidArguments("Failed to parse", .{}, ctx, exception);
        return null;
    };

    if ((this.bundler.log.warnings + this.bundler.log.errors) > 0) {
        var out_exception = this.bundler.log.toJS(ctx.ptr(), getAllocator(ctx), "Parse error");
        exception.* = out_exception.asObjectRef();
        return null;
    }

    var buffer_writer = this.buffer_writer orelse brk: {
        var writer = JSPrinter.BufferWriter.init(arena.backingAllocator()) catch {
            JSC.throwInvalidArguments("Failed to create BufferWriter", .{}, ctx, exception);
            return null;
        };

        writer.buffer.growIfNeeded(code.len) catch unreachable;
        writer.buffer.list.expandToCapacity();
        break :brk writer;
    };

    defer {
        this.buffer_writer = buffer_writer;
    }

    buffer_writer.reset();
    var printer = JSPrinter.BufferPrinter.init(buffer_writer);
    _ = this.bundler.print(parse_result, @TypeOf(&printer), &printer, .esm_ascii) catch |err| {
        JSC.JSError(bun.default_allocator, "Failed to print code: {s}", .{@errorName(err)}, ctx, exception);

        return null;
    };

    // TODO: benchmark if pooling this way is faster or moving is faster
    buffer_writer = printer.ctx;
    var out = JSC.ZigString.init(buffer_writer.written);
    out.mark();
    out.setOutputEncoding();

    return out.toValueGC(ctx.ptr()).asObjectRef();
}

fn namedExportsToJS(global: *JSGlobalObject, named_exports: JSAst.Ast.NamedExports) JSC.JSValue {
    if (named_exports.count() == 0)
        return JSC.JSValue.fromRef(JSC.C.JSObjectMakeArray(global, 0, null, null));

    var named_exports_iter = named_exports.iterator();
    var stack_fallback = std.heap.stackFallback(@sizeOf(JSC.ZigString) * 32, getAllocator(global));
    var allocator = stack_fallback.get();
    var names = allocator.alloc(
        JSC.ZigString,
        named_exports.count(),
    ) catch unreachable;
    defer allocator.free(names);
    var i: usize = 0;
    while (named_exports_iter.next()) |entry| {
        names[i] = JSC.ZigString.init(entry.key_ptr.*);
        i += 1;
    }
    JSC.ZigString.sortAsc(names[0..i]);
    return JSC.JSValue.createStringArray(global, names.ptr, names.len, true);
}

const ImportRecord = @import("../../import_record.zig").ImportRecord;

fn namedImportsToJS(
    global: *JSGlobalObject,
    import_records: []const ImportRecord,
    exception: JSC.C.ExceptionRef,
) JSC.JSValue {
    var stack_fallback = std.heap.stackFallback(@sizeOf(JSC.C.JSObjectRef) * 32, getAllocator(global));
    var allocator = stack_fallback.get();

    var i: usize = 0;
    const path_label = JSC.ZigString.init("path");
    const kind_label = JSC.ZigString.init("kind");
    var array_items = allocator.alloc(
        JSC.C.JSValueRef,
        import_records.len,
    ) catch unreachable;
    defer allocator.free(array_items);

    for (import_records) |record| {
        if (record.is_internal) continue;

        const path = JSC.ZigString.init(record.path.text).toValueGC(global);
        const kind = JSC.ZigString.init(record.kind.label()).toValue(global);
        array_items[i] = JSC.JSValue.createObject2(global, &path_label, &kind_label, path, kind).asObjectRef();
        i += 1;
    }

    return JSC.JSValue.fromRef(JSC.C.JSObjectMakeArray(global, i, array_items.ptr, exception));
}

pub fn scanImports(
    this: *Transpiler,
    ctx: js.JSContextRef,
    _: js.JSObjectRef,
    _: js.JSObjectRef,
    arguments: []const js.JSValueRef,
    exception: js.ExceptionRef,
) JSC.C.JSObjectRef {
    var args = JSC.Node.ArgumentsSlice.init(ctx.bunVM(), @ptrCast([*]const JSC.JSValue, arguments.ptr)[0..arguments.len]);
    const code_arg = args.next() orelse {
        JSC.throwInvalidArguments("Expected a string or Uint8Array", .{}, ctx, exception);
        return null;
    };

    const code_holder = JSC.Node.StringOrBuffer.fromJS(ctx.ptr(), args.arena.allocator(), code_arg, exception) orelse {
        if (exception.* == null) JSC.throwInvalidArguments("Expected a string or Uint8Array", .{}, ctx, exception);
        return null;
    };
    args.eat();
    const code = code_holder.slice();

    var loader: Loader = this.transpiler_options.default_loader;
    if (args.next()) |arg| {
        if (Loader.fromJS(ctx.ptr(), arg, exception)) |_loader| {
            loader = _loader;
        }
        args.eat();
    }

    if (!loader.isJavaScriptLike()) {
        JSC.throwInvalidArguments("Only JavaScript-like files support this fast path", .{}, ctx, exception);
        return null;
    }

    if (exception.* != null) return null;

    var arena = Mimalloc.Arena.init() catch unreachable;
    var prev_allocator = this.bundler.allocator;
    this.bundler.setAllocator(arena.allocator());
    var log = logger.Log.init(arena.backingAllocator());
    defer log.deinit();
    this.bundler.setLog(&log);
    defer {
        this.bundler.setLog(&this.transpiler_options.log);
        this.bundler.setAllocator(prev_allocator);
        arena.deinit();
    }

    const source = logger.Source.initPathString(loader.stdinName(), code);
    var bundler = &this.bundler;
    const jsx = if (this.transpiler_options.tsconfig != null)
        this.transpiler_options.tsconfig.?.mergeJSX(this.bundler.options.jsx)
    else
        this.bundler.options.jsx;

    var opts = JSParser.Parser.Options.init(jsx, loader);
    if (this.bundler.macro_context == null) {
        this.bundler.macro_context = JSAst.Macro.MacroContext.init(&this.bundler);
    }
    opts.macro_context = &this.bundler.macro_context.?;

    JSAst.Stmt.Data.Store.reset();
    JSAst.Expr.Data.Store.reset();

    defer {
        JSAst.Stmt.Data.Store.reset();
        JSAst.Expr.Data.Store.reset();
    }

    bundler.resolver.caches.js.scan(
        bundler.allocator,
        &this.scan_pass_result,
        opts,
        bundler.options.define,
        &log,
        &source,
    ) catch |err| {
        defer this.scan_pass_result.reset();
        if ((log.warnings + log.errors) > 0) {
            var out_exception = log.toJS(ctx.ptr(), getAllocator(ctx), "Failed to scan imports");
            exception.* = out_exception.asObjectRef();
            return null;
        }

        JSC.throwInvalidArguments("Failed to scan imports: {s}", .{@errorName(err)}, ctx, exception);
        return null;
    };

    defer this.scan_pass_result.reset();

    if ((log.warnings + log.errors) > 0) {
        var out_exception = log.toJS(ctx.ptr(), getAllocator(ctx), "Failed to scan imports");
        exception.* = out_exception.asObjectRef();
        return null;
    }

    const named_imports_value = namedImportsToJS(
        ctx.ptr(),
        this.scan_pass_result.import_records.items,
        exception,
    );
    if (exception.* != null) return null;
    return named_imports_value.asObjectRef();
}
