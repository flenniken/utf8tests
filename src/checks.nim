## Check a file created from utf8tests.bin against the expected result
## defined in utf8tests.txt.

import std/options
import std/strutils
import std/os
import std/strformat
import std/tables
import regexes
import opresult

const
  testCases* = "utf8tests.txt"
  binTestCases* = "utf8tests.bin"

type
  WriteValidUtf8File* = proc (inFilename, outFilename: string,
    skipOrReplace = "replace"): int
    ## Procedure prototype for sanitizing a UTF-8 file.

  TestLine* = object
    ## TestLine holds the information from a utf8test.txt test line.
    valid*: bool  # valid line type or invalid line type.
    numStr*: string  # test number string
    testCase*: string # test byte sequence
    eSkip*: string # expected byte sequence when skipping invalid bytes
    eReplace*: string # expected byte sequence when replacing invalid
                     # bytes with the replacement character.

func newTestLine*(valid: bool, numStr, testCase: string,
    eSkip="", eReplace=""): TestLine =
  ## Create a new TestLine object.
  result = TestLine(valid: valid, numStr: numStr, testCase: testCase,
                    eSkip: eSkip, eReplace: eReplace)

func stringToHex*(str: string): string =
  ## Convert the string bytes to hex bytes like 34 a9 ff e2.
  var digits: seq[string]
  for ch in str:
    let abyte = uint8(ord(ch))
    digits.add(fmt"{abyte:02x}")
  result = digits.join(" ")

func hexToString*(hexString: string): OpResult[string, string] =
  ## Convert the hex string to a string.
  ##
  ## Examples:
  ##
  ## "33 34 35" -> "345"
  ## "333435" -> "345"
  ## " 33 3435" -> "345"

  var str: string
  var digit = 0u8
  var firstNimble = 0u8
  var count = 0
  for ch in hexString:
    case ch
    of ' ':
      continue
    of '0' .. '9':
      digit = uint8(ord(ch) - ord('0'))
    of 'a' .. 'f':
      digit = uint8(ord(ch) - ord('a') + 10)
    of 'A' .. 'F':
      digit = uint8(ord(ch) - ord('A') + 10)
    else:
      return newOpResultMsg[string, string](fmt"Invalid hex digit: '{ch}'.")
    if count == 0:
      firstNimble = digit
      inc(count)
    else:
      let newNum = firstNimble shl 4 or digit
      str.add(char(newNum))
      count = 0
  if count != 0:
    let msg = "Hex values come in pairs but we got an odd number of digits."
    return newOpResultMsg[string, string](msg)

  result = newOpResult[string, string](str)

func parseInvalidHexLine*(line: string): OpResult[TestLine, string] =
  ## Parse invalid hex type test line.
  ##
  ## Examples:
  ##
  ## 22.3:invalid hex:e0 80 af:nothing:EFBFBD EFBFBD EFBFBD

  # Validate and extract the information from the line.
  let pattern = r"([0-9.]+)\s*:\s*invalid hex\s*:\s*([0-9a-f A-F]+)\s*:\s*([^:]+)\s*:\s*(.+)$"
  let matchesO = matchPattern(line, pattern)
  if not matchesO.isSome:
    return newOpResultMsg[TestLine, string]("Not a valid 'invalid hex' type line.")
  let groups = getGroups(matchesO.get, 4)
  let numStr = groups[0]
  let testCaseHex = groups[1]
  let eSkipHex = strutils.strip(groups[2])
  let eReplaceHex = strutils.strip(groups[3])

  # Convert the test case hex string to a string.
  let testCaseOr = hexToString(testCaseHex)
  if testCaseOr.isMessage:
    return newOpResultMsg[TestLine, string](testCaseOr.message)
  let testCase = testCaseOr.value

  # Convert the expected skip hex string to a string.
  var eSkip: string
  if eSkipHex == "nothing":
    eSkip = ""
  else:
    let eSkipOr = hexToString(eSkipHex)
    if eSkipOr.isMessage:
      return newOpResultMsg[TestLine, string](eSkipOr.message)
    eSkip = eSkipOr.value

  # Convert the expected replace hex string to a string.
  let eReplaceOr = hexToString(eReplaceHex)
  if eReplaceOr.isMessage:
    return newOpResultMsg[TestLine, string](eReplaceOr.message)
  let eReplace = eReplaceOr.value

  return newOpResult[TestLine, string](
    newTestLine(false, numStr, testCase, eSkip, eReplace))

