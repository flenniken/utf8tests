import std/options
import std/strutils
import std/os
import std/strformat
import std/unicode
import std/tables
import std/osproc
import unicodes
import regexes
import opresult

const
  testCases* = "testfiles/utf8tests.txt"
  binTestCases* = "testfiles/utf8tests.bin"

  # The replacement character U+FFFD has UTF-8 byte sequence ef bf bd.
  replacementSeq* = "\xEF\xBF\xBD"

  # The tests turned off do not pass.
  testIconv = false
  testNim = true
  testPython3skip = true
  testPython3replace = false
  testNodeJs = false

  validStr = "valid:"
  validHexStr = "valid hex:"
  invalidStr = "invalid at "
  invalidHexStr = "invalid hex at "

type
  TestLine* = object
    ## TestLine holds the information from a test line.
    valid*: bool  # valid type of line or invalid type.
    numStr*: string  # test number
    testCase*: string # test byte sequence
    eSkip*: string # expected byte sequence when skipping invalid bytes
    eReplace*: string # expected byte sequence when replacing invalid
                     # bytes with the replacement character.

func newTestLine*(valid: bool, numStr, testCase: string, eSkip="", eReplace=""): TestLine =
  ## Create a new TestLine object.
  result = TestLine(valid: valid, numStr: numStr, testCase: testCase,
                    eSkip: eSkip, eReplace: eReplace)

func stringToHex*(str: string): string =
  ## Convert the str bytes to hex bytes like 34 a9 ff e2.
  var digits: seq[string]
  for ch in str:
    let abyte = uint8(ord(ch))
    digits.add(fmt"{abyte:02x}")
  result = digits.join(" ")

func hexToString*(hexString: string): OpResult[string, string] =
  ## Convert the hexString to a string.
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
  ## Parse invalid hex test line.
  ## 22.3: invalid hex: e0 80 af: nothing : rep3
  ## 13.0: invalid hex: c02031 : 20 31: rep 20 31

  let pattern = r"([0-9.]+)\s*:\s*invalid hex\s*:\s*([0-9a-f A-F]+)\s*:\s*([^:]+)\s*:\s*(.+)$"
  let matchesO = matchPattern(line, pattern)
  if not matchesO.isSome:
    return newOpResultMsg[TestLine, string]("Not a valid 'invalid hex' line.")
  let groups = getGroups(matchesO.get, 4)
  let numStr = groups[0]
  let testCaseHex = groups[1]
  let eSkipHex = strutils.strip(groups[2])
  let eReplaceHex = strutils.strip(groups[3])

  let testCaseOr = hexToString(testCaseHex)
  if testCaseOr.isMessage:
    return newOpResultMsg[TestLine, string](testCaseOr.message)
  let testCase = testCaseOr.value

  var eSkip: string
  if eSkipHex == "nothing":
    eSkip = ""
  else:
    let eSkipOr = hexToString(eSkipHex)
    if eSkipOr.isMessage:
      return newOpResultMsg[TestLine, string](eSkipOr.message)
    eSkip = eSkipOr.value

  var eReplace: string
  if eReplaceHex.startsWith("rep"):
    var repeatNum: int
    if eReplaceHex.len == 3:
      repeatNum = 1
    else:
      try:
        repeatNum = int(parseBiggestInt(eReplaceHex[3 .. ^1]))
      except:
        return newOpResultMsg[TestLine, string](fmt"Invalid rep number: '{eReplaceHex}'")
    eReplace = ""
    for _ in countUp(1, repeatNum):
      eReplace.add(replacementSeq)
  else:
    let eReplaceOr = hexToString(eReplaceHex)
    if eReplaceOr.isMessage:
      return newOpResultMsg[TestLine, string](eReplaceOr.message)
    eReplace = eReplaceOr.value

  return newOpResult[TestLine, string](newTestLine(false, numStr, testCase, eSkip, eReplace))

func parseValidHexLine*(line: string): OpResult[TestLine, string] =
  ## Parse valid hex type test line.

  # example: 10.3: valid hex: F4 8F BF BF

  let pattern = r"([0-9.]+)\s*:\s*valid hex\s*:\s*(.+)$"
  let matchesO = matchPattern(line, pattern)
  if not matchesO.isSome:
    return newOpResultMsg[TestLine, string]("Invalid 'valid hex' line format.")
  let (numStr, hexString) = matchesO.get().get2Groups()
  let testCaseOr = hexToString(hexString)
  if testCaseOr.isMessage:
    return newOpResultMsg[TestLine, string](testCaseOr.message)
  return newOpResult[TestLine, string](newTestLine(true, numStr, testCaseOr.value, "", ""))

