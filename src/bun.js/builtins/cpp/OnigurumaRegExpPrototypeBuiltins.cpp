/*
 * Copyright (c) 2015 Igalia
 * Copyright (c) 2015 Igalia S.L.
 * Copyright (c) 2015 Igalia.
 * Copyright (c) 2015, 2016 Canon Inc. All rights reserved.
 * Copyright (c) 2015, 2016, 2017 Canon Inc.
 * Copyright (c) 2016, 2018 -2018 Apple Inc. All rights reserved.
 * Copyright (c) 2016, 2020 Apple Inc. All rights reserved.
 * Copyright (c) 2022 Codeblog Corp. All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. AND ITS CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 * 
 */

// DO NOT EDIT THIS FILE. It is automatically generated from JavaScript files for
// builtins by the script: Source/JavaScriptCore/Scripts/generate-js-builtins.py

#include "config.h"
#include "OnigurumaRegExpPrototypeBuiltins.h"

#include "WebCoreJSClientData.h"
#include <JavaScriptCore/HeapInlines.h>
#include <JavaScriptCore/IdentifierInlines.h>
#include <JavaScriptCore/ImplementationVisibility.h>
#include <JavaScriptCore/Intrinsic.h>
#include <JavaScriptCore/JSCJSValueInlines.h>
#include <JavaScriptCore/JSCellInlines.h>
#include <JavaScriptCore/StructureInlines.h>
#include <JavaScriptCore/VM.h>

