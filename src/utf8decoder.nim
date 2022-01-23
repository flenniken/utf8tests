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

proc decode(state: var uint32, codep: var uint32, sByte: char) =
  ## Interior part of a UTF-8 decoder.

  let ctype = uint32(utf8d[uint8(sByte)])
  if state != 0:
    codep = (uint32(sByte) and 0x3fu32) or (codep shl 6u32)
  else:
    codep = (0xffu32 shr ctype) and uint32(sByte)
  state = utf8d[256 + state + ctype]

func validateUtf8String*(str: string): int =
  ## Return the position of the first invalid UTF-8 byte in the string
  ## else return -1.

  var codePoint: uint32 = 0
  var state: uint32 = 0
  var byteCount = 0
  var ix: int

  for sByte in str:
    decode(state, codePoint, sByte)
    if state == 12:
      break
    if state == 0:
      byteCount = 0
    else:
      inc(byteCount)
    inc(ix)

  if state != 0:
    result = ix - byteCount
    assert result >= 0
  else:
    result = -1

func sanitizeUtf8*(str: string, skipOrReplace: string = "replace"): string =
  ## Sanitize and return the UTF-8 string. The skipOrReplace parameter
  ## determines whether to skip or replace invalid bytes.  When
  ## replacing the U+FFFD character is used.

  let skipInvalid = if skipOrReplace == "skip": true else: false

  const
    replacementChar = "\uFFFD"

  var codePoint: uint32 = 0
  var state: uint32 = 0

  # String index to the first byte of the current character.
  var ixChar = 0

  # Reserve space for the result string the same size as the input string.
  result = newStringOfCap(str.len)

  # Loop through the string bytes.
  var ix = 0
  while true:
    if ix >= str.len:
      if state != 0:
        # We got to the end of the string but did not finish with a
        # valid character.
        if not skipInvalid:
          result.add(replacementChar)
      break # all done

    # Process the string byte.
    let sByte = str[ix]
    decode(state, codePoint, sByte)

    # Handle an invalid byte sequence.
    if state == 12:
      if not skipInvalid:
        result.add(replacementChar)
      # Restart at the byte that broke a multi-byte sequence.
      state = 0
      if ix - ixChar == 0:
        inc(ix)
      ixChar = ix
      continue

    # Add the valid character to the result string.
    if state == 0:
      result.add(str[ixChar .. ix])
      ixChar = ix + 1
    inc(ix)

func utf8CharString*(str: string, pos: Natural): string =
  ## Get the unicode character at pos.  Return a one character
  ## string. Return "" when not a UTF-8 character.
  if pos > str.len - 1:
    return
  var codePoint: uint32
  var state: uint32 = 0
  for sByte in str[pos .. str.len - 1]:
    decode(state, codePoint, sByte)
    if state == 12:
      return ""
    result.add(char(sByte))
    if state == 0:
      return result
  result = ""

func utf8CodePoint*(str: string, pos: Natural): int =
  ## Return the unicode code point at pos.  Return -1 when not a UTF-8
  ## character.
  if pos > str.len - 1:
    return -1
  var codePoint: uint32
  var state: uint32 = 0
  for sByte in str[pos .. str.len - 1]:
    decode(state, codePoint, sByte)
    if state == 0:
      return int(codePoint)
    if state == 12:
      break
  result = -1