func parseValidHexLine*(line: string): OpResult[TestLine, string] =
  ## Parse valid hex type test line.

  # Example:
  # 10.3:valid hex:F4 8F BF BF

  let pattern = r"([0-9.]+)\s*:\s*valid hex\s*:\s*(.+)$"
  let matchesO = matchPattern(line, pattern)
  if not matchesO.isSome:
    return newOpResultMsg[TestLine, string]("Invalid 'valid hex' line format.")
  let groups = matchesO.get().getGroups(2)
  let numStr = groups[0]
  let hexString = groups[1]
  let testCaseOr = hexToString(hexString)
  if testCaseOr.isMessage:
    return newOpResultMsg[TestLine, string](testCaseOr.message)
  return newOpResult[TestLine, string](newTestLine(true, numStr, testCaseOr.value, "", ""))

func parseInvalidLine*(line: string): OpResult[TestLine, string] =
  ## Parse invalid hex type test line.

  # Example:
  # 10.3:invalid:\xff\xfe

  let pattern = r"([0-9.]+):invalid:(.*)$"
  let matchesO = matchPattern(line, pattern)
  if not matchesO.isSome:
    return newOpResultMsg[TestLine, string]("Invalid 'invalid' line format.")
  let groups = matchesO.get().getGroups(2)
  let numStr = groups[0]
  let testCase = groups[1]
  return newOpResult[TestLine, string](newTestLine(true, numStr, testCase, "", ""))

func parseValidLine*(line: string): OpResult[TestLine, string] =
  ## Parse valid type test line.

  # Example:
  # 10.3:valid:abc

  let pattern = r"([0-9.]+):valid:(.+)$"
  let matchesO = matchPattern(line, pattern)
  if not matchesO.isSome:
    return newOpResultMsg[TestLine, string]("Invalid 'valid' line format.")
  let groups = matchesO.get().getGroups(2)
  let numStr = groups[0]
  let testCase = groups[1]
  return newOpResult[TestLine, string](newTestLine(true, numStr, testCase, "", ""))

func parseTestLine*(line: string): OpResult[TestLine, string] =
  ## Parse a test line and return a TestLine object.

  result = parseInvalidLine(line)
  if result.isValue:
    return result
  result = parseInvalidHexLine(line)
  if result.isValue:
    return result
  result = parseValidLine(line)
  if result.isValue:
    return result
  result = parseValidHexLine(line)
  if result.isValue:
    return result
  let msg = fmt"Invalid line format: '{line}'."
  return newOpResultMsg[TestLine, string](msg)

func newOpResultTestLines(table: OrderedTable[string, TestLine]):
    OpResult[OrderedTable[string, TestLine], string] {.inline.} =
  result = newOpResult[OrderedTable[string, TestLine], string](table)

func newOpResultMessage(message: string):
    OpResult[OrderedTable[string, TestLine], string] {.inline.} =
  result = newOpResultMsg[OrderedTable[string, TestLine], string](message)

