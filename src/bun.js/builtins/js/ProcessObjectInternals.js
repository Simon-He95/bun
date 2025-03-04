/*
 * Copyright 2022 Codeblog Corp. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

function getStdioWriteStream(fd_, rawRequire) {
  var module = { path: "node:process", require: rawRequire };
  var require = (path) => module.require(path);

  function createStdioWriteStream(fd_) {
    var { Duplex, eos, destroy } = require("node:stream");
    var StdioWriteStream = class StdioWriteStream extends Duplex {
      #writeStream;
      #readStream;

      #readable = true;
      #writable = true;
      #fdPath;

      #onClose;
      #onDrain;
      #onFinish;
      #onReadable;
      #isTTY;

      get isTTY() {
        return (this.#isTTY ??= require("node:tty").isatty(fd_));
      }

      get fd() {
        return fd_;
      }

      constructor(fd) {
        super({ readable: true, writable: true });
        this.#fdPath = `/dev/fd/${fd}`;
      }

      #onFinished(err) {
        const cb = this.#onClose;
        this.#onClose = null;

        if (cb) {
          cb(err);
        } else if (err) {
          this.destroy(err);
        } else if (!this.#readable && !this.#writable) {
          this.destroy();
        }
      }

      _destroy(err, callback) {
        if (!err && this.#onClose !== null) {
          var AbortError = class AbortError extends Error {
            constructor(
              message = "The operation was aborted",
              options = void 0,
            ) {
              if (options !== void 0 && typeof options !== "object") {
                throw new Error(
                  `Invalid AbortError options:\n\n${JSON.stringify(
                    options,
                    null,
                    2,
                  )}`,
                );
              }
              super(message, options);
              this.code = "ABORT_ERR";
              this.name = "AbortError";
            }
          };
          err = new AbortError();
        }

        this.#onDrain = null;
        this.#onFinish = null;
        if (this.#onClose === null) {
          callback(err);
        } else {
          this.#onClose = callback;
          if (this.#writeStream) destroy(this.#writeStream, err);
          if (this.#readStream) destroy(this.#readStream, err);
        }
      }

      _write(chunk, encoding, callback) {
        if (!this.#writeStream) {
          var { createWriteStream } = require("node:fs");
          var stream = (this.#writeStream = createWriteStream(this.#fdPath));

          stream.on("finish", () => {
            if (this.#onFinish) {
              const cb = this.#onFinish;
              this.#onFinish = null;
              cb();
            }
          });

          stream.on("drain", () => {
            if (this.#onDrain) {
              const cb = this.#onDrain;
              this.#onDrain = null;
              cb();
            }
          });

          eos(stream, (err) => {
            this.#writable = false;
            if (err) {
              destroy(stream, err);
            }
            this.#onFinished(err);
          });
        }
        if (stream.write(chunk, encoding)) {
          callback();
        } else {
          this.#onDrain = callback;
        }
      }

      _final(callback) {
        this.#writeStream && this.#writeStream.end();
        this.#onFinish = callback;
      }

      #loadReadStream() {
        var { createReadStream } = require("node:fs");

        var readStream = (this.#readStream = createReadStream(this.#fdPath));

        readStream.on("readable", () => {
          if (this.#onReadable) {
            const cb = this.#onReadable;
            this.#onReadable = null;
            cb();
          } else {
            this.read();
          }
        });

        readStream.on("end", () => {
          this.push(null);
        });

        eos(readStream, (err) => {
          this.#readable = false;
          if (err) {
            destroy(readStream, err);
          }
          this.#onFinished(err);
        });
        return readStream;
      }

      _read() {
        var stream = this.#readStream;
        if (!stream) {
          stream = this.#loadReadStream();
        }

        while (true) {
          const buf = stream.read();
          if (buf === null || !this.push(buf)) {
            return;
          }
        }
      }
    };
    return new StdioWriteStream(fd_);
  }

  var { EventEmitter } = require("node:events");

  function isFastEncoding(encoding) {
    if (!encoding) return true;

    var normalied = encoding.toLowerCase();
    return (
      normalied === "utf8" ||
      normalied === "utf-8" ||
      normalied === "buffer" ||
      normalied === "binary"
    );
  }

  var FastStdioWriteStream = class StdioWriteStream extends EventEmitter {
    #fd;
    #innerStream;
    #writer;
    #isTTY;

    bytesWritten = 0;

    setDefaultEncoding(encoding) {
      if (this.#innerStream || !isFastEncoding(encoding)) {
        this.#ensureInnerStream();
        return this.#innerStream.setDefaultEncoding(encoding);
      }
    }

    #createWriter() {
      switch (this.#fd) {
        case 1: {
          var writer = Bun.stdout.writer({ highWaterMark: 0 });
          writer.unref();
          return writer;
        }

        case 2: {
          var writer = Bun.stderr.writer({ highWaterMark: 0 });
          writer.unref();
          return writer;
        }
        default: {
          throw new Error("Unsupported writer");
        }
      }
    }

    #getWriter() {
      return (this.#writer ??= this.#createWriter());
    }

    constructor(fd_) {
      super();
      this.#fd = fd_;
    }

    get fd() {
      return this.#fd;
    }

    get isTTY() {
      return (this.#isTTY ??= require("node:tty").isatty(this.#fd));
    }

    ref() {
      this.#getWriter().ref();
    }

    unref() {
      this.#getWriter().unref();
    }

    on(event, listener) {
      if (event === "close" || event === "finish") {
        this.#ensureInnerStream();
        return this.#innerStream.on(event, listener);
      }

      if (event === "drain") {
        return super.on("drain", listener);
      }

      if (event === "error") {
        return super.on("error", listener);
      }

      return super.on(event, listener);
    }

    get _writableState() {
      this.#ensureInnerStream();
      return this.#innerStream._writableState;
    }

    get _readableState() {
      this.#ensureInnerStream();
      return this.#innerStream._readableState;
    }

    pipe(destination) {
      this.#ensureInnerStream();
      return this.#innerStream.pipe(destination);
    }

    unpipe(destination) {
      this.#ensureInnerStream();
      return this.#innerStream.unpipe(destination);
    }

    #ensureInnerStream() {
      if (this.#innerStream) return;
      this.#innerStream = createStdioWriteStream(this.#fd);
      const events = this.eventNames();
      for (const event of events) {
        this.#innerStream.on(event, (...args) => {
          this.emit(event, ...args);
        });
      }
    }

    #write1(chunk) {
      var writer = this.#getWriter();
      const writeResult = writer.write(chunk);
      this.bytesWritten += writeResult;
      const flushResult = writer.flush(false);
      return !!(writeResult || flushResult);
    }

    #writeWithEncoding(chunk, encoding) {
      if (!isFastEncoding(encoding)) {
        this.#ensureInnerStream();
        return this.#innerStream.write(chunk, encoding);
      }

      return this.#write1(chunk);
    }

    #performCallback(cb, err) {
      if (err) {
        this.emit("error", err);
      }

      try {
        cb(err ? err : null);
      } catch (err2) {
        this.emit("error", err2);
      }
    }

    #writeWithCallbackAndEncoding(chunk, encoding, callback) {
      if (!isFastEncoding(encoding)) {
        this.#ensureInnerStream();
        return this.#innerStream.write(chunk, encoding, callback);
      }

      var writer = this.#getWriter();
      const writeResult = writer.write(chunk);
      const flushResult = writer.flush(true);
      if (flushResult?.then) {
        flushResult.then(
          () => {
            this.#performCallback(callback);
            this.emit("drain");
          },
          (err) => this.#performCallback(callback, err),
        );
        return false;
      }

      queueMicrotask(() => {
        this.#performCallback(callback);
      });

      return !!(writeResult || flushResult);
    }

    write(chunk, encoding, callback) {
      const result = this._write(chunk, encoding, callback);

      if (result) {
        this.emit("drain");
      }

      return result;
    }

    get hasColors() {
      return Bun.tty[this.#fd].hasColors;
    }

    _write(chunk, encoding, callback) {
      var inner = this.#innerStream;
      if (inner) {
        return inner.write(chunk, encoding, callback);
      }

      switch (arguments.length) {
        case 0: {
          var error = new Error("Invalid arguments");
          error.code = "ERR_INVALID_ARG_TYPE";
          throw error;
        }
        case 1: {
          return this.#write1(chunk);
        }
        case 2: {
          if (typeof encoding === "function") {
            return this.#writeWithCallbackAndEncoding(chunk, "", encoding);
          } else if (typeof encoding === "string") {
            return this.#writeWithEncoding(chunk, encoding);
          }
        }
        default: {
          if (
            (typeof encoding !== "undefined" && typeof encoding !== "string") ||
            (typeof callback !== "undefined" && typeof callback !== "function")
          ) {
            var error = new Error("Invalid arguments");
            error.code = "ERR_INVALID_ARG_TYPE";
            throw error;
          }

          if (typeof callback === "undefined") {
            return this.#writeWithEncoding(chunk, encoding);
          }

          return this.#writeWithCallbackAndEncoding(chunk, encoding, callback);
        }
      }
    }

    destroy() {
      return this;
    }

    end() {
      return this;
    }
  };

  return new FastStdioWriteStream(fd_);
}

function getStdinStream(fd, rawRequire, Bun) {
  var module = { path: "node:process", require: rawRequire };
  var require = (path) => module.require(path);

  var { Readable, Duplex, eos, destroy } = require("node:stream");

  var StdinStream = class StdinStream extends Duplex {
    #readStream;
    #writeStream;

    #readable = true;
    #writable = true;

    #onFinish;
    #onClose;
    #onDrain;
    #onReadable;

    get isTTY() {
      return require("tty").isatty(fd);
    }

    get fd() {
      return fd_;
    }

    constructor() {
      super({ readable: true, writable: true });

      this.#onReadable = (...args) => this._read(...args);
    }

    #onFinished(err) {
      const cb = this.#onClose;
      this.#onClose = null;

      if (cb) {
        cb(err);
      } else if (err) {
        this.destroy(err);
      } else if (!this.#readable && !this.#writable) {
        this.destroy();
      }
    }

    _destroy(err, callback) {
      if (!err && this.#onClose !== null) {
        var AbortError = class AbortError extends Error {
          constructor(message = "The operation was aborted", options = void 0) {
            if (options !== void 0 && typeof options !== "object") {
              throw new Error(
                `Invalid AbortError options:\n\n${JSON.stringify(
                  options,
                  null,
                  2,
                )}`,
              );
            }
            super(message, options);
            this.code = "ABORT_ERR";
            this.name = "AbortError";
          }
        };
        err = new AbortError();
      }

      if (this.#onClose === null) {
        callback(err);
      } else {
        this.#onClose = callback;
        if (this.#readStream) destroy(this.#readStream, err);
        if (this.#writeStream) destroy(this.#writeStream, err);
      }
    }

    on(ev, cb) {
      super.on(ev, cb);
      if (!this.#readStream && (ev === "readable" || ev === "data")) {
        this.#loadReadStream();
      }
    }

    #loadReadStream() {
      var readStream = (this.#readStream = Readable.fromWeb(
        Bun.stdin.stream(),
      ));

      readStream.on("data", (data) => {
        this.push(data);
      });
      readStream.ref();

      readStream.on("end", () => {
        this.push(null);
      });

      eos(readStream, (err) => {
        this.#readable = false;
        if (err) {
          destroy(readStream, err);
        }
        this.#onFinished(err);
      });
    }

    ref() {
      this.#readStream?.ref?.();
    }
    unref() {
      this.#readStream?.unref?.();
    }

    _read(encoding, callback) {}

    #constructWriteStream() {
      var { createWriteStream } = require("node:fs");
      var writeStream = (this.#writeStream = createWriteStream("/dev/fd/0"));

      writeStream.on("finish", () => {
        if (this.#onFinish) {
          const cb = this.#onFinish;
          this.#onFinish = null;
          cb();
        }
      });

      writeStream.on("drain", () => {
        if (this.#onDrain) {
          const cb = this.#onDrain;
          this.#onDrain = null;
          cb();
        }
      });

      eos(writeStream, (err) => {
        this.#writable = false;
        if (err) {
          destroy(writeStream, err);
        }
        this.#onFinished(err);
      });

      return writeStream;
    }

    _write(chunk, encoding, callback) {
      var writeStream = this.#writeStream;
      if (!writeStream) {
        writeStream = this.#constructWriteStream();
      }

      if (writeStream.write(chunk, encoding)) {
        callback();
      } else {
        this.#onDrain = callback;
      }
    }

    _final(callback) {
      this.#writeStream.end();
      this.#onFinish = (...args) => callback(...args);
    }
  };

  return new StdinStream();
}