func parseInvalidLine*(line: string): OpResult[TestLine, string] =
  ## Parse invalid hex type test line.

  # example: 10.3:invalid:\xff\xfe
  # example: 10.3:invalid:

  let pattern = r"([0-9.]+):invalid:(.*)$"
  let matchesO = matchPattern(line, pattern)
  if not matchesO.isSome:
    return newOpResultMsg[TestLine, string]("Invalid 'invalid' line format.")
  let (numStr, testCase) = matchesO.get().get2Groups()
  return newOpResult[TestLine, string](newTestLine(true, numStr, testCase, "", ""))

func parseValidLine*(line: string): OpResult[TestLine, string] =
  ## Parse valid type test line.
  # example: 10.3:valid:abc

  let pattern = r"([0-9.]+):valid:(.+)$"
  let matchesO = matchPattern(line, pattern)
  if not matchesO.isSome:
    return newOpResultMsg[TestLine, string]("Invalid 'valid' line format.")
  let (numStr, testCase) = matchesO.get().get2Groups()
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

proc readTestCasesFile*(filename: string):
    OpResult[OrderedTable[string, TestLine], string] =
  ## Read the test cases file. Return an ordered dictionary where
  ## the key is the test number string and the value is a TestLine
  ## object. When there is an error, return the error message.

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


# proc testValidateUtf8String(callback: proc(str: string): int ): bool =
#   ## Validate the validateUtf8String method by processing all the the
#   ## test cases in utf8tests.txt one by one.  The callback procedure
#   ## is called for each test case. The callback returns -1 when the
#   ## string is valid, else it is the position of the first invalid
#   ## byte.

#   if not fileExists(binTestCases):
#     echo "Missing test file: " & binTestCases
#     return false

#   # The utf8test.bin is created from the utftest.txt file by
#   # rewriteUtf8TestFile.
#   let filename = binTestCases
#   if not fileExists(filename):
#     echo "The file does not exist: " & filename
#     return false

#   var file: File
#   if not open(file, filename, fmRead):
#     echo "Unable to open the file: $1" % [filename]
#     return false
#   defer:
#     file.close()

#   var beValid: bool
#   var lineNum = 0
#   result = true

#   var hexLineO: Option[TestLine]
#   for line in lines(file):
#     inc(lineNum)
#     if line.len == 0:
#       continue
#     elif line.startswith("#"):
#       continue
#     elif line.startswith(validStr):
#       beValid = true
#       hexLineO = parseValidLine(line)
#       if not hexLineO.isSome:
#         echo "Line $1: $2" % [$lineNum, "incorrect line format."]
#         result = false
#     elif line.startswith(invalidStr):
#       beValid = false
#       hexLineO = parseInvalidLine(line)
#       if not hexLineO.isSome:
#         echo "Line $1: $2" % [$lineNum, "incorrect line format."]
#         result = false
#     else:
#       echo "Line $1: not one of the expected lines types." % $lineNum
#       result = false

#     let hexLine = hexLineO.get()

#     let pos = callback(hexLine.str)

#     if beValid:
#       if pos != -1:
#         echo "Line $1 is invalid but expected to be valid. $2" % [$lineNum, hexLine.comment]
#         result = false
#     else:
#       if pos == -1:
#         echo fmt"Line {lineNum}: Invalid string passed validation. {hexline.comment}"
#         result = false
#       elif pos != hexLine.pos:
#         echo "Line $1: expected invalid pos: $2 $3" % [$lineNum, $hexLine.pos, $hexLine.comment]
#         echo "Line $1:      got invalid pos: $2" % [$lineNum, $pos]
#         result = false


proc writeValidUtf8FileTea*(inFilename: string, outFilename: string,
    skipOrReplace = "replace"): int =
  ## Read the binary file input file, which contains invalid UTF-8
  ## bytes, then write valid UTF-8 bytes to the output file either
  ## skipping the invalid bytes or replacing them with U-FFFD.
  ##
  ## When there is an error, display the error message to standard out
  ## and return 1, else return 0.  The input file must be under 50k.

  if not fileExists(inFilename):
    echo "The input file is missing."
    return 1
  if getFileSize(inFilename) > 50 * 1024:
    echo "The input file must be under 50k."
    return 1

  # Read the file into memory.
  var inData: string
  try:
    inData = readFile(inFilename)
  except:
    echo "Unable to open and read the input file."
    return 1

  # Process the input data assuming it is UTF-8 encoded but it contains
  # some invalid bytes. Return valid UTF-8 encoded bytes.
  let outData = sanitizeUtf8(inData, skipOrReplace)

  # Write the valid UTF-8 data to the output file.
  try:
    writeFile(outFilename, outData)
  except:
    echo "Unable to open and write the output file."
    return 1

  result = 0 # success


