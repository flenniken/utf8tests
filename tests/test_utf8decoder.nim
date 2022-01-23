import std/unittest
import utf8decoder

suite "utf8decoder.nim":

  test "validateUtf8String":
    check validateUtf8String("") == -1
    check validateUtf8String("a") == -1
    check validateUtf8String("ab") == -1
    check validateUtf8String("\xC2\xA9") == -1
    check validateUtf8String("\xE2\x80\x90") == -1
    check validateUtf8String("\xF0\x9D\x92\x9C") == -1
    # U-FFFF
    check validateUtf8String("\xEF\xBF\xBF") == -1

    # Null
    check validateUtf8String("\x00") == -1

  test "validateUtf8String invalid bytes":
    check validateUtf8String("\xff") == 0

    # too big
    check validateUtf8String("\xF7\xBF\xBF\xBF") == 0

    # overlong solidus
    check validateUtf8String("\xc0\xaf") == 0

    # surrogate
    check validateUtf8String("\xed\xa0\x80") == 0

  test "validateUtf8String invalid pos":
    check validateUtf8String("0\xff") == 1
    check validateUtf8String("01\xff") == 2
    check validateUtf8String("0\xff1") == 1

    check validateUtf8String("\xC2\xA9\xed\xa0\x80") == 2
    check validateUtf8String("\xC2\xA9\xed\xa0\x80\xff") == 2

    check validateUtf8String("\xC2\xA9\xE2\x80\x90\xF0\x9D\x92\x9C\xff") == 9


  test "utf8CharString":
    check utf8CharString("", 0) == ""
    check utf8CharString("a", 0) == "a"
    check utf8CharString("ab", 0) == "a"
    check utf8CharString("ab", 1) == "b"
    check utf8CharString("abc", 0) == "a"
    check utf8CharString("abc", 1) == "b"
    check utf8CharString("abc", 2) == "c"

    check utf8CharString("\xC2\xA9", 0) == "\xC2\xA9"
    check utf8CharString("\xE2\x80\x90", 0) == "\xE2\x80\x90"
    check utf8CharString("\xF0\x9D\x92\x9C", 0) == "\xF0\x9D\x92\x9C"

    check utf8CharString("\xC2\xA9\xC2\xA9", 0) == "\xC2\xA9"
    check utf8CharString("\xC2\xA9\xE2\x80\x90\xC2\xA9", 0) == "\xC2\xA9"
    check utf8CharString("\xC2\xA9\xF0\x9D\x92\x9C\xC2\xA9", 0) == "\xC2\xA9"

    check utf8CharString("\xC2\xA9\xC2\xA9", 2) == "\xC2\xA9"
    check utf8CharString("\xC2\xA9\xE2\x80\x90\xC2\xA9", 2) == "\xE2\x80\x90"
    check utf8CharString("\xC2\xA9\xF0\x9D\x92\x9C\xC2\xA9", 2) == "\xF0\x9D\x92\x9C"

  test "utf8CharString invalid pos":

    check utf8CharString("", 0) == ""
    check utf8CharString("a", 1) == ""
    check utf8CharString("ab", 2) == ""

    check utf8CharString("\xC2\xA9", 1) == ""
    check utf8CharString("\xE2\x80\x90", 1) == ""
    check utf8CharString("\xE2\x80\x90", 2) == ""
    check utf8CharString("\xF0\x9D\x92\x9C", 1) == ""
    check utf8CharString("\xF0\x9D\x92\x9C", 2) == ""
    check utf8CharString("\xF0\x9D\x92\x9C", 3) == ""

    check utf8CharString("abc\xC2\xA9def", 4) == ""
