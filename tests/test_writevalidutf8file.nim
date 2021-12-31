import std/os
import std/unittest
import writevalidutf8file
import checks

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

  test "generate artifacts":
    let skipFilename = "artifacts/utf8.skip.ref.txt"
    if not fileExists(skipFilename) or fileNewer(binTestCases, skipFilename):
        echo "generating file: " & skipFilename
        let rc = writeValidUtf8Ref(binTestCases, skipFilename, "skip")
        check rc == 0

    let replaceFilename = "artifacts/utf8.replace.ref.txt"
    if not fileExists(replaceFilename) or fileNewer(binTestCases, replaceFilename):
        echo "generating file: " & replaceFilename
        let rc = writeValidUtf8Ref(binTestCases, replaceFilename, "skip")
        check rc == 0
