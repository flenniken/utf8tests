import std/unittest
import std/os
import std/strformat
import opresult
import checks

proc compareTestLineEcho*(testLine: TestLine, eTestLine: TestLine): bool =
  ## Compare to TestLine objects and show the differences. Return true
  ## when equal.
  result = true
  if testLine.numStr != eTestLine.numStr:
    echo "numStr expected: " & eTestLine.numStr
    echo "            got: " & testLine.numStr
    result = false

  if testLine.testCase != eTestLine.testCase:
    echo "testCase expected: " & eTestLine.testCase
    echo "              got: " & testLine.testCase
    result = false

  if testLine.eSkip != eTestLine.eSkip:
    echo "eSkip expected: " & eTestLine.eSkip
    echo "           got: " & testLine.eSkip
    result = false

  if testLine.eReplace != eTestLine.eReplace:
    echo "eReplace expected: " & eTestLine.eReplace
    echo "              got: " & testLine.eReplace
    result = false

proc testHexToString(hexString: string, eStr: string): bool =
  ## Test hexToString, pass a hex string and the expected resulting
  ## string.
  let strOr = hexToString(hexString)
  result = true
  if strOr.isMessage:
    echo "hexToString failed with message: " & strOr.message
    return false
  let str = strOr.value
  if str != eStr:
    echo "expected: " & eStr
    echo "     got: " & str
    result = false

proc testHexToStringError(hexString: string, eMsg: string): bool =
  ## Test hexToString error case, pass a hex string and the expected
  ## error message.
  let strOr = hexToString(hexString)
  result = true
  if strOr.isValue:
    echo "hexToString did not fail as expected, got: " & strOr.value
    return false
  if strOr.message != eMsg:
    echo "expected: " & eMsg
    echo "     got: " & strOr.message
    result = false

proc testLineParser(parser: proc(line: string): OpResult[TestLine, string],
    line: string, eTestLine: TestLine): bool =
  let testLineOr = parser(line)
  if testLineOr.isMessage:
    echo fmt"The parser returned the error message: {testLineOr.message}"
    return false
  let testLine = testLineOr.value
  result = compareTestLineEcho(testLine, eTestLine)

proc testParseInvalidHexLine(line: string, eTestLine: TestLine): bool =
  ## Test the parseInvalidHexLine for correctly formed lines.
  result = testLineParser(parseInvalidHexLine, line, eTestLine)

proc testParseValidLine(line: string, eTestLine: TestLine): bool =
  ## Test the parseValidLine for correctly formed lines.
  result = testLineParser(parseValidLine, line, eTestLine)

proc testParseInvalidLine(line: string, eTestLine: TestLine): bool =
  ## Test the parseInvalidLine for correctly formed lines.
  result = testLineParser(parseInvalidLine, line, eTestLine)

proc testParseValidHexLine(line: string, eTestLine: TestLine): bool =
  ## Test the parseValidHexLine for correctly formed lines.
  result = testLineParser(parseValidHexLine, line, eTestLine)

proc testParseTestLine(line: string, eTestLine: TestLine): bool =
  ## Test the parseTestLine for correctly formed lines.
  result = testLineParser(parseTestLine, line, eTestLine)

proc testParseTestLineError(line: string): bool =
  ## Test the parseTestLine for incorrectly formed lines.
  result = true
  let testLineOr = parseTestLine(line)
  if testLineOr.isValue:
    echo "The parseTestLine procedure unexpectedly passed for:"
    echo $testLineOr.value
    result = false

