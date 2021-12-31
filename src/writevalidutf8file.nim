import std/os
import std/strutils
import std/unicode
import std/osproc
import unicodes
import checks

const
  # The tests turned off do not pass.
  testIconv = false
  testNim = true
  testNodeJs = false


proc writeValidUtf8Ref*(inFilename: string, outFilename: string,
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


proc runWriteValidUtf8FileNimEcho*(skipOrReplace: string = "replace") =
  when testNim:
    discard testWriteValidUtf8File(writeValidUtf8FileNim, "skip")