proc sanitizeUtf8Nim*(str: string, skipOrReplace = "replace"): string =
  ## Sanitize and return the UTF-8 string. The skipOrReplace parameter
  ## determines whether to skip or replace invalid bytes.  When
  ## replacing the U-FFFD character is used.

  # Reserve space for the result string the same size as the input string.
  result = newStringOfCap(str.len)

  let skipInvalid = if skipOrReplace == "skip": true else: false

  var ix = 0
  while true:
    if ix >= str.len:
      break
    var pos = validateUtf8(str[ix .. str.len - 1])
    if pos == -1:
      result.add(str[ix .. str.len - 1])
      break
    assert pos >= 0
    var endPos = ix + pos
    if endPos > 0:
      result.add(str[ix .. endPos - 1])
    if not skipInvalid:
      result.add("\ufffd")
    ix = endPos + 1

func formatGotLine(gotLine: string): string =
  ## Show the gotLine comment part followed by hex.
  ##invalid at 0: 6.0, too big U-001FFFFF, F7 BF BF BF: ????
  ##6.0, too big U-001FFFFF, (F7 BF BF BF): xx xx xx xx

  # Find the two colons.
  let firstColon = gotLine.find(':')
  assert firstColon >= 0
  let start = firstColon + 2
  assert start < gotLine.len
  let secondColon = gotLine[start .. ^1].find(':') + start
  assert secondColon >= start

  let comment = gotLine[start .. secondColon - 1]
  let bytesStart = secondColon + 2
  assert bytesStart <= gotLine.len
  let hexString = stringToHex(gotLine[bytesStart .. ^1])

  result = fmt"{comment}: {hexString}"

proc compareUtf8TestFiles(expectedFilename: string, gotFilename: string): bool =
  ## Return true when the two files are the same. When different, show
  ## the line differences.

  let expectedData = readFile(expectedFilename)
  let gotData = readFile(gotFilename)

  if expectedData.len != gotData.len:
    result = false
  else:
    result = true

  let expectedLines = splitLines(expectedData)
  let gotLines = splitLines(gotData)

  # Compare the file generated with the expected output line by line.
  var ix = 0
  while true:
    if ix >= expectedLines.len and ix >= gotLines.len:
      break

    var expectedLine: string
    if ix < expectedLines.len:
      expectedLine = expectedLines[ix]
    else:
      expectedLine = ""

    var gotLine: string
    if ix < gotLines.len:
      gotLine = gotLines[ix]
    else:
      gotLine = ""

    if expectedLine != gotLine:
      # echo "expected: " & expectedLine
      # echo "     got: " & gotLine
      echo formatGotLine(gotLine)

      result = false

    inc(ix)



# todo: test Utf8CharString

# proc testUtf8CharString(text: string, start: Natural, eStr: string, ePos: Natural): bool =
#   var pos = start
#   let gotStr = utf8CharString(text, pos)
#   result = true
#   if gotStr != eStr:
#     echo "expected: " & eStr
#     echo "     got: " & gotStr
#     result = false
#   if pos != ePos:
#     echo "expected pos: " & $ePos
#     echo "     got pos: " & $pos
#     result = false

#   if result == false:
#     let rune = runeAt(text, start)
#     echo "rune = " & $rune
#     echo "rune hex = " & toHex(int32(rune))
#     echo "utf-8 hex = " & toHex(toUtf8(rune))

# proc testUtf8CharStringError(text: string, start: Natural, ePos: Natural): bool =
#   var pos = start
#   let gotStr = utf8CharString(text, pos)
#   result = true
#   if gotStr != "":
#     result = false
#   if pos != ePos:
#     result = false
#   if result == false:
#     echo "expected empty string"
#     echo ""
#     echo "input text: " & text
#     echo "input text as hex: " & toHex(text)
#     echo "start pos: " & $start
#     echo ""
#     echo "expected pos: " & $ePos
#     echo "     got pos: " & $pos
#     echo ""
#     echo "len: $1, got: '$2'" % [$gotStr.len, gotStr]
#     echo "got as hex: " & toHex(gotStr)

