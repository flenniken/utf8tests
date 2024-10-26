import std/os
import std/unittest
import std/strutils
import std/strformat
import std/unicode
import writevalidutf8file
import checks
import utf8decoder
import opresult

proc testPerlDecodeEcho(hexStr: string, eHexStr: string): bool =
  ## Test Perl decoding a string. If the decoded string does not equal
  ## the expected string show the result to the screen.

  let inFilename = "perlReplacementTests.txt"
  let outFilename = "perlOut.txt"

  let strOr = hexToString(hexStr)
  if strOr.isMessage:
    echo strOr.message
    return false
  let str = strOr.value

  let eStrOr = hexToString(eHexStr)
  if eStrOr.isMessage:
    echo eStrOr.message
    return false
  let eStr = eStrOr.value

  createFile(inFilename, str)
  check writeValidUtf8FilePerl(inFilename, outFilename) == 0
  let outContents = readFile(outFilename)
  if outContents != eStr:
    echo "Perl decode: " & hexStr
    echo "expected: " & eHexStr
    echo "     got: " & stringToHex(outContents)
    echo ""
  discard tryRemoveFile(inFilename)
  discard tryRemoveFile(outFilename)


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
      echo "Nim validateUtf8 allows U+110000"

    # too big U+00200000, <f8 88 80 80 80>
    if validateUtf8("\xf8\x88\x80\x80\x80") != 0:
      echo "Nim validateUtf8 allows U+00200000"

    # too big U+03FFFFFF, <F7 BF BF BF BF>
    if validateUtf8("\xF7\xBF\xBF\xBF\xBF") != 0:
      echo "Nim validateUtf8 allows U+03FFFFFF"

    # too big U+04000000, <fc 84 80 80 80 80>
    if validateUtf8("\xfc\x84\x80\x80\x80\x80") != 0:
      echo "Nim validateUtf8 allows U+04000000"

    # too big U+7FFFFFFF, <F7 BF BF BF BF BF>
    if validateUtf8("\xF7\xBF\xBF\xBF\xBF\xBF") != 0:
      echo "Nim validateUtf8 allows U+7FFFFFFF"

  test "validateUtf8 surrogates":

    # U+D800 to U+DBFF -- high surrogates
    # U+DC00 to U+DFFF -- low surrogates

    # 1 surrogate U+D800, <ed a0 80>

    if validateUtf8("\xed\xa0\x80") != 0:
      echo "Nim validateUtf8 allows surrogate U+D800"
    if validateUtf8("\xED\xAF\xBF") != 0:
      echo "Nim validateUtf8 allows surrogate U+DBFF"
    if validateUtf8("\xED\xB0\x80") != 0:
      echo "Nim validateUtf8 allows surrogate U+DC00"
    if validateUtf8("\xED\xBF\xBF") != 0:
      echo "Nim validateUtf8 allows surrogate U+DFFF"

  test "validateUtf8 overlong":
    # overlong solidus <c0 af>
    check validateUtf8("\xc0\xaf") == 0

    # overlong solidus <e0 80 af>
    if validateUtf8("\xe0\x80\xaf") == -1:
      echo "Nim validateUtf8 allows overlong solidus 2"

    if validateUtf8("\xf0\x80\x80\xaf") == -1:
      echo "Nim validateUtf8 allows overlong solidus 3"

    # overlong solidus <f8 80 80 80 af>
    let str4 = "\xf0\x80\x80\x80\xaf"
    if validateUtf8(str4) != 0:
      echo "Nim validateUtf8 allows overlong solidus 4"
    check validateUtf8String(str4) == 0

    # overlong solidus <fc 80 80 80 80 af>
    let str5 = "\xf0\x80\x80\x80\x80\xaf"
    if validateUtf8(str5) != 0:
      echo "Nim validateUtf8 allows overlong solidus 5"
    check validateUtf8String(str5) == 0

  test "$ - runes to string":
    check $(@[Rune(0x31), Rune(0x32), Rune(0x33)]) == "123"

    # U+D800 to U+DBFF -- high surrogates
    # U+DC00 to U+DFFF -- low surrogates
    if $(@[Rune(0xD800)]) == "\uD800":
      echo "Nim unicode $ allows surrogates"

    # Rune too big.
    echo "Nim Rune allows rune 0x110000: " & stringToHex($(@[Rune(0x110000)]))


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
      # newDecoder("nodejs.17.2.0", writeValidUtf8FileNodeJs, false, "replace", "pass"),
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

  test "consistent replacement":
    check sanitizeUtf8("") == ""
    check sanitizeUtf8("a") == "a"
    check sanitizeUtf8("ab") == "ab"
    check sanitizeUtf8("abc") == "abc"
    check sanitizeUtf8("\xff") == "\ufffd"
    check sanitizeUtf8("\xffa") == "\ufffda"
    check sanitizeUtf8("a\xff") == "a\ufffd"
    check sanitizeUtf8("\xff\xff") == "\ufffd\ufffd"
    check sanitizeUtf8("\xc2T") == "\ufffdT"
    check sanitizeUtf8("\xe1\x80T") == "\ufffdT"
    check sanitizeUtf8("\xf4\x80\x80T") == "\ufffdT"
    check sanitizeUtf8("\xe0\xa0T") == "\ufffdT"

    check sanitizeUtf8("\xff\xff\xff") == "\ufffd\ufffd\ufffd"
    # echo "     got: " & stringToHex(sanitizeUtf8("\xf1\x80\xf3\x80\x80\xc2\x80T"))
    check sanitizeUtf8("\xf1\x80\xf3\x80\x80\xc2\x80T") == "\ufffd\ufffd\xc2\x80T"

  test "Perl tests":
    let testCases = [
      ["e0 80 7f", "ef bf bd ef bf bd 7f"],
      ["e0 80 80", "ef bf bd ef bf bd ef bf bd"],
      ["f0 80 80 80", "ef bf bd ef bf bd ef bf bd ef bf bd"],
      ["ed ae 80 ed b0 80", "ef bf bd ef bf bd ef bf bd ef bf bd ef bf bd ef bf bd"],
      ["f1 80 80 f4 80 80 c2 80", "ef bf bd ef bf bd c2 80"], # this one is ok
      ["ef bf be", "ef bf be"], # U+FFFE
    ]

    # ed ae 80 ed b0 80
    #
    # ed ae is invalid
    # ae is invalid
    # 80 is invalid
    # ed b0 is invalid
    # b0 is invalid
    # 80 is invalid

    for testCase in testCases:
      let hexStr = testCase[0]
      let eHexStr = testCase[1]
      let eHexStr2 = stringToHex(sanitizeUtf8(hexToString(hexStr).value))
      check eHexStr == eHexStr2

      discard testPerlDecodeEcho(hexStr, eHexStr)
