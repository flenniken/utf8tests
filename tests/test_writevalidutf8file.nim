import std/os
import std/unittest
import std/strutils
import std/strformat
import writevalidutf8file
import checks

suite "writevalidutf8file.nim":

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

  test "generate utf8browser.txt":
    # Re-generate the utf8BrowserTests.txt file when the utf8tests.txt file changes.
    if not fileExists(browserTestCases) or fileNewer(testCases, browserTestCases):
      echo "generating file: " & browserTestCases
      let msg = createUtf8testsBinFile(browserTestCases, true)
      check msg == ""
      echo "run the tests again"
      fail()

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
      newDecoder("emacs.25.3.1", writeNothing, true, "skip", "pass"),
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
        echo fmt"{decoder.name} failed the tests."
        fail()
      elif rc == 0 and decoder.passOrFail == "fail":
        echo fmt"{decoder.name} was expected to fail but it passed."
        fail()
