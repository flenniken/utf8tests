import std/unittest
import std/unicode
import utf8decoder

proc testSanitizeutf8Empty(str: string): bool =
  ## Test that the string does not have any valid UTF-8 bytes.

  result = true
  let empty = sanitizeUtf8(str, "skip")
  if empty != "":
    echo "expected nothing, got: " & empty
    result = false

  let rchars = sanitizeUtf8(str, "replace")
  if rchars.len != str.len * 3 or rchars.len mod 3 != 0:
    echo "expected all replace characters, got: " & rchars
    result = false
  else:
    # check at all the bytes are U-FFFD (EF BF BD)
    for ix in countUp(0, rchars.len-3, 3):
      if rchars[ix] != '\xEF' or rchars[ix+1] != '\xBF' or
         rchars[ix+2] != '\xBD':
        echo "expected all replace characters, got: " & rchars
        result = false
        break

proc testSanitizeutf8(str: string, expected: string, skipOrReplace = "replace"): bool =
  ## Test that sanitizeUtf8 returns the expected string when skipping.

  result = true
  let sanitized = sanitizeUtf8(str, skipOrReplace)
  if sanitized != expected:
    echo "     got: " & sanitized
    echo "expected: " & expected
    result = false

suite "utf8decoder.nim":

  test "sanitizeUtf8":
    check sanitizeUtf8("happy path", "skip") == "happy path"
    check sanitizeUtf8("happy path", "replace") == "happy path"

    check testSanitizeutf8Empty("\x80")
    check testSanitizeutf8Empty("\xbf")
    check testSanitizeutf8Empty("\x80\xbf")
    check testSanitizeutf8Empty("\xf8\x88\x80\x80\x80")
  
  test "sanitizeUtf8 all 64 possible continuation bytes":
    # 0x80-0xbf
    check testSanitizeutf8Empty("\x80\x81\x82\x83\x84\x85\x86\x87")
    check testSanitizeutf8Empty("\x88\x89\x8a\x8b\x8c\x8d\x8e\x8f")
    check testSanitizeutf8Empty("\x90\x91\x92\x93\x94\x95\x96\x97")
    check testSanitizeutf8Empty("\x98\x99\x9a\x9b\x9c\x9d\x9e\x9f")
    check testSanitizeutf8Empty("\xa0\xa1\xa2\xa3\xa4\xa5\xa6\xa7")
    check testSanitizeutf8Empty("\xa8\xa9\xaa\xab\xac\xad\xae\xaf")
    check testSanitizeutf8Empty("\xb0\xb1\xb2\xb3\xb4\xb5\xb6\xb7")
    check testSanitizeutf8Empty("\xb8\xb9\xba\xbb\xbc\xbd\xbe\xbf")

  test "32 first bytes of 2-byte sequences (0xc0-0xdf)":
    check testSanitizeutf8("\xc0\x20\xc1\x20\xc2\x20\xc3\x20", "    ", "skip")
    check testSanitizeutf8("\xc4\x20\xc5\x20\xc6\x20\xc7\x20", "    ", "skip")
    check testSanitizeutf8("\xc8\x20\xc9\x20\xca\x20\xcb\x20", "    ", "skip")
    check testSanitizeutf8("\xcc\x20\xcd\x20\xce\x20\xcf\x20", "    ", "skip")
    check testSanitizeutf8("\xd0\x20\xd1\x20\xd2\x20\xd3\x20", "    ", "skip")
    check testSanitizeutf8("\xd4\x20\xd5\x20\xd6\x20\xd7\x20", "    ", "skip")
    check testSanitizeutf8("\xd8\x20\xd9\x20\xda\x20\xdb\x20", "    ", "skip")
    check testSanitizeutf8("\xdc\x20\xdd\x20\xde\x20\xdf\x20", "    ", "skip")

  test "Byte fe and ff cannot appear in UTF-8":

    check testSanitizeutf8Empty("\x80")
    check testSanitizeutf8Empty("\x81")
    check testSanitizeutf8Empty("\xfe")
    check testSanitizeutf8Empty("\xff")

    check sanitizeutf8("\x37\xff", "skip") ==  "7"
    check sanitizeutf8("\x37\xff", "replace") ==  "7\ufffd"
    check sanitizeutf8("\xff56", "skip") ==  "56"
    check sanitizeutf8("\xff56", "replace") ==  "\ufffd56"

    check testSanitizeutf8("\x37\x38\xfe", "78", "skip")
    check testSanitizeutf8("\x37\x38\x39\xfe", "789", "skip")

  test "overlong solidus":
    check testSanitizeutf8Empty("\xc0\xaf")
    check testSanitizeutf8Empty("\xe0\x80\xaf")

  test "restart after invalid":
    # This test shows how restarting works after an invalid multi-byte
    # sequence when replacing.
    check testSanitizeutf8("\xf4\x31", "\xef\xbf\xbd\x31", "replace")
    check testSanitizeutf8("\xf4\x80\x31", "\xef\xbf\xbd\x31", "replace")
    check testSanitizeutf8("\xf0\x90\x80\x31", "\xef\xbf\xbd\x31", "replace")
    check testSanitizeutf8("\xf1\x80\x80\xff", "\xef\xbf\xbd\xef\xbf\xbd", "replace")

    check testSanitizeutf8("\xf4\x80", "\xef\xbf\xbd", "replace")
    check testSanitizeutf8("\xf0\x90\x80", "\xef\xbf\xbd", "replace")

  test "validateUtf8String":
    check validateUtf8String("") == -1
    check validateUtf8String("d") == -1
    check validateUtf8String("asdf") == -1
    check validateUtf8String("\xC2\xA9") == -1
    check validateUtf8String("\xE2\x80\x90") == -1
    check validateUtf8String("\xF0\x9D\x92\x9C") == -1
    check validateUtf8String("asdf\xF0\x9D\x92\x9C\xE2\x80\x90\xC2\xA9") == -1

  test "validateUtf8String pos":
    check validateUtf8String("\xff") == 0
    check validateUtf8String("1\xff") == 1
    check validateUtf8String("12\xff") == 2
    check validateUtf8String("12\xC2\xA9\xff") == 4
    check validateUtf8String("\xff3") == 0
    check validateUtf8String("\xff43") == 0
    check validateUtf8String("\xf1\x80\x80\x00") == 0
    check validateUtf8String("22\xf1\x80\x80\x00") == 2
    check validateUtf8String("\xf4\x80\x80\x00") == 0
    check validateUtf8String("\xf0\x90\x80\x00") == 0
    check validateUtf8String("\xed\x80\x00") == 0
    check validateUtf8String("\xe0\x80\x7f") == 0

    check validateUtf8String("\xf4\x80\x80") == 0
    check validateUtf8String("\xf0\x90\x80") == 0
    check validateUtf8String("\xed\x80") == 0
    check validateUtf8String("\xe0\x80") == 0

  test "utf8CharString":
    check utf8CharString("a", 0) == "a"
    check utf8CharString("ab", 0) == "a"

    check utf8CharString("ab", 1) == "b"
    check utf8CharString("abc", 1) == "b"
    check utf8CharString("abc", 2) == "c"

  test "utf8CharString invalid index":
    check utf8CharString("", 0) == ""
    check utf8CharString("a", 1) == ""
    check utf8CharString("a", 2) == ""
    check utf8CharString("abc", 3) == ""

  test "utf8CharString multi-byte":
    check utf8CharString("\xC2\xA9", 0) == "\xC2\xA9"
    check utf8CharString("\xE2\x80\x90", 0) == "\xE2\x80\x90"
    check utf8CharString("\xF0\x9D\x92\x9C", 0) == "\xF0\x9D\x92\x9C"
    check utf8CharString("asdf\xF0\x9D\x92\x9C\xE2\x80\x90\xC2\xA9", 4) == "\xF0\x9D\x92\x9C"
  test "utf8CharString start in the middle":
    check utf8CharString("\xC2\xA9", 1) == ""
    check utf8CharString("\xF0\x9D\x92\x9C", 1) == ""
    check utf8CharString("\xF0\x9D\x92\x9C", 2) == ""
    check utf8CharString("\xF0\x9D\x92\x9C", 3) == ""

  test "validateUtf8":
    check validateUtf8("\xff") == 0

    # # too big U+001FFFFF, <F7 BF BF BF>
    # # 6.0:invalid hex:F7 BF BF BF:nothing:EFBFBD  EFBFBD  EFBFBD  EFBFBD
    # check validateUtf8("\xf7\xbf\xbf\xbf") == 0

    # # overlong solidus <e0 80 af>
    # # 22.3:invalid hex:e0 80 af:nothing:EFBFBD EFBFBD EFBFBD
    # check validateUtf8("\xe0\x80\xaf") == 0

    # # 1 surrogate U+D800, <ed a0 80>
    # # 24.0:invalid hex:ed a0 80:nothing:EFBFBD EFBFBD EFBFBD
    # check validateUtf8("\xed\xa0\x80") == 0
