import std/unittest
import unicodes

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

suite "unicodes.nim":

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
