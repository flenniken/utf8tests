## Command line program to run UTF-8 tests.

import std/strutils
import std/os
import std/options
import std/parseopt

const
  versionNumber = "0.1.0"
  
type
  Args* = object
    ## Args holds the command line arguments.
    help*: bool
    version*: bool
    skip*: bool
    replace*: bool
    filename*: string

proc checkFile*(filename: string): int =
  ## Check the file for errors. Echo errors to the screen. Return 0 on
  ## success.
  echo "not implemented"
  return 1

proc getHelp(): string =
  ## Return the help message and usage text.
  result = """
# UTF-8 Test Runner

Check an UTF-8 file for errors. You generate the file from utf8tests.bin.

## Usage

utf8tests -h -s -r -f=filename

* -h --help          Show this help message.
* -v --version       Show the version number.
* -s --skip          File was created skipping invalid byte sequences.
* -r --replace       File was created replacing invalid byte sequences with U-FFFD <EFBFBD>.
* -f --filename      File to check.
"""

proc letterToWord(letter: char): string =
  ## Convert the one letter switch to its long form. Echo
  ## errors and return "".
  const
    switches = [
      ('h', "help"),
      ('v', "version"),
      ('s', "skip"),
      ('r', "replace"),
      ('f', "filename"),
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

  if word == "filename":
    if value == "":
      echo "Missing filename. Use -f=filename"
      return 1
    else:
      args.filename = value
  elif word == "help":
    args.help = true
  elif word == "version":
    args.version = true
  elif word == "skip":
    args.skip = true
  elif word == "replace":
    args.replace = true
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

  result = some(args)

proc processArgs(args: Args): int =
  ## Run what was specified on the command line. Return 0 when
  ## successful. Echo messages to the screen.

  if args.help:
    echo getHelp()
  elif args.version:
    echo versionNumber
  elif args.filename != "":
    result = checkFile(args.filename)
  else:
    echo "Missing argments, use -h for help."
    result = 1

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