suite "checks.nim":

  test "stringToHex":
    check stringToHex("\x0a") == "0a"
    check stringToHex("123") == "31 32 33"
    check stringToHex("\x01\x14") == "01 14"
    check stringToHex("") == ""

  test "hexToString":
    check testHexToString("33 34 35", "345")
    check testHexToString("33 34 35", "345")
    check testHexToString(" 33  34  35 ", "345")
    check testHexToString("01 14", "\x01\x14")
    check testHexToString("ab", "\xab")
    check testHexToString("cf", "\xcf")
    check testHexToString("FF", "\xff")
    check testHexToString("112233445566778899aabbccddeeff",
      "\x11\x22\x33\x44\x55\x66\x77\x88\x99\xaa\xbb\xcc\xdd\xee\xff")
    check testHexToString("0123456789abcdef",
      "\x01\x23\x45\x67\x89\xab\xcd\xef")

  test "hexToString error":
    let oddMsg = "Hex values come in pairs but we got an odd number of digits."
    check testHexToStringError("3", oddMsg)
    check testHexToStringError("123", oddMsg)
    check testHexToStringError("ag", "Invalid hex digit: 'g'.")
    check testHexToStringError("03 0r", "Invalid hex digit: 'r'.")

  test "parseValidLine":
    check testParseValidLine("1:valid:abc", newTestLine(true, "1", "abc"))
    check testParseValidLine("1.2.0:valid:κόσμε", newTestLine(true, "1.2.0", "κόσμε"))
    check testParseValidLine("2.0.0:valid:©", newTestLine(true, "2.0.0", "©"))
    check testParseValidLine("1.0.0:valid:1", newTestLine(true, "1.0.0", "1"))

  test "parseValidHexLine":
    check testParseValidHexLine("2.1.0: valid hex: C2 A9", newTestLine(true, "2.1.0", "©"))
    check testParseValidHexLine("3.0: valid hex: E2 80 90", newTestLine(true, "3.0",
      "\xe2\x80\x90"))
    check testParseValidHexLine("22.7: valid hex: e0 a0 80",
      newTestLine(true, "22.7", "\xe0\xa0\x80"))

  test "parseInvalidHexLine":
    var line = "6.0: invalid hex : F7 BF BF BF : nothing: EF BF BD  EF BF BD  EF BF BD  EF BF BD"
    check testParseInvalidHexLine(line,
      newTestLine(false, "6.0", "\xF7\xBF\xBF\xBF", "",
                  "\xEF\xBF\xBD\xEF\xBF\xBD\xEF\xBF\xBD\xEF\xBF\xBD"))

    check testParseInvalidHexLine("3: invalid hex: ff: nothing: EFBFBD",
      newTestLine(false, "3", "\xff", "", "\xEF\xBF\xBD"))

    check testParseInvalidHexLine("3: invalid hex: ff: nothing: EFBFBD ",
      newTestLine(false, "3", "\xff", "", "\xEF\xBF\xBD"))

    check testParseInvalidHexLine("3: invalid hex: ff: nothing: EFBFBD EFBFBD",
      newTestLine(false, "3", "\xff", "", "\xEF\xBF\xBD\xEF\xBF\xBD"))

    check testParseInvalidHexLine("3: invalid hex: ff: nothing: EFBFBD EFBFBD ",
      newTestLine(false, "3", "\xff", "", "\xEF\xBF\xBD\xEF\xBF\xBD"))

    check testParseInvalidHexLine("4: invalid hex : ff : 33: 31 32 ",
      newTestLine(false, "4", "\xff", "3", "12"))

    check testParseInvalidHexLine("11.2: invalid hex: 80 bf : nothing : EFBFBD EFBFBD",
      newTestLine(false, "11.2", "\x80\xbf", "", "\xEF\xBF\xBD\xEF\xBF\xBD"))

    line = "6.1: invalid hex: f8 88 80 80 80: nothing: EF BF BD  EF BF BD  EF BF BD  EF BF BD  EF BF BD"
    check testParseInvalidHexLine(line,
      newTestLine(false, "6.1", "\xf8\x88\x80\x80\x80", "",
        "\xEF\xBF\xBD\xEF\xBF\xBD\xEF\xBF\xBD\xEF\xBF\xBD\xEF\xBF\xBD"))

  test "parseInvalidLine":
    check testParseInvalidLine("1:invalid:abc", newTestLine(false, "1", "abc"))
    check testParseInvalidLine("1.2:invalid:abc", newTestLine(false, "1.2", "abc"))
    check testParseInvalidLine("1.2:invalid:", newTestLine(false, "1.2", ""))

  test "parseTestLine":
    check testParseTestLine("1:valid:abc", newTestLine(true, "1", "abc"))
    check testParseTestLine("2: valid hex: 39", newTestLine(true, "2", "9"))
    check testParseTestLine("3: invalid hex: ff: nothing: EFBFBD ",
      newTestLine(false, "3", "\xff", "", "\xEF\xBF\xBD"))

  test "parseTestLine error":
    check testParseTestLineError("b:valid:abc")
    check testParseTestLineError("1: asdf: abc")
    check testParseTestLineError("1: valid :1")
    check testParseTestLineError("1: valid d: a")
    check testParseTestLineError("1: invalid hex: 31: 32: 3")
    check testParseTestLineError("1: invalid hex: 31: 3: 33")
    check testParseTestLineError("1: invalid hex: 3: 32: 33")
    check testParseTestLineError("1: invalid : 31: 32: 33")
    check testParseTestLineError("1: inalid : 31: 32: 33")
    check testParseTestLineError("abc: invalid : 31: 32: 33")

  test "readTestCasesFile testCases":
    let tableOr = readTestCasesFile(testCases)
    if tableOr.isMessage:
      echo "Unable to read the file."
      echo tableOr.message
    check tableOr.isValue()

  test "createUtf8testsBinFile":
    let filename = "temp.bin"
    discard tryRemoveFile(filename)
    let msg = createUtf8testsBinFile(filename)
    check msg == ""
    check fileExists(filename)
    discard tryRemoveFile(filename)

  test "read tests":
    let tableOr = readTestCasesFile(testCases)
    check tableOr.isValue

    let filename = "temp2.bin"
    let msg = createUtf8testsBinFile(filename)
    check msg == ""

    let table2Or = readTestCasesFile(filename)
    check table2Or.isValue

    discard tryRemoveFile(filename)

  test "check utf8tests.txt is ascii":

    var found = false
    var lineNum = 1
    for line in lines(testCases):
      for ch in line:
        if ord(ch) < 20:
          echo fmt"{lineNum} has a control character in it."
          found = true
        elif ord(ch) > 127:
          echo fmt"{lineNum} has a character > 127."
          found = true
      inc(lineNum)

    check found == false

  test "reference check skip":
    let gotFilename = "artifacts/utf8.skip.ref.txt"
    let rc = checkFile(binTestCases, gotFilename, "skip")
    check rc == 0

  test "reference check replace":
    let gotFilename = "artifacts/utf8.replace.ref.txt"
    let rc = checkFile(binTestCases, gotFilename, "replace")
    check rc == 0
