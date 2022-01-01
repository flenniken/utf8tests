import std/os
import std/unittest
import std/strutils
import writevalidutf8file
import checks

proc generateArtifacts(name: string, writeProc: WriteValidUtf8File): int =
  ## Generate the skip and replace artifacts for the given name.

  var options = ["skip", "replace"]
  for ix in [0, 1]:
    let skipOrReplace = options[ix]
    let filename = "artifacts/utf8.$1.$2.txt" % [skipOrReplace, name]
    if not fileExists(filename) or fileNewer(binTestCases, filename):
      echo "generating file: " & filename
      let rc = writeProc(binTestCases, filename, skipOrReplace)
      if rc != 0:
        result = rc



suite "writevalidutf8file.nim":

  test "sanitizeUtf8Nim":
    check sanitizeUtf8Nim("abc") == "abc"
    check sanitizeUtf8Nim("abc", "skip") == "abc"
    check sanitizeUtf8Nim("abc", "replace") == "abc"
    check sanitizeUtf8Nim("ab\xffc", "skip") == "abc"
    check sanitizeUtf8Nim("\xffabc", "skip") == "abc"
    check sanitizeUtf8Nim("abc\xff", "skip") == "abc"
    check sanitizeUtf8Nim("\xff", "skip") == ""
    check sanitizeUtf8Nim("\xff\xff\xff", "skip") == ""
    check sanitizeUtf8Nim("a\xff\xffb", "skip") == "ab"
    check sanitizeUtf8Nim("", "skip") == ""
    check sanitizeUtf8Nim("", "replace") == ""

  test "generate utf8tests.bin":
    if not fileExists(binTestCases) or fileNewer(testCases, binTestCases):
      echo "generating file: " & binTestCases
      let msg = createUtf8testsBinFile(binTestCases)
      check msg == ""
      echo "run the tests again"
      fail()

  test "generate reference artifacts":
    let rc = generateArtifacts("ref", writeValidUtf8Ref)
    check rc == 0

  test "generate nim artifacts":
    let rc = generateArtifacts("nim.1.4.8", writeValidUtf8FileNim)
    check rc == 0

  test "generate python3 artifacts":
    let rc = generateArtifacts("python.3.7.5", writeValidUtf8FilePython3)
    check rc == 0
