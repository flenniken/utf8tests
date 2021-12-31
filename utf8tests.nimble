# Package

version       = "0.1.0"
author        = "Steve Flenniken"
description   = "UTF-8 test cases and supporting code."
license       = "MIT"
srcDir        = "src"
bin           = @["bin/utf8tests"]


# Dependencies

requires "nim >= 1.4.8"

proc buildExe() =
  let part1 = "nim c --gc:orc --hint[Performance]:off "
  let part2 = "--hint[Conf]:off --hint[Link]: off -d:release "
  let part3 = "--out:bin/ src/utf8tests"
  var cmd = part1 & part2 & part3
  echo cmd
  exec cmd
  cmd = "strip bin/utf8tests"
  exec cmd

task n, "\tShow available tasks.":
  exec "nimble tasks"

task b, "\tBuild the utf8test app.":
  buildExe()