namespace WebCore {

const JSC::ConstructAbility s_onigurumaRegExpPrototypeAdvanceStringIndexCodeConstructAbility = JSC::ConstructAbility::CannotConstruct;
const JSC::ConstructorKind s_onigurumaRegExpPrototypeAdvanceStringIndexCodeConstructorKind = JSC::ConstructorKind::None;
const JSC::ImplementationVisibility s_onigurumaRegExpPrototypeAdvanceStringIndexCodeImplementationVisibility = JSC::ImplementationVisibility::Private;
const int s_onigurumaRegExpPrototypeAdvanceStringIndexCodeLength = 427;
static const JSC::Intrinsic s_onigurumaRegExpPrototypeAdvanceStringIndexCodeIntrinsic = JSC::NoIntrinsic;
const char* const s_onigurumaRegExpPrototypeAdvanceStringIndexCode =
    "(function (string, index, unicode)\n" \
    "{\n" \
    "    //\n" \
    "    \"use strict\";\n" \
    "\n" \
    "    if (!unicode)\n" \
    "        return index + 1;\n" \
    "\n" \
    "    if (index + 1 >= string.length)\n" \
    "        return index + 1;\n" \
    "\n" \
    "    var first = string.@charCodeAt(index);\n" \
    "    if (first < 0xD800 || first > 0xDBFF)\n" \
    "        return index + 1;\n" \
    "\n" \
    "    var second = string.@charCodeAt(index + 1);\n" \
    "    if (second < 0xDC00 || second > 0xDFFF)\n" \
    "        return index + 1;\n" \
    "\n" \
    "    return index + 2;\n" \
    "})\n" \
;

const JSC::ConstructAbility s_onigurumaRegExpPrototypeMatchSlowCodeConstructAbility = JSC::ConstructAbility::CannotConstruct;
const JSC::ConstructorKind s_onigurumaRegExpPrototypeMatchSlowCodeConstructorKind = JSC::ConstructorKind::None;
const JSC::ImplementationVisibility s_onigurumaRegExpPrototypeMatchSlowCodeImplementationVisibility = JSC::ImplementationVisibility::Private;
const int s_onigurumaRegExpPrototypeMatchSlowCodeLength = 796;
static const JSC::Intrinsic s_onigurumaRegExpPrototypeMatchSlowCodeIntrinsic = JSC::NoIntrinsic;
const char* const s_onigurumaRegExpPrototypeMatchSlowCode =
    "(function (regexp, str)\n" \
    "{\n" \
    "    \"use strict\";\n" \
    "\n" \
    "    if (!regexp.global)\n" \
    "        return regexp.exec(str);\n" \
    "    \n" \
    "    var unicode = regexp.unicode;\n" \
    "    regexp.lastIndex = 0;\n" \
    "    var resultList = [];\n" \
    "\n" \
    "    //\n" \
    "    //\n" \
    "    //\n" \
    "    var maximumReasonableMatchSize = 100000000;\n" \
    "\n" \
    "    while (true) {\n" \
    "        var result = regexp.exec(str);\n" \
    "        \n" \
    "        if (result === null) {\n" \
    "            if (resultList.length === 0)\n" \
    "                return null;\n" \
    "            return resultList;\n" \
    "        }\n" \
    "\n" \
    "        if (resultList.length > maximumReasonableMatchSize)\n" \
    "            @throwOutOfMemoryError();\n" \
    "\n" \
    "        var resultString = @toString(result[0]);\n" \
    "\n" \
    "        if (!resultString.length)\n" \
    "            regexp.lastIndex = @advanceStringIndex(str, regexp.lastIndex, unicode);\n" \
    "\n" \
    "        @arrayPush(resultList, resultString);\n" \
    "    }\n" \
    "})\n" \
;

const JSC::ConstructAbility s_onigurumaRegExpPrototypeMatchCodeConstructAbility = JSC::ConstructAbility::CannotConstruct;
const JSC::ConstructorKind s_onigurumaRegExpPrototypeMatchCodeConstructorKind = JSC::ConstructorKind::None;
const JSC::ImplementationVisibility s_onigurumaRegExpPrototypeMatchCodeImplementationVisibility = JSC::ImplementationVisibility::Public;
const int s_onigurumaRegExpPrototypeMatchCodeLength = 225;
static const JSC::Intrinsic s_onigurumaRegExpPrototypeMatchCodeIntrinsic = JSC::NoIntrinsic;
const char* const s_onigurumaRegExpPrototypeMatchCode =
    "(function (strArg)\n" \
    "{\n" \
    "    \"use strict\";\n" \
    "\n" \
    "    if (!@isObject(this))\n" \
    "        @throwTypeError(\"RegExp.prototype.@@match requires that |this| be an Object\");\n" \
    "\n" \
    "    var str = @toString(strArg);\n" \
    "\n" \
    "    return @matchSlow(this, str);\n" \
    "})\n" \
;

const JSC::ConstructAbility s_onigurumaRegExpPrototypeMatchAllCodeConstructAbility = JSC::ConstructAbility::CannotConstruct;
const JSC::ConstructorKind s_onigurumaRegExpPrototypeMatchAllCodeConstructorKind = JSC::ConstructorKind::None;
const JSC::ImplementationVisibility s_onigurumaRegExpPrototypeMatchAllCodeImplementationVisibility = JSC::ImplementationVisibility::Public;
const int s_onigurumaRegExpPrototypeMatchAllCodeLength = 2928;
static const JSC::Intrinsic s_onigurumaRegExpPrototypeMatchAllCodeIntrinsic = JSC::NoIntrinsic;
const char* const s_onigurumaRegExpPrototypeMatchAllCode =
    "(function (strArg)\n" \
    "{\n" \
    "    \"use strict\";\n" \
    "\n" \
    "    var regExp = this;\n" \
    "    if (!@isObject(regExp)) {\n" \
    "        @throwTypeError(\"RegExp.prototype.@@matchAll requires |this| to be an Object\");\n" \
    "    }\n" \
    "\n" \
    "    var string = @toString(strArg);\n" \
    "\n" \
    "    var Matcher = @speciesConstructor(regExp, @Bun.OnigurumaRegExp);\n" \
    "\n" \
    "    var flags = @toString(regExp.flags);\n" \
    "    var matcher = new Matcher(regExp.source, flags);\n" \
    "    matcher.lastIndex = @toLength(regExp.lastIndex);\n" \
    "\n" \
    "    var global = @stringIncludesInternal.@call(flags, \"g\");\n" \
    "    var fullUnicode = @stringIncludesInternal.@call(flags, \"u\");\n" \
    "\n" \
    "    var iterator = globalThis.Symbol.iterator;\n" \
    "\n" \
    "    var RegExpStringIterator = class RegExpStringIterator {\n" \
    "        constructor(regExp, string, global, fullUnicode)\n" \
    "        {\n" \
    "    \n" \
    "            @putByIdDirectPrivate(this, \"regExpStringIteratorRegExp\", regExp);\n" \
    "            @putByIdDirectPrivate(this, \"regExpStringIteratorString\", string);\n" \
    "            @putByIdDirectPrivate(this, \"regExpStringIteratorGlobal\", global);\n" \
    "            @putByIdDirectPrivate(this, \"regExpStringIteratorUnicode\", fullUnicode);\n" \
    "            @putByIdDirectPrivate(this, \"regExpStringIteratorDone\", false);\n" \
    "        }\n" \
    "\n" \
    "        next() {\n" \
    "            \"use strict\";\n" \
    "            if (!@isObject(this)) {\n" \
    "                @throwTypeError(\"%RegExpStringIteratorPrototype%.next requires |this| to be an Object\");\n" \
    "            }\n" \
    "        \n" \
    "            var done = @getByIdDirectPrivate(this, \"regExpStringIteratorDone\");\n" \
    "            if (done === @undefined) {\n" \
    "                @throwTypeError(\"%RegExpStringIteratorPrototype%.next requires |this| to be an RegExp String Iterator instance\");\n" \
    "            }\n" \
    "        \n" \
    "            if (done) {\n" \
    "                return { value: @undefined, done: true };\n" \
    "            }\n" \
    "        \n" \
    "            var regExp = @getByIdDirectPrivate(this, \"regExpStringIteratorRegExp\");\n" \
    "            var string = @getByIdDirectPrivate(this, \"regExpStringIteratorString\");\n" \
    "            var global = @getByIdDirectPrivate(this, \"regExpStringIteratorGlobal\");\n" \
    "            var fullUnicode = @getByIdDirectPrivate(this, \"regExpStringIteratorUnicode\");\n" \
    "            var match = regExp.exec(string);\n" \
    "            if (match === null) {\n" \
    "                @putByIdDirectPrivate(this, \"regExpStringIteratorDone\", true);\n" \
    "                return { value: @undefined, done: true };\n" \
    "            }\n" \
    "        \n" \
    "            if (global) {\n" \
    "                var matchStr = @toString(match[0]);\n" \
    "                if (matchStr === \"\") {\n" \
    "                    var thisIndex = @toLength(regExp.lastIndex);\n" \
    "                    regExp.lastIndex = @advanceStringIndex(string, thisIndex, fullUnicode);\n" \
    "                }\n" \
    "            } else\n" \
    "                @putByIdDirectPrivate(this, \"regExpStringIteratorDone\", true);\n" \
    "        \n" \
    "            return { value: match, done: false };\n" \
    "        }\n" \
    "\n" \
    "        [iterator]() {\n" \
    "            return this;\n" \
    "        }\n" \
    "\n" \
    "    };\n" \
    "\n" \
    "    return new RegExpStringIterator(matcher, string, global, fullUnicode);\n" \
    "})\n" \
;

const JSC::ConstructAbility s_onigurumaRegExpPrototypeGetSubstitutionCodeConstructAbility = JSC::ConstructAbility::CannotConstruct;
const JSC::ConstructorKind s_onigurumaRegExpPrototypeGetSubstitutionCodeConstructorKind = JSC::ConstructorKind::None;
const JSC::ImplementationVisibility s_onigurumaRegExpPrototypeGetSubstitutionCodeImplementationVisibility = JSC::ImplementationVisibility::Private;
const int s_onigurumaRegExpPrototypeGetSubstitutionCodeLength = 3603;
static const JSC::Intrinsic s_onigurumaRegExpPrototypeGetSubstitutionCodeIntrinsic = JSC::NoIntrinsic;
const char* const s_onigurumaRegExpPrototypeGetSubstitutionCode =
    "(function (matched, str, position, captures, namedCaptures, replacement)\n" \
    "{\n" \
    "    \"use strict\";\n" \
    "\n" \
    "    var matchLength = matched.length;\n" \
    "    var stringLength = str.length;\n" \
    "    var tailPos = position + matchLength;\n" \
    "    var m = captures.length;\n" \
    "    var replacementLength = replacement.length;\n" \
    "    var result = \"\";\n" \
    "    var lastStart = 0;\n" \
    "\n" \
    "    for (var start = 0; start = @stringIndexOfInternal.@call(replacement, \"$\", lastStart), start !== -1; lastStart = start) {\n" \
    "        if (start - lastStart > 0)\n" \
    "            result = result + @stringSubstring.@call(replacement, lastStart, start);\n" \
    "        start++;\n" \
    "        if (start >= replacementLength)\n" \
    "            result = result + \"$\";\n" \
    "        else {\n" \
    "            var ch = replacement[start];\n" \
    "            switch (ch)\n" \
    "            {\n" \
    "            case \"$\":\n" \
    "                result = result + \"$\";\n" \
    "                start++;\n" \
    "                break;\n" \
    "            case \"&\":\n" \
    "                result = result + matched;\n" \
    "                start++;\n" \
    "                break;\n" \
    "            case \"`\":\n" \
    "                if (position > 0)\n" \
    "                    result = result + @stringSubstring.@call(str, 0, position);\n" \
    "                start++;\n" \
    "                break;\n" \
    "            case \"'\":\n" \
    "                if (tailPos < stringLength)\n" \
    "                    result = result + @stringSubstring.@call(str, tailPos);\n" \
    "                start++;\n" \
    "                break;\n" \
    "            case \"<\":\n" \
    "                if (namedCaptures !== @undefined) {\n" \
    "                    var groupNameStartIndex = start + 1;\n" \
    "                    var groupNameEndIndex = @stringIndexOfInternal.@call(replacement, \">\", groupNameStartIndex);\n" \
    "                    if (groupNameEndIndex !== -1) {\n" \
    "                        var groupName = @stringSubstring.@call(replacement, groupNameStartIndex, groupNameEndIndex);\n" \
    "                        var capture = namedCaptures[groupName];\n" \
    "                        if (capture !== @undefined)\n" \
    "                            result = result + @toString(capture);\n" \
    "\n" \
    "                        start = groupNameEndIndex + 1;\n" \
    "                        break;\n" \
    "                    }\n" \
    "                }\n" \
    "\n" \
    "                result = result + \"$<\";\n" \
    "                start++;\n" \
    "                break;\n" \
    "            default:\n" \
    "                var chCode = ch.@charCodeAt(0);\n" \
    "                if (chCode >= 0x30 && chCode <= 0x39) {\n" \
    "                    var originalStart = start - 1;\n" \
    "                    start++;\n" \
    "\n" \
    "                    var n = chCode - 0x30;\n" \
    "                    if (n > m) {\n" \
    "                        result = result + @stringSubstring.@call(replacement, originalStart, start);\n" \
    "                        break;\n" \
    "                    }\n" \
    "\n" \
    "                    if (start < replacementLength) {\n" \
    "                        var nextChCode = replacement.@charCodeAt(start);\n" \
    "                        if (nextChCode >= 0x30 && nextChCode <= 0x39) {\n" \
    "                            var nn = 10 * n + nextChCode - 0x30;\n" \
    "                            if (nn <= m) {\n" \
    "                                n = nn;\n" \
    "                                start++;\n" \
    "                            }\n" \
    "                        }\n" \
    "                    }\n" \
    "\n" \
    "                    if (n == 0) {\n" \
    "                        result = result + @stringSubstring.@call(replacement, originalStart, start);\n" \
    "                        break;\n" \
    "                    }\n" \
    "\n" \
    "                    var capture = captures[n - 1];\n" \
    "                    if (capture !== @undefined)\n" \
    "                        result = result + capture;\n" \
    "                } else\n" \
    "                    result = result + \"$\";\n" \
    "                break;\n" \
    "            }\n" \
    "        }\n" \
    "    }\n" \
    "\n" \
    "    return result + @stringSubstring.@call(replacement, lastStart);\n" \
    "})\n" \
;

const JSC::ConstructAbility s_onigurumaRegExpPrototypeReplaceCodeConstructAbility = JSC::ConstructAbility::CannotConstruct;
const JSC::ConstructorKind s_onigurumaRegExpPrototypeReplaceCodeConstructorKind = JSC::ConstructorKind::None;
const JSC::ImplementationVisibility s_onigurumaRegExpPrototypeReplaceCodeImplementationVisibility = JSC::ImplementationVisibility::Public;
const int s_onigurumaRegExpPrototypeReplaceCodeLength = 3208;
static const JSC::Intrinsic s_onigurumaRegExpPrototypeReplaceCodeIntrinsic = JSC::NoIntrinsic;
const char* const s_onigurumaRegExpPrototypeReplaceCode =
    "(function (strArg, replace)\n" \
    "{\n" \
    "    \"use strict\";\n" \
    "\n" \
    "    if (!@isObject(this))\n" \
    "        @throwTypeError(\"RegExp.prototype.@@replace requires that |this| be an Object\");\n" \
    "\n" \
    "    var regexp = this;\n" \
    "\n" \
    "    var str = @toString(strArg);\n" \
    "    var stringLength = str.length;\n" \
    "    var functionalReplace = @isCallable(replace);\n" \
    "\n" \
    "    if (!functionalReplace)\n" \
    "        replace = @toString(replace);\n" \
    "\n" \
    "    var global = regexp.global;\n" \
    "    var unicode = false;\n" \
    "\n" \
    "    if (global) {\n" \
    "        unicode = regexp.unicode;\n" \
    "        regexp.lastIndex = 0;\n" \
    "    }\n" \
    "\n" \
    "    var resultList = [];\n" \
    "    var result;\n" \
    "    var done = false;\n" \
    "    while (!done) {\n" \
    "        result = regexp.exec(str);\n" \
    "\n" \
    "        if (result === null)\n" \
    "            done = true;\n" \
    "        else {\n" \
    "            @arrayPush(resultList, result);\n" \
    "            if (!global)\n" \
    "                done = true;\n" \
    "            else {\n" \
    "                var matchStr = @toString(result[0]);\n" \
    "\n" \
    "                if (!matchStr.length) {\n" \
    "                    var thisIndex = @toLength(regexp.lastIndex);\n" \
    "                    regexp.lastIndex = @advanceStringIndex(str, thisIndex, unicode);\n" \
    "                }\n" \
    "            }\n" \
    "        }\n" \
    "    }\n" \
    "\n" \
    "    var accumulatedResult = \"\";\n" \
    "    var nextSourcePosition = 0;\n" \
    "\n" \
    "    for (var i = 0, resultListLength = resultList.length; i < resultListLength; ++i) {\n" \
    "        var result = resultList[i];\n" \
    "        var nCaptures = result.length - 1;\n" \
    "        if (nCaptures < 0)\n" \
    "            nCaptures = 0;\n" \
    "        var matched = @toString(result[0]);\n" \
    "        var matchLength = matched.length;\n" \
    "        var position = @toIntegerOrInfinity(result.index);\n" \
    "        position = (position > stringLength) ? stringLength : position;\n" \
    "        position = (position < 0) ? 0 : position;\n" \
    "\n" \
    "        var captures = [];\n" \
    "        for (var n = 1; n <= nCaptures; n++) {\n" \
    "            var capN = result[n];\n" \
    "            if (capN !== @undefined)\n" \
    "                capN = @toString(capN);\n" \
    "            @arrayPush(captures, capN);\n" \
    "        }\n" \
    "\n" \
    "        var replacement;\n" \
    "        var namedCaptures = result.groups;\n" \
    "\n" \
    "        if (functionalReplace) {\n" \
    "            var replacerArgs = [ matched ];\n" \
    "            for (var j = 0; j < captures.length; j++)\n" \
    "                @arrayPush(replacerArgs, captures[j]);\n" \
    "\n" \
    "            @arrayPush(replacerArgs, position);\n" \
    "            @arrayPush(replacerArgs, str);\n" \
    "\n" \
    "            if (namedCaptures !== @undefined)\n" \
    "                @arrayPush(replacerArgs, namedCaptures);\n" \
    "\n" \
    "            var replValue = replace.@apply(@undefined, replacerArgs);\n" \
    "            replacement = @toString(replValue);\n" \
    "        } else {\n" \
    "            if (namedCaptures !== @undefined)\n" \
    "                namedCaptures = @toObject(namedCaptures, \"RegExp.prototype[Symbol.replace] requires 'groups' property of a match not be null\");\n" \
    "\n" \
    "            replacement = @getSubstitution(matched, str, position, captures, namedCaptures, replace);\n" \
    "        }\n" \
    "\n" \
    "        if (position >= nextSourcePosition) {\n" \
    "            accumulatedResult = accumulatedResult + @stringSubstring.@call(str, nextSourcePosition, position) + replacement;\n" \
    "            nextSourcePosition = position + matchLength;\n" \
    "        }\n" \
    "    }\n" \
    "\n" \
    "    if (nextSourcePosition >= stringLength)\n" \
    "        return  accumulatedResult;\n" \
    "\n" \
    "    return accumulatedResult + @stringSubstring.@call(str, nextSourcePosition);\n" \
    "})\n" \
;

const JSC::ConstructAbility s_onigurumaRegExpPrototypeSearchCodeConstructAbility = JSC::ConstructAbility::CannotConstruct;
const JSC::ConstructorKind s_onigurumaRegExpPrototypeSearchCodeConstructorKind = JSC::ConstructorKind::None;
const JSC::ImplementationVisibility s_onigurumaRegExpPrototypeSearchCodeImplementationVisibility = JSC::ImplementationVisibility::Public;
const int s_onigurumaRegExpPrototypeSearchCodeLength = 631;
static const JSC::Intrinsic s_onigurumaRegExpPrototypeSearchCodeIntrinsic = JSC::NoIntrinsic;
const char* const s_onigurumaRegExpPrototypeSearchCode =
    "(function (strArg)\n" \
    "{\n" \
    "    \"use strict\";\n" \
    "\n" \
    "    var regexp = this;\n" \
    "\n" \
    "    //\n" \
    "    //\n" \
    "    if (!@isObject(this))\n" \
    "        @throwTypeError(\"RegExp.prototype.@@search requires that |this| be an Object\");\n" \
    "\n" \
    "    //\n" \
    "    var str = @toString(strArg)\n" \
    "\n" \
    "    //\n" \
    "    var previousLastIndex = regexp.lastIndex;\n" \
    "\n" \
    "    //\n" \
    "    //\n" \
    "    if (!@sameValue(previousLastIndex, 0))\n" \
    "        regexp.lastIndex = 0;\n" \
    "\n" \
    "    //\n" \
    "    var result = regexp.exec(str);\n" \
    "\n" \
    "    //\n" \
    "    //\n" \
    "    //\n" \
    "    if (!@sameValue(regexp.lastIndex, previousLastIndex))\n" \
    "        regexp.lastIndex = previousLastIndex;\n" \
    "\n" \
    "    //\n" \
    "    if (result === null)\n" \
    "        return -1;\n" \
    "\n" \
    "    //\n" \
    "    return result.index;\n" \
    "})\n" \
;

const JSC::ConstructAbility s_onigurumaRegExpPrototypeSplitCodeConstructAbility = JSC::ConstructAbility::CannotConstruct;
const JSC::ConstructorKind s_onigurumaRegExpPrototypeSplitCodeConstructorKind = JSC::ConstructorKind::None;
const JSC::ImplementationVisibility s_onigurumaRegExpPrototypeSplitCodeImplementationVisibility = JSC::ImplementationVisibility::Public;
const int s_onigurumaRegExpPrototypeSplitCodeLength = 2926;
static const JSC::Intrinsic s_onigurumaRegExpPrototypeSplitCodeIntrinsic = JSC::NoIntrinsic;
const char* const s_onigurumaRegExpPrototypeSplitCode =
    "(function (string, limit)\n" \
    "{\n" \
    "    \"use strict\";\n" \
    "\n" \
    "    //\n" \
    "    //\n" \
    "    if (!@isObject(this))\n" \
    "        @throwTypeError(\"RegExp.prototype.@@split requires that |this| be an Object\");\n" \
    "    var regexp = this;\n" \
    "\n" \
    "    //\n" \
    "    var str = @toString(string);\n" \
    "\n" \
    "    //\n" \
    "    var speciesConstructor = @speciesConstructor(regexp, @RegExp);\n" \
    "\n" \
    "    //\n" \
    "    var flags = @toString(regexp.flags);\n" \
    "\n" \
    "    //\n" \
    "    //\n" \
    "    var unicodeMatching = @stringIncludesInternal.@call(flags, \"u\");\n" \
    "    //\n" \
    "    //\n" \
    "    var newFlags = @stringIncludesInternal.@call(flags, \"y\") ? flags : flags + \"y\";\n" \
    "\n" \
    "    //\n" \
    "    var splitter = new speciesConstructor(regexp.source, newFlags);\n" \
    "\n" \
    "    //\n" \
    "    //\n" \
    "\n" \
    "    //\n" \
    "    //\n" \
    "    var result = [];\n" \
    "\n" \
    "    //\n" \
    "    limit = (limit === @undefined) ? 0xffffffff : limit >>> 0;\n" \
    "\n" \
    "    //\n" \
    "    if (!limit)\n" \
    "        return result;\n" \
    "\n" \
    "    //\n" \
    "    var size = str.length;\n" \
    "\n" \
    "    //\n" \
    "    if (!size) {\n" \
    "        //\n" \
    "        var z = splitter.exec(str);\n" \
    "        //\n" \
    "        if (z !== null)\n" \
    "            return result;\n" \
    "        //\n" \
    "        @putByValDirect(result, 0, str);\n" \
    "        //\n" \
    "        return result;\n" \
    "    }\n" \
    "\n" \
    "    //\n" \
    "    var position = 0;\n" \
    "    //\n" \
    "    var matchPosition = 0;\n" \
    "\n" \
    "    //\n" \
    "    while (matchPosition < size) {\n" \
    "        //\n" \
    "        splitter.lastIndex = matchPosition;\n" \
    "        //\n" \
    "        var matches = splitter.exec(str);\n" \
    "        //\n" \
    "        if (matches === null)\n" \
    "            matchPosition = @advanceStringIndex(str, matchPosition, unicodeMatching);\n" \
    "        //\n" \
    "        else {\n" \
    "            //\n" \
    "            var endPosition = @toLength(splitter.lastIndex);\n" \
    "            //\n" \
    "            endPosition = (endPosition <= size) ? endPosition : size;\n" \
    "            //\n" \
    "            if (endPosition === position)\n" \
    "                matchPosition = @advanceStringIndex(str, matchPosition, unicodeMatching);\n" \
    "            //\n" \
    "            else {\n" \
    "                //\n" \
    "                var subStr = @stringSubstring.@call(str, position, matchPosition);\n" \
    "                //\n" \
    "                //\n" \
    "                @arrayPush(result, subStr);\n" \
    "                //\n" \
    "                if (result.length == limit)\n" \
    "                    return result;\n" \
    "\n" \
    "                //\n" \
    "                position = endPosition;\n" \
    "                //\n" \
    "                //\n" \
    "                var numberOfCaptures = matches.length > 1 ? matches.length - 1 : 0;\n" \
    "\n" \
    "                //\n" \
    "                var i = 1;\n" \
    "                //\n" \
    "                while (i <= numberOfCaptures) {\n" \
    "                    //\n" \
    "                    var nextCapture = matches[i];\n" \
    "                    //\n" \
    "                    //\n" \
    "                    @arrayPush(result, nextCapture);\n" \
    "                    //\n" \
    "                    if (result.length == limit)\n" \
    "                        return result;\n" \
    "                    //\n" \
    "                    i++;\n" \
    "                }\n" \
    "                //\n" \
    "                matchPosition = position;\n" \
    "            }\n" \
    "        }\n" \
    "    }\n" \
    "    //\n" \
    "    var remainingStr = @stringSubstring.@call(str, position, size);\n" \
    "    //\n" \
    "    @arrayPush(result, remainingStr);\n" \
    "    //\n" \
    "    return result;\n" \
    "})\n" \
;

const JSC::ConstructAbility s_onigurumaRegExpPrototypeTestCodeConstructAbility = JSC::ConstructAbility::CannotConstruct;
const JSC::ConstructorKind s_onigurumaRegExpPrototypeTestCodeConstructorKind = JSC::ConstructorKind::None;
const JSC::ImplementationVisibility s_onigurumaRegExpPrototypeTestCodeImplementationVisibility = JSC::ImplementationVisibility::Public;
const int s_onigurumaRegExpPrototypeTestCodeLength = 452;
static const JSC::Intrinsic s_onigurumaRegExpPrototypeTestCodeIntrinsic = JSC::NoIntrinsic;
const char* const s_onigurumaRegExpPrototypeTestCode =
    "(function (strArg)\n" \
    "{\n" \
    "    \"use strict\";\n" \
    "\n" \
    "    var regexp = this;\n" \
    "\n" \
    "    if (regexp.test == @Bun.OnigurumaRegExp.prototype.test) {\n" \
    "        return regexp.test(strArg);\n" \
    "    }\n" \
    "\n" \
    "    //\n" \
    "    //\n" \
    "    if (!@isObject(regexp))\n" \
    "        @throwTypeError(\"RegExp.prototype.test requires that |this| be an Object\");\n" \
    "\n" \
    "    //\n" \
    "    var str = @toString(strArg);\n" \
    "\n" \
    "    //\n" \
    "    var match = regexp.exec(str);\n" \
    "\n" \
    "    //\n" \
    "    if (match !== null)\n" \
    "        return true;\n" \
    "    return false;\n" \
    "})\n" \
;


#define DEFINE_BUILTIN_GENERATOR(codeName, functionName, overriddenName, argumentCount) \
JSC::FunctionExecutable* codeName##Generator(JSC::VM& vm) \
{\
    JSVMClientData* clientData = static_cast<JSVMClientData*>(vm.clientData); \
    return clientData->builtinFunctions().onigurumaRegExpPrototypeBuiltins().codeName##Executable()->link(vm, nullptr, clientData->builtinFunctions().onigurumaRegExpPrototypeBuiltins().codeName##Source(), std::nullopt, s_##codeName##Intrinsic); \
}
WEBCORE_FOREACH_ONIGURUMAREGEXPPROTOTYPE_BUILTIN_CODE(DEFINE_BUILTIN_GENERATOR)
#undef DEFINE_BUILTIN_GENERATOR


} // namespace WebCore
