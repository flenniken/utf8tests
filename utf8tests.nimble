import std/os
import std/strutils
import std/strformat
include src/version

proc getHostDirName(): string =
  ## Return a directory name corresponding to the given nim hostOS
  ## name.  The name is good for storing host specific files, for
  ## example in the bin and env folders.  Current possible host
  ## values: "windows", "macosx", "linux", "netbsd", "freebsd",
  ## "openbsd", "solaris", "aix", "haiku", "standalone".

  case hostOS
  of "macosx":
    result = "mac"
  of "linux":
    # Use debian to match the env/debian folder name.
    result = "debian"
  # of "windows":
  #   result = "win"
  else:
    assert false, "add a new platform"

let hostDirName = getHostDirName()

version       = utf8testsVersionNumber
author        = "Steve Flenniken"
description   = "UTF-8 test cases and UTF-8 decoder."
license       = "MIT"
srcDir        = "src"
bin           = @[fmt"bin/{hostDirName}/utf8tests"]

requires "nim >= 2.0.2"



proc buildExe() =
  var cmd = fmt"""
nim c --mm:orc --hint[Performance]:off \
  --hint[Conf]:off --hint[Link]: off -d:release \
  --out:bin/{hostDirName}/utf8tests src/utf8tests"""
  echo cmd
  exec cmd
  cmd = fmt"strip bin/{hostDirName}/utf8tests"
  exec cmd

proc get_test_filenames(): seq[string] =
  ## Return the basename of the nim files in the tests folder.
  result = @[]
  var list = listFiles("tests")
  for filename in list:
    result.add(lastPathPart(filename))

proc get_test_module_cmd(filename: string, release = false): string =
  ## Return the command line to test the given nim file.

  var rel: string
  if release:
    rel = "-d:release "
  else:
    rel = ""

  # The BareExcept is turned off because nim's unittest.nim(552, 5)
  # generates it in version 1.6.12.

  result = fmt"""nim c --mm:orc --verbosity:0 \
--hint[Performance]:off \
--hint[XCannotRaiseY]:off -d:test \
--warning[BareExcept]:off \
{rel} \
-r -p:src \
--out:bin/{hostDirName} \
tests/{filename}"""

proc runCmd(cmd: string, showOutput = false) =
  ## Run the command and if it fails, generate an exception and print
  ## out debugging info.

  let (stdouterr, rc) = gorgeEx(cmd)
  if rc != 0:
    echo "\n\n"
    echo "------"
    echo fmt"The following command failed with return code {rc}:"
    echo ""
    echo cmd
    echo ""
    echo stdouterr
    echo "------"
    echo ""
    raise newException(OSError, "the command failed")
  if showOutput:
    echo stdouterr

# tasks below

task n, "\tShow available tasks.":
  if not existsEnv("utf8tests_env"):
    echo "Error: run in a docker container not on the host."
    return
  exec "nimble tasks"

task b, "\tBuild the utf8tests app.":
  if not existsEnv("utf8tests_env"):
    echo "Error: run in a docker container not on the host."
    return
  buildExe()

task test, "\tRun one or more tests; specify part of test filename or nothing to run all.":
  ## Run one or more tests.  You specify part of the test filename and
  ## all files that match case insensitive are run. If you don't
  ## specify a name, all are run.
  if not existsEnv("utf8tests_env"):
    echo "Error: run in a docker container not on the host."
    return
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

task clean, "\tRemove all the binaries so everything gets built next time.":
  # Remove all the bin and some doc files.
  let dirs = @[fmt"bin/{hostDirName}"]
  for dir in dirs:
    let list = listFiles(dir)
    for filename in list:
      rmFile(filename)

