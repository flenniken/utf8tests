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

const
  utf8testsImage = "utf8tests-image"
  utf8testsContainer = "utf8tests-container"

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

proc doesImageExist(): bool =
  let cmd = fmt"docker inspect {utf8testsImage} 2>/dev/null | grep 'Id'"
  let (imageStatus, _) = gorgeEx(cmd)
  # echo imageStatus
  if "sha256" in imageStatus:
    result = true

proc getContainerState(): string =
  let cmd2=fmt"docker inspect {utf8testsContainer} 2>/dev/null | grep Status"
  let (containerStatus, _) = gorgeEx(cmd2)
  if "running" in containerStatus:
    result = "running"
  elif "exited" in containerStatus:
    result = "exited"
  else:
    result = "no container"

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

task drun, "\tRun a utf8tests debian docker build environment":

  # Verify we are running in the utf8tests root folder by looking for
  # the nimble file.
  let dir = getCurrentDir()
  let nimbleFile = joinPath(dir, "utf8tests.nimble")
  if not fileExists(nimbleFile):
    echo fmt"Current dir: {dir}"
    echo "Run from the utf8tests root folder."
    return

  if existsEnv("utf8tests_env"):
    echo "Run on the host not in the docker container."
    return

  if doesImageExist():
    echo fmt"The {utf8testsImage} exists."
  else:
    echo fmt"The {utf8testsImage} does not exist, creating it..."

    let buildCmd = fmt"docker build --tag={utf8testsImage} env/debian/."
    # echo buildCmd

    exec buildCmd

    echo ""
    echo "If no errors, run drun again to run the container."
    return

  let state = getContainerState()
  if state == "running":
    echo fmt"The {utf8testsContainer} is running, attaching to it..."
    let attachCmd = fmt"docker attach {utf8testsContainer}"
    exec attachCmd
  elif state == "exited":
    echo fmt"The {utf8testsContainer} exists but its not running, starting it..."
    let runCmd = fmt"docker start -ai {utf8testsContainer}"
    exec runCmd
  else:
    echo fmt"The {utf8testsContainer} does not exist, creating it..."
    let shared_option = fmt"-v {dir}:/home/utf8tester/utf8tests"
    let createCmd = fmt"docker run --name={utf8testsContainer} -it {shared_option} {utf8testsImage}"
    exec createCmd

task ddelete, "\tDelete the utf8tests docker image and container.":
  if existsEnv("utf8tests_env"):
    echo "Run on the host not in the docker container."
    return

  let state = getContainerState()
  if state == "running":
    echo "The container is running, exit it and try again."
    return
  elif state == "exited":
    let cmd = fmt"docker rm {utf8testsContainer}"
    runCmd(cmd, showOutput = true)

  if doesImageExist():
    let cmd = fmt"docker image rm {utf8testsImage}"
    runCmd(cmd, showOutput = true)

task dlist, "\tList the docker image and container.":
  if existsEnv("utf8tests_env"):
    echo "Run on the host not in the docker container."
    return

  if doesImageExist():
    echo fmt"The {utf8testsImage} exists."
  else:
    echo fmt"No {utf8testsImage}."

  let cmd2=fmt"docker inspect {utf8testsContainer} 2>/dev/null | grep Status"
  let (containerStatus, _) = gorgeEx(cmd2)
  # echo containerStatus
  if "running" in containerStatus:
    echo fmt"The {utf8testsContainer} is running."
  elif "exited" in containerStatus:
    echo fmt"The {utf8testsContainer} is stopped."
  else:
    echo fmt"No {utf8testsContainer}."

task clean, "\tRemove all the binaries so everything gets built next time.":
  # Remove all the bin and some doc files.
  let dirs = @[fmt"bin/{hostDirName}"]
  for dir in dirs:
    let list = listFiles(dir)
    for filename in list:
      rmFile(filename)