#     # validate the input text.
#     var invalidPos = validateUtf8(text)
#     if invalidPos != -1:
#       echo "validateUtf8 reports the text is valid."
#     else:
#       echo "validateUtf8 reports invalid pos: " & $invalidPos

#     # Run iconv on the character.
#     let filename = "tempfile.txt"
#     var file = open(filename, fmWrite)
#     file.write(text[start .. text.len-1])
#     file.close()
#     let rc = execCmd("iconv -f UTF-8 -t UTF-8 $1" % filename)
#     echo "iconv returns: " & $rc
#     discard tryRemoveFile(filename)


proc testSanitizeutf8Empty(str: string): bool =
  ## Test that the string does not have any valid UTF-8 bytes.

  result = true
  let empty = sanitizeUtf8(str, "skip")
  if empty != "":
    echo "expected nothing, got: " & empty
    result = false

  let rchars = sanitizeUtf8(str, "replace")
  if rchars.len != str.len * 3 or rchars.len mod 3 != 0:
    echo "expected all replace characters, got: " & rchars
    result = false
  else:
    # check at all the bytes are U-FFFD (EF BF BD)
    for ix in countUp(0, rchars.len-3, 3):
      if rchars[ix] != '\xEF' or rchars[ix+1] != '\xBF' or
         rchars[ix+2] != '\xBD':
        echo "expected all replace characters, got: " & rchars
        result = false
        break

proc testSanitizeutf8(str: string, expected: string, skipOrReplace = "replace"): bool =
  ## Test that sanitizeUtf8 returns the expected string when skipping.

  result = true
  let sanitized = sanitizeUtf8(str, skipOrReplace)
  if sanitized != expected:
    echo "     got: " & sanitized
    echo "expected: " & expected
    result = false



proc fileExistsAnd50kEcho(filename: string): int =
  ## Return 0 when the file exists and it is less than 50K. Otherwise
  ## echo the problem and return 1.

  if not fileExists(filename):
    echo "The input file is missing."
    return 1
  if getFileSize(filename) > 50 * 1024:
    echo "The input file must be under 50k."
    return 1
  result = 0

when testNim:
  proc writeValidUtf8FileNim(inFilename: string, outFilename: string,
                             skipOrReplace = "replace"): int =
    ## Read the binary file input file, which contains invalid UTF-8
    ## bytes, then write valid UTF-8 bytes to the output file.  Either
    ## skip invalid bytes or replace them with U-FFFD.
    ##
    ## When there is an error, display the error message to standard out
    ## and return 1, else return 0.  The input file must be under 50k.

    if fileExistsAnd50kEcho(inFilename) != 0:
      return 1

    # Read the file into memory.
    var inData: string
    try:
      inData = readFile(inFilename)
    except:
      echo "Unable to open and read the input file."
      return 1

    # Process the input data assuming it is UTF-8 encoded but it contains
    # some invalid bytes. Return valid UTF-8 encoded bytes.
    let outData = sanitizeUtf8Nim(inData, skipOrReplace)

    # Write the valid UTF-8 data to the output file.
    try:
      writeFile(outFilename, outData)
    except:
      echo "Unable to open and write the output file."
      return 1

    result = 0 # success

when testIconv:
  proc writeValidUtf8FileIconv(inFilename: string, outFilename: string,
                             skipInvalid: bool): int =
    ## Read the binary file input file, which might contain invalid
    ## UTF-8 bytes, then write valid UTF-8 bytes to the output file
    ## either skipping the invalid bytes or replacing them with U-FFFD.
    ##
    ## When there is an error, display the error message to standard out
    ## and return 1, else return 0.  The input file must be under 50k.

    ## This is the version of iconv and how to get the version number:
    ## iconv --version | head -1
    ## iconv (GNU libiconv 1.11)

    if fileExistsAnd50kEcho(inFilename) != 0:
      return 1

    # Run iconv on the input file to generate the output file.
    var option: string
    if skipInvalid:
      option = "-c"
    else:
      # option = "--byte-subst='(%x!)'"
      option = "--byte-subst='\xEF\xBF\xBD'"

    discard execCmd("iconv $1 -f UTF-8 -t UTF-8 $2 >$3 2>/dev/null" % [
      option, inFilename, outFilename])
    if not fileExists(outFilename) or getFileSize(outFilename) == 0:
      echo "Iconv did not generate a result file."
      result = 1
    else:
      result = 0

