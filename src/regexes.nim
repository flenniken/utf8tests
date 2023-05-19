## Perl regular expression matching.

# The notice below is here because this module includes the nim re module.
#[
Written by Philip Hazel
Copyright (c) 1997-2005 University of Cambridge

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

  Redistributions of source code must retain the above copyright
  notice, this list of conditions and the following disclaimer.
  Redistributions in binary form must reproduce the above copyright
  notice, this list of conditions and the following disclaimer in the
  documentation and/or other materials provided with the distribution.
  Neither the name of the University of Cambridge nor the names of its
  contributors may be used to endorse or promote products derived from
  this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]#

import std/re
import std/options
import std/tables

const
  ## The maximum number of groups supported in the matchPattern procedure.
  maxGroups = 10

var compliledPatterns = initTable[string, Regex]()
  ## A cache of compiled regex patterns, mapping a pattern to Regex.

type
  Matches* = object
    ## Holds the result of a match.
    groups*: seq[string]
    length*: Natural
    start*: Natural

  Replacement* = object
    ## Holds the regular expression and replacement for the replaceMany
    ## function.
    pattern*: string
    sub*: string

proc newMatches*(length: Natural, start: Natural, groups: varargs[string]): Matches =
  ## Return a Matches object.
  result.length = length
  result.start = start
  for group in groups:
    result.groups.add(group)

func getGroups*(matches: Matches, groupCount: Natural): seq[string] =
  ## Return the number of groups specified. If one of the groups doesn't
  ## exist, "" is returned for it.

  var count: Natural
  if groupCount > maxGroups:
    count = maxGroups
  else:
    count = groupCount

  var groups = newSeqOfCap[string](count)
  for ix in countUp(0, count-1):
    if ix < matches.groups.len:
      groups.add(matches.groups[ix])
    else:
      groups.add("")
  result = groups

func matchRegex*(str: string, regex: Regex, start: Natural = 0): Option[Matches] =
  ## Match a regular expression pattern in a string.

  var groups = newSeq[string](maxGroups)
  let length = matchLen(str, regex, groups, start)
  if length != -1:
    var matches = Matches(length: length, groups: newSeq[string]())
    matches.length = length
    matches.start = start

    # Find the last non-empty group.
    var ixList = -1
    for ix, group in groups:
      if group != "":
        ixList = ix

    # Return the matches up to the last non-empty one.
    if ixList != -1:
      for ix in countUp(0, ixList):
        matches.groups.add(groups[ix])
    result = some(matches)

func compilePattern(pattern: string): Option[Regex] =
  try:
    let regex = re(pattern)
    result = some(regex)
  except CatchableError:
    result = none(Regex)

proc matchPatternCached*(str: string, pattern: string,
    start: Natural = 0): Option[Matches] =
  ## Match a pattern in a string and cache the compiled regular
  ## expression pattern.

  # Get the cached regex for the pattern or compile it and add it to
  # the cache.
  var regex: Regex
  if pattern in compliledPatterns:
    regex = compliledPatterns[pattern]
  else:
    let regexO = compilePattern(pattern)
    if not regexO.isSome:
      return
    regex = regexO.get()
    compliledPatterns[pattern] = regex
  result = matchRegex(str, regex, start)

func matchPattern*(str: string, pattern: string,
    start: Natural = 0): Option[Matches] =
  ## Match a regular expression pattern in a string.
  let regexO = compilePattern(pattern)
  if not regexO.isSome:
    return
  result = matchRegex(str, regexO.get(), start)

func newReplacement*(pattern: string, sub: string): Replacement =
  ## Create a new Replacement object.
  result = Replacement(pattern: pattern, sub: sub)

proc replaceMany*(str: string, replacements: seq[Replacement]): Option[string] =
  ## Replace the patterns in the string with their replacements.

  var subs: seq[tuple[pattern: Regex, repl: string]]
  for r in replacements:
    let regexO = compilePattern(r.pattern)
    if not regexO.isSome:
      return
    let regex = regexO.get()
    subs.add((regex, r.sub))
  result = some(multiReplace(str, subs))
