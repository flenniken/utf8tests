import std/os
import std/unittest
import std/strutils
import writevalidutf8file
import checks

proc generateArtifacts(name: string, writeProc: WriteValidUtf8File,
    options = @["skip", "replace"]): int =
  ## Generate the skip and/or replace artifacts for the given name.

  for skipOrReplace in options:
    if not (skipOrReplace in ["skip", "replace"]):
      echo "Invalid option, expected skip or replace."
      return 1
    let filename = "artifacts/utf8.$1.$2.txt" % [skipOrReplace, name]
    let rc = writeProc(binTestCases, filename, skipOrReplace)
    if rc != 0:
      result = rc

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

  test "generate reference artifacts":
    let rc = generateArtifacts("ref", writeValidUtf8Ref)
    check rc == 0

  test "generate nim artifacts":
    let rc = generateArtifacts("nim.1.4.8", writeValidUtf8FileNim, @["skip"])
    check rc == 0

  test "generate python3 artifacts":
    let rc = generateArtifacts("python.3.7.5", writeValidUtf8FilePython3)
    check rc == 0

  test "generate node.js artifacts":
    let rc = generateArtifacts("nodejs.17.2.0", writeValidUtf8FileNodeJs, @["replace"])
    check rc == 0

  test "generate iconv artifacts":
    let rc = generateArtifacts("iconv.1.11", writeValidUtf8FileIconv, @["skip"])
    check rc == 0

  test "generate perl artifacts":
    let rc = generateArtifacts("perl.5.30.2", writeValidUtf8FilePerl, @["replace"])
    check rc == 0