proc writeValidUtf8FilePython3(inFilename: string, outFilename: string,
                           skipInvalid: bool): int =
  ## Read the binary file input file, which might contain invalid
  ## UTF-8 bytes, then write valid UTF-8 bytes to the output file
  ## either skipping the invalid bytes or replacing them with U-FFFD.
  ##
  ## When there is an error, display the error message to standard out
  ## and return 1, else return 0.  The input file must be under 50k.

  if fileExistsAnd50kEcho(inFilename) != 0:
    return 1

  var option: string
  if skipInvalid:
    option = "-s"
  else:
    option = ""

  # Run a python 3 script on the input file to generate the output
  # file.
  let cmd = "python3 testfiles/writeValidUtf8.py $1 $2 $3" % [
    option, inFilename, outFilename]
  discard execCmd(cmd)

  if not fileExists(outFilename) or getFileSize(outFilename) == 0:
    echo "Python did not generate a result file."
    result = 1
  else:
    result = 0


when testNodeJs:
  proc writeValidUtf8FileNodeJs(inFilename: string, outFilename: string,
                             skipInvalid: bool): int =
    ## Read the binary file input file, which might contain invalid
    ## UTF-8 bytes, then write valid UTF-8 bytes to the output file
    ## either skipping the invalid bytes or replacing them with U-FFFD.
    ##
    ## When there is an error, display the error message to standard out
    ## and return 1, else return 0.  The input file must be under 50k.

    ## This is the version of node.js and how to get the version number:
    ## node -v
    ## v17.2.0

    if fileExistsAnd50kEcho(inFilename) != 0:
      return 1

    # Run node js  on the input file to generate the output file.
    var option: string
    if skipInvalid:
      option = "skip"
    else:
      option = "replace"

    let cmd = "node testfiles/writeValidUtf8.js $1 $2 $3"

    discard execCmd(cmd % [inFilename, outFilename, option])
    if not fileExists(outFilename) or getFileSize(outFilename) == 0:
      echo "WriteValidUtf8.js did not generate a result file."
      result = 1
    else:
      result = 0

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

proc compareTablesEcho(eTable: OrderedTable[string, TestLine],
    gotTable: OrderedTable[string, TestLine],
    skipOrReplace="replace"): bool =
  ## Compare to tables and show the differences.

  result = true
  if eTable.len != gotTable.len:
    echo "The two tables have different number of elements."
    echo "expected: " & $eTable.len
    echo "     got: " & $gotTable.len
    result = false

  for eNumStr, eTestLine in pairs(eTable):
    if not gotTable.hasKey(eNumStr):
      echo fmt"test number '{eNumStr}' does not exist in the generated table."
      result = false
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
      result = false


type
  WriteValidUtf8File = proc (inFilename, outFilename: string,
                             skipOrReplace = "replace"): int

proc testWriteValidUtf8File*(testProc: WriteValidUtf8File, option: string = "both"): bool =
  ## Test a WriteValidUtf8File procedure.  The option parameter
  ## determines which tests get run, pass "skip", "replace", or
  ## "both".

  if not (option in ["skip", "replace", "both"]):
    echo "Pass 'skip', 'replace' or 'both'."
    return false

  let eTableOr = readTestCasesFile(testCases)
  if eTableOr.isMessage:
    echo "Unable to read the test cases file."
    echo eTableOr.message
    return false
  let eTable = eTableOr.value

  let msg = createUtf8testsBinFile(binTestCases)
  if msg != "":
    echo msg
    return false

  result = true
  var rc: int
  var passed: bool

  var loop: seq[string]
  if option == "both":
    loop = @["skip", "replace"]
  else:
    loop = @[option]

  result = true
  for skipOrReplace in loop:

    # Call the write procedure to generate a file.
    let gotFile = "temp-$1.txt" % skipOrReplace
    rc = testProc(binTestCases, gotFile, skipOrReplace)
    if rc != 0:
      echo fmt"The WriteValidUtf8File procedure failed with '{skipOrReplace}'."
      result = false
      continue

    # Read the file just generated into a table.
    let gotTableOr = readTestCasesFile(gotFile)
    # discard tryRemoveFile(gotFile)
    if gotTableOr.isMessage:
      echo "Unable to read the generated file."
      echo gotTableOr.message
      result = false
      continue
    let gotTable = gotTableOr.value

    # Compare the table with the expected table.
    let passed = compareTablesEcho(eTable, gotTable, skipOrReplace)
    if not passed:
      result = false
      echo "WriteValidUtf8File with '$1' failed, see above." % skipOrReplace
      echo "------------------------------------------------------"


proc runWriteValidUtf8FileNimEcho*(skipOrReplace: string = "replace") =
  when testNim:
    discard testWriteValidUtf8File(writeValidUtf8FileNim, "skip")
