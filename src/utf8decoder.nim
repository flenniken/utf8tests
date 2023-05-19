## Functions for decoding and validating UTF-8.

# copyright notice:

# http://bjoern.hoehrmann.de/utf-8/decoder/dfa/

# Copyright (c) 2008-2009 Bjoern Hoehrmann <bjoern@hoehrmann.de>

# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# end copyright notice

const
  # The accept state is 0 and the reject state is 12.

  # The first part of the table maps bytes to character classes that
  # to reduce the size of the transition table and create bitmasks.
  utf8d = [
   0u8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
     1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,  9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,
     7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,  7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
     8,8,2,2,2,2,2,2,2,2,2,2,2,2,2,2,  2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
    10,3,3,3,3,3,3,3,3,3,3,3,3,4,3,3, 11,6,6,6,5,8,8,8,8,8,8,8,8,8,8,8,

    # The second part is a transition table that maps a combination
    # of a state of the automaton and a character class to a state.
     0,12,24,36,60,96,84,12,12,12,48,72, 12,12,12,12,12,12,12,12,12,12,12,12,
    12, 0,12,12,12,12,12, 0,12, 0,12,12, 12,24,12,12,12,12,12,24,12,24,12,12,
    12,12,12,12,12,12,12,24,12,12,12,12, 12,24,12,12,12,12,12,12,12,24,12,12,
    12,12,12,12,12,12,12,36,12,36,12,12, 12,36,12,12,12,12,12,36,12,36,12,12,
    12,36,12,12,12,12,12,12,12,12,12,12,
  ]

proc decode*(state: var uint32, codep: var uint32, sByte: char) =
  ## Interior part of a UTF-8 decoder.

  let ctype = uint32(utf8d[uint8(sByte)])
  if state != 0:
    codep = (uint32(sByte) and 0x3fu32) or (codep shl 6u32)
  else:
    codep = (0xffu32 shr ctype) and uint32(sByte)
  state = utf8d[256 + state + ctype]

iterator yieldUtf8Chars*(str: string, ixStartSeq: var int,
    ixEndSeq: var int, codePoint: var uint32): bool =
  ## Iterate through the string's UTF-8 character byte sequences.
  ## For each character set ixStartSeq, ixEndSeq, and codePoint.
  ## Return true when the bytes sequence is valid else return false.
  ##
  ## You can get the current byte sequence with:
  ## str[ixStartSeq .. ixEndSeq]
  ##
  ## A UTF-8 character is a one to four byte sequence.

  ixStartSeq = 0
  ixEndSeq = 0
  codePoint = 0
  var state = 0u32
  while true:
    if ixEndSeq >= str.len:
      break
    decode(state, codePoint, str[ixEndSeq])

    case state:
    of 0:
      yield true
      inc(ixEndSeq)
      ixStartSeq = ixEndSeq
    of 12:
      if ixEndSeq > ixStartSeq:
        # Restart at the byte that broke a multi-byte sequence.
        dec(ixEndSeq)
      codePoint = 0
      yield false
      inc(ixEndSeq)
      ixStartSeq = ixEndSeq
      state = 0
    else:
      inc(ixEndSeq)

  if state != 0:
    yield false

func validateUtf8String*(str: string): int =
  ## Return the position of the first invalid UTF-8 byte in the string
  ## else return -1.

  var ixStartSeq: int
  var ixEndSeq: int
  var codePoint: uint32
  for valid in yieldUtf8Chars(str, ixStartSeq, ixEndSeq, codePoint):
    if not valid:
      return ixStartSeq
  result = -1

func sanitizeUtf8*(str: string, skipOrReplace: string = "replace"): string =
  ## Sanitize and return the UTF-8 string. The skipOrReplace parameter
  ## determines whether to skip or replace invalid bytes.  When
  ## replacing the U+FFFD character is used.

  let skipInvalid = if skipOrReplace == "skip": true else: false

  var ixStartSeq: int
  var ixEndSeq: int
  var codePoint: uint32
  for valid in yieldUtf8Chars(str, ixStartSeq, ixEndSeq, codePoint):
    if valid:
      result.add(str[ixStartSeq .. ixEndSeq])
    elif not skipInvalid:
      result.add("\uFFFD")

func utf8CharString*(str: string, pos: Natural): string =
  ## Get the unicode character at pos.  Return a one character
  ## string. Return "" when not a UTF-8 character.
  if pos > str.len - 1:
    return

  var ixStartSeq: int
  var ixEndSeq: int
  var codePoint: uint32
  for valid in yieldUtf8Chars(str[pos .. str.len-1], ixStartSeq, ixEndSeq, codePoint):
    if valid:
      return str[pos+ixStartSeq .. pos+ixEndSeq]
    else:
      return ""
