import std/os
import std/strutils
import std/strformat

version       = "0.1.3"
author        = "Steve Flenniken"
description   = "UTF-8 test cases and UTF-8 decoder."
license       = "MIT"
srcDir        = "src"
bin           = @["bin/utf8tests"]

requires "nim >= 1.6.12"

proc buildExe() =
  let part1 = "nim c --gc:orc --hint[Performance]:off "
  let part2 = "--hint[Conf]:off --hint[Link]: off -d:release "
  let part3 = "--out:bin/ src/utf8tests"
  var cmd = part1 & part2 & part3
  echo cmd
  exec cmd
  cmd = "strip bin/utf8tests"
  exec cmd

proc get_test_filenames(): seq[string] =
  ## Return the basename of the nim files in the tests folder.
  result = @[]
  var list = listFiles("tests")
  for filename in list:
    result.add(lastPathPart(filename))

proc get_test_module_cmd(filename: string, release = false): string =
  ## Return the command line to test the given nim file.

  let binName = changeFileExt(filename, "bin")
  var rel: string
  if release:
    rel = "-d:release "
  else:
    rel = ""

  # The BareExcept is turned off because nim's unittest.nim(552, 5)
  # generates it in version 1.6.12.

  result = fmt"""nim c --gc:orc --verbosity:0 \
--hint[Performance]:off \
--hint[XCannotRaiseY]:off -d:test \
--warning[BareExcept]:off \
{rel} \
-r -p:src \
--out:bin/{binName} \
tests/{filename}"""

# tasks below

task n, "\tShow available tasks.":
  exec "nimble tasks"

task b, "\tBuild the utf8tests app.":
  buildExe()

task test, "\tRun one or more tests; specify part of test filename.":
  ## Run one or more tests.  You specify part of the test filename and
  ## all files that match case insensitive are run. If you don't
  ## specify a name, all are run.
  let count = system.paramCount()+1
  # The name is either part of a name or "test" when not
  # specified. Test happens to match all test files.
  let name = system.paramStr(count-1)
  let test_filenames = get_test_filenames()
  for filename in test_filenames:
    if name.toLower in filename.toLower:
      # echo ""
      let cmd = get_test_module_cmd(filename)
      # echo cmd
      exec cmd
