## Procedures to read UTF-8 files and write the sanitized data to a
## new file.

import std/os
import std/strutils
import std/unicode
import std/osproc
import unicodes

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

proc writeValidUtf8Ref*(inFilename: string, outFilename: string,
    skipOrReplace = "replace"): int =
  ## Read the binary file input file, which contains invalid UTF-8
  ## bytes, then write valid UTF-8 bytes to the output file either
  ## skipping the invalid bytes or replacing them with U+FFFD.  Return
  ## 0 on success. On error display the error message to standard out.
  ## The input file must be under 50k.

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
  let outData = sanitizeUtf8(inData, skipOrReplace)

  # Write the valid UTF-8 data to the output file.
  try:
    writeFile(outFilename, outData)
  except:
    echo "Unable to open and write the output file."
    return 1

  result = 0 # success

proc writeFileUsingWriter*(cmd: string, inFilename: string,
    outFilename: string, skipOrReplace = "replace"): int =
  ## Read the binary input file which might contain invalid
  ## UTF-8 bytes, then write valid UTF-8 bytes to the output file
  ## either skipping the invalid bytes or replacing them with U+FFFD.
  ##
  ## When there is an error, display the error message to standard out
  ## and return 1, else return 0.  The input file must be under 50k.

  # Check the file exists and is small.
  if fileExistsAnd50kEcho(inFilename) != 0:
    return 1

  discard tryRemoveFile(outFilename)

  let fullCmd = cmd % [inFilename, outFilename, skipOrReplace]
  discard execCmd(fullCmd)

  if not fileExists(outFilename) or getFileSize(outFilename) == 0:
    echo "The output file wasn't created."
    result = 1
  else:
    result = 0

proc sanitizeUtf8Nim*(str: string, skipOrReplace = "replace"): string =
  ## Sanitize and return the UTF-8 string. The skipOrReplace parameter
  ## determines whether to skip or replace invalid bytes.  When
  ## replacing the U+FFFD character is used.

  let skipInvalid = if skipOrReplace == "skip": true else: false

  # Reserve space for the result string the same size as the input string.
  result = newStringOfCap(str.len)

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
      # This is not correct enough for current best practices.
      result.add("\ufffd")
    ix = endPos + 1

proc writeValidUtf8FileNim*(inFilename: string, outFilename: string,
                           skipOrReplace = "replace"): int =

  if fileExistsAnd50kEcho(inFilename) != 0:
    return 1

  if skipOrReplace == "replace":
    echo "Replace is not currently supported."
    return 1

  discard tryRemoveFile(outFilename)

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

proc writeValidUtf8FileIconv*(inFilename: string, outFilename: string,
    skipOrReplace = "replace"): int =
  if skipOrReplace == "replace":
    echo "Replace not supported."
    return 1
  let cmd = "iconv -c -f UTF-8 -t UTF-8 $1 >$2 2>/dev/null"
  return writeFileUsingWriter(cmd, inFilename, outFilename, skipOrReplace)

proc writeValidUtf8FilePython3*(inFilename: string, outFilename: string,
    skipOrReplace = "replace"): int =
  let cmd = "python3 writers/writeValidUtf8.py $1 $2 $3"
  return writeFileUsingWriter(cmd, inFilename, outFilename, skipOrReplace)

proc writeValidUtf8FileNodeJs*(inFilename: string, outFilename: string,
                           skipOrReplace = "replace"): int =
  if skipOrReplace == "skip":
    echo "Skip not supported."
    return 1

  let cmd = "node writers/writeValidUtf8.js $1 $2 $3"
  return writeFileUsingWriter(cmd, inFilename, outFilename, skipOrReplace)

proc writeValidUtf8FilePerl*(inFilename: string, outFilename: string,
                           skipOrReplace = "replace"): int =
  if skipOrReplace == "skip":
    echo "Skip not supported."
    return 1

  let cmd = "perl writers/writeValidUtf8.pl $1 $2 $3"
  return writeFileUsingWriter(cmd, inFilename, outFilename, skipOrReplace)
