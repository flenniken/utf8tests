import std/os
import std/unittest
import std/strutils
import std/strformat
import std/unicode
import writevalidutf8file
import checks
import utf8decoder

suite "writevalidutf8file.nim":

  test "validateUtf8":
    check validateUtf8("") == -1
    check validateUtf8("a") == -1
    check validateUtf8("ab") == -1
    check validateUtf8("aÂâð♘☺🃞") == -1

    check validateUtf8("\xff") == 0
    check validateUtf8("\xffabc") == 0
    check validateUtf8("ab\xffc") == 2
    check validateUtf8("abc\xff") == 3

  test "validateUtf8 too big":
    # U+10FFFF, biggest code point, <F4 8F BF BF>
    check validateUtf8("\xf4\x8f\xbf\xbf") == -1
    check validateUtf8("\u{10FFFF}") == -1

    # \u{110000} generates a compile error as expected.
    # check validateUtf8("\u{110000}") == 0

    # too big  110000, <F4 90 80 80>
    if validateUtf8("\xf4\x90\x80\x80") != 0:
      echo "validateUtf8 allows U+110000"

    # too big U+00200000, <f8 88 80 80 80>
    if validateUtf8("\xf8\x88\x80\x80\x80") != 0:
      echo "validateUtf8 allows U+00200000"

    # too big U+03FFFFFF, <F7 BF BF BF BF>
    if validateUtf8("\xF7\xBF\xBF\xBF\xBF") != 0:
      echo "validateUtf8 allows U+03FFFFFF"

    # too big U+04000000, <fc 84 80 80 80 80>
    if validateUtf8("\xfc\x84\x80\x80\x80\x80") != 0:
      echo "validateUtf8 allows U+04000000"

    # too big U+7FFFFFFF, <F7 BF BF BF BF BF>
    if validateUtf8("\xF7\xBF\xBF\xBF\xBF\xBF") != 0:
      echo "validateUtf8 allows U+7FFFFFFF"

  test "validateUtf8 surrogates":

    # U+D800 to U+DBFF -- high surrogates
    # U+DC00 to U+DFFF -- low surrogates

    # 1 surrogate U+D800, <ed a0 80>

    if validateUtf8("\xed\xa0\x80") != 0:
      echo "validateUtf8 allows surrogate U+D800"
    if validateUtf8("\xED\xAF\xBF") != 0:
      echo "validateUtf8 allows surrogate U+DBFF"
    if validateUtf8("\xED\xB0\x80") != 0:
      echo "validateUtf8 allows surrogate U+DC00"
    if validateUtf8("\xED\xBF\xBF") != 0:
      echo "validateUtf8 allows surrogate U+DFFF"

  test "validateUtf8 overlong":
    # overlong solidus <c0 af>
    check validateUtf8("\xc0\xaf") == 0

    # overlong solidus <e0 80 af>
    if validateUtf8("\xe0\x80\xaf") == -1:
      echo "validateUtf8 allows overlong solidus 2"

    if validateUtf8("\xf0\x80\x80\xaf") == -1:
      echo "validateUtf8 allows overlong solidus 3"

    # overlong solidus <f8 80 80 80 af>
    let str4 = "\xf0\x80\x80\x80\xaf"
    if validateUtf8(str4) != 0:
      echo "validateUtf8 allows overlong solidus 4"
    check validateUtf8String(str4) == 0

    # overlong solidus <fc 80 80 80 80 af>
    let str5 = "\xf0\x80\x80\x80\x80\xaf"
    if validateUtf8(str5) != 0:
      echo "validateUtf8 allows overlong solidus 5"
    check validateUtf8String(str5) == 0

  test "$ - runes to string":
    check $(@[Rune(0x31), Rune(0x32), Rune(0x33)]) == "123"

    # U+D800 to U+DBFF -- high surrogates
    # U+DC00 to U+DFFF -- low surrogates
    if $(@[Rune(0xD800)]) == "\uD800":
      echo "$ allows surrogates"

    # Rune too big.
    echo stringToHex($(@[Rune(0x110000)]))


  test "sanitizeUtf8Nim":
    check sanitizeUtf8Nim("abc") == "abc"
    check sanitizeUtf8Nim("abc", "skip") == "abc"
    check sanitizeUtf8Nim("ab\xffc", "skip") == "abc"
    check sanitizeUtf8Nim("\xffabc", "skip") == "abc"
    check sanitizeUtf8Nim("abc\xff", "skip") == "abc"
    check sanitizeUtf8Nim("\xff", "skip") == ""
    check sanitizeUtf8Nim("\xff\xff\xff", "skip") == ""
    check sanitizeUtf8Nim("a\xff\xffb", "skip") == "ab"
    check sanitizeUtf8Nim("", "skip") == ""

  test "generate utf8tests.bin":
    # Re-generate the utf8tests.bin file when the utf8tests.txt file changes.
    if not fileExists(binTestCases) or fileNewer(testCases, binTestCases):
      echo "generating file: " & binTestCases
      let msg = createUtf8testsBinFile(binTestCases)
      check msg == ""
      echo "run the tests again"
      fail()

  test "generate utf8tests.html":
    # Re-generate the utf8tests.html file when the utf8tests.txt file changes.
    if not fileExists(htmlTestCases) or fileNewer(testCases, htmlTestCases):
      echo "generating file: " & htmlTestCases
      let msg = createUtf8testsHtmlFile(htmlTestCases)
      check msg == ""

  test "generate artifacts":
    type
      Decoder = object
        name: string
        writeProc: WriteValidUtf8File
        artifactOnly: bool
        skipOrReplace: string
        passOrFail: string

    func newDecoder(name: string, writeProc: WriteValidUtf8File,
        artifactOnly: bool, skipOrReplace: string,
        passOrFail: string): Decoder =
      result = Decoder(name: name, writeProc: writeProc,
        artifactOnly: artifactOnly, skipOrReplace: skipOrReplace,
        passOrFail: passOrFail)

    let decoders = [
      newDecoder("emacs.25.3.1", writeNothing, true, "replace", "fail"),
      newDecoder("iconv.1.11", writeValidUtf8FileIconv, false, "skip", "fail"),
      newDecoder("nim.1.4.8", writeValidUtf8FileNim, false, "skip", "fail"),
      newDecoder("nodejs.17.2.0", writeValidUtf8FileNodeJs, false, "replace", "pass"),
      newDecoder("perl.5.30.2", writeValidUtf8FilePerl, false, "replace", "fail"),
      newDecoder("python.3.7.5", writeValidUtf8FilePython3, false, "skip", "pass"),
      newDecoder("python.3.7.5", writeValidUtf8FilePython3, false, "replace", "pass"),
      newDecoder("ref", writeValidUtf8Ref, false, "skip", "pass"),
      newDecoder("ref", writeValidUtf8Ref, false, "replace", "pass"),
    ]
    for decoder in decoders:
      let skipOrReplace = decoder.skipOrReplace
      let artifactName = "artifacts/utf8.$1.$2.txt" % [skipOrReplace, decoder.name]
      var rc: int

      # Generate the artifact.
      if not decoder.artifactOnly:
        rc = decoder.writeProc(binTestCases, artifactName, skipOrReplace)
        if rc != 0:
          echo decoder.name
        check rc == 0

      # Check the artifact.
      rc = checkFile(binTestCases, artifactName, skipOrReplace, echoOut=false)

      if rc != 0 and decoder.passOrFail == "pass":
        echo fmt"{decoder.name} {skipOrReplace} failed the tests."
        fail()
      elif rc == 0 and decoder.passOrFail == "fail":
        echo fmt"{decoder.name} {skipOrReplace} was expected to fail but it passed."
        fail()