proc readTestCasesFile*(filename: string, readIgnore = false):
    OpResult[OrderedTable[string, TestLine], string] =
  ## Read the test cases file. Return an ordered dictionary where
  ## the key is the test number string and the value is a TestLine
  ## object. When there is an error, return the error message.
  ## Set readIgnore true to ignore bad lines.

  if not fileExists(filename):
    return newOpResultMessage("The file does not exist: " & filename)

  # Open the file for reading.
  var file: File
  if not open(file, filename, fmRead):
    return newOpResultMessage("Unable to open the file: " & filename)
  defer:
    file.close()

  # Read and process the file line by line.
  var dict: OrderedTable[string, TestLine]
  var lineNum = 0
  for line in lines(file):
    inc(lineNum)

    # Skip comment and blank lines.
    if line.len == 0 or line[0] == '#':
      continue

    # Parse a test line.
    let testLineOr = parseTestLine(line)
    if testLineOr.isMessage:
      if readIgnore:
        continue
      return newOpResultMessage("Line $1: $2" % [$lineNum, testLineOr.message])
    let testLine = testLineOr.value

    # Add the test line to the dictionary.
    if testLine.numStr in dict:
      return newOpResultMessage("Line $1: $2" % [$lineNum, "Duplicate test number."])

    dict[testLine.numStr] = testLine

  result = newOpResultTestLines(dict)

proc createUtf8testsBinFile*(resultFilename: string): string =
  ## Create a bin file from the utf8tests.txt file. The bin
  ## file has two types of lines, valid lines and invalid lines.  If
  ## there is an error, return a message telling what went wrong.
  ##
  ## Lines:
  ## numStr:valid:testCase
  ## numStr:invalid:testCase

  # Read the test cases file into an ordered dictionary.
  let tableOr = readTestCasesFile(testCases)
  if tableOr.isMessage:
    return tableOr.message
  let table = tableOr.value

  var resultFile: File
  if not open(resultFile, resultFilename, fmWrite):
    return "Unable to open the file: " & resultFilename
  defer:
    resultFile.close()

  for testLine in table.values:
    var lineType: string
    if testLine.valid:
      lineType = "valid"
    else:
      lineType = "invalid"
    resultFile.write(fmt"{testLine.numStr}:{lineType}:{testLine.testCase}"&"\n")

proc compareTablesEcho(eTable: OrderedTable[string, TestLine],
    gotTable: OrderedTable[string, TestLine],
    skipOrReplace="replace"): int =
  ## Compare two tables and show the differences. Return 0 when they
  ## are the same.

  if eTable.len != gotTable.len:
    echo "The two tables have different number of elements."
    echo "expected: " & $eTable.len
    echo "     got: " & $gotTable.len
    result = 1

  for eNumStr, eTestLine in pairs(eTable):
    if not gotTable.hasKey(eNumStr):
      echo fmt"Test number '{eNumStr}' does not exist in the generated table."
      result = 1
      continue
    let gotTestLine = gotTable[eNumStr]

    var expectedStr: string

    if eTestLine.valid:
      expectedStr = eTestLine.testCase
    elif skipOrReplace == "skip":
      expectedStr = eTestLine.eSkip
    else:
      expectedStr = eTestLine.eReplace

    if expectedStr != gotTestLine.testCase:
      var expected: string
      if expectedStr == "":
        expected = "nothing"
      else:
        expected = stringToHex(expectedStr)

      echo "$1: test case: $2" % [eTestLine.numStr, stringToHex(eTestLine.testCase)]
      echo "$1:  expected: $2" % [eTestLine.numStr, expected]
      echo "$1:       got: $2" % [eTestLine.numStr, stringToHex(gotTestLine.testCase)]
      echo ""
      result = 1

proc checkFile*(expectedFilename: string, gotFilename: string,
    skipOrReplace = "replace", readIgnore = false): int =
  ## Check the file for differences with the expected output. Echo
  ## differences to the screen. Return 0 when the output matches the
  ## expected output. When readIgnore is true, ignore malformed lines
  ## when reading the got file.

  # Read the got file into a dictionary.
  let gotTableOr = readTestCasesFile(gotFilename, readIgnore)
  if gotTableOr.isMessage:
    echo gotTableOr.message
    return 1
  let gotTable = gotTableOr.value

  # Read the test case file into a dictionary.
  let eTableOr = readTestCasesFile(testCases)
  if eTableOr.isMessage:
    echo eTableOr.message
    return 1
  let eTable = eTableOr.value

  # Compare the got table with the expected table.
  let rc = compareTablesEcho(eTable, gotTable, skipOrReplace)
  if rc != 0:
    result = 1
