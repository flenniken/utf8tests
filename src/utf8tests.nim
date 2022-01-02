## Command line program to run UTF-8 tests.

import std/strutils
import std/os
import std/options
import std/parseopt
import std/strformat
import checks

const
  versionNumber = "0.1.0"

type
  Args* = object
    ## Args holds the command line arguments.
    help*: bool
    version*: bool
    replaceFilename*: string
    skipFilename*: string
    expectedFilename*: string # the utf8tests.txt filename

proc checkFile*(args: Args): int =
  ## Check the file(s).

  if args.skipFilename != "":
    let rc = checkFile(args.expectedFilename, args.skipFilename, "skip")
    if rc != 0:
      result = rc

  if args.replaceFilename != "":
    let rc = checkFile(args.expectedFilename, args.replaceFilename, "replace")
    if rc != 0:
      result = rc

proc getHelp(): string =
  ## Return the help message and usage text.
  result = """
UTF-8 Test Comparer

Compare a file created from utf8tests.bin with the expected output
defined in the utf8tests.txt file. Show the differences to the screen.

A skip type file discards invalid byte sequences. A replace type file
replaces invalid byte sequences with the Unicode replacment character
U+FFFD, <EF BF BD>.

utf8tests -h -e=utf8tests.txt [-s=filename] [-r=filename]

* -h --help          Show this help message.
* -v --version       Show the version number.
* -e --expected      The utf8tests.txt file containing the expected results.
* -s --skip          A skip type file to check.
* -r --replace       A replace type file to check.
"""

proc letterToWord(letter: char): string =
  ## Convert the one letter switch to its long form. Echo
  ## errors and return "".
  const
    switches = [
      ('h', "help"),
      ('v', "version"),
      ('e', "expected"),
      ('s', "skip"),
      ('r', "replace"),
    ]

  for (ch, word) in switches:
    if ch == letter:
      return word
  echo "Unknown switch: $1" % $letter
  return ""

proc handleOption(switch: string, word: string, value: string,
    args: var Args): int =
  ## Fill in the Args object with a value from the command line.
  ## Switch is the key from the command line, either a word or a
  ## letter.  Word is the long form of the switch. If the option
  ## cannot be handled, echo an error message. Return 0 on success.

  case word
  of "skip", "replace", "expected":
    if value == "":
      echo fmt"Missing equal sign and filename. Use --{word}=filename"
      return 1
    case word
      of "skip":
        args.skipFilename = value
      of "replace":
        args.replaceFilename = value
      of "expected":
        args.expectedFilename = value
      else:
        discard
  of "help":
    args.help = true
  of "version":
    args.version = true
  else:
    echo "Unknown switch: " & word
    return 1

proc parseRunCommandLine*(argv: seq[string]): Option[Args] =
  ## Parse the command line arguments. Echo error messages to the
  ## screen. No messages on success.

  var args: Args
  var optParser = initOptParser(argv)

  # Iterate over all arguments passed to the command line.
  for kind, key, value in getopt(optParser):
    case kind
      of CmdLineKind.cmdShortOption:
        for ix in 0..key.len-1:
          let letter = key[ix]
          let word = letterToWord(letter)
          if word == "":
            return
          let rc = handleOption($letter, word, value, args)
          if rc != 0:
            return

      of CmdLineKind.cmdLongOption:
        let rc = handleOption(key, key, value, args)
        if rc != 0:
          return

      of CmdLineKind.cmdArgument:
        echo "Unknown switch: $1" % [key]
        return

      of CmdLineKind.cmdEnd:
        discard

  # Check for missing required args.
  var emptyArgs: Args
  if args == emptyArgs:
    echo "Missing required arguments, use -h for help."
    return
  if not args.help and not args.version:
    if args.expectedFilename == "":
      echo "The -e=utftests.txt argument is required."
      return

    if args.skipFilename == "" and args.replaceFilename == "":
      echo "The -s=filename or -r=filename argument is required."
      return

  result = some(args)

proc processArgs(args: Args): int =
  ## Run what was specified on the command line. Return 0 when
  ## successful. Echo messages to the screen.

  if args.help:
    echo getHelp()
  elif args.version:
    echo versionNumber
  else:
    result = checkFile(args)

proc main(argv: seq[string]): int =
  ## Run UTF-8 test files. Return 0 when successful.

  # Setup control-c monitoring so ctrl-c stops the program.
  proc controlCHandler() {.noconv.} =
    quit 0
  setControlCHook(controlCHandler)

  try:
    # Parse the command line options then run.
    let argsO = parseRunCommandLine(argv)
    if not argsO.isSome:
      return 1
    result = processArgs(argsO.get())
  except:
    var message = "Unexpected exception: $1" % [getCurrentExceptionMsg()]
    # The stack trace is only available in the debug builds.
    when not defined(release):
      message = message & "\n" & getCurrentException().getStackTrace()
    echo message
    result = 1

when isMainModule:
  let rc = main(commandLineParams())
  quit(rc)
