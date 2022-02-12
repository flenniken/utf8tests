import std/unittest
import std/strutils
import std/strformat
import utf8decoder

func stringToHex*(str: string): string =
  ## Convert the string bytes to hex bytes like 34 a9 ff e2.
  var digits: seq[string]
  for ch in str:
    let abyte = uint8(ord(ch))
    digits.add(fmt"{abyte:02x}")
  result = digits.join(" ")

proc testYieldUtf8Char(str: string, eUtf8Chars: seq[string],
    eCodePoints: seq[uint32], eValid: seq[bool]): bool =
  ## Test the yieldUtf8Chars iterator.

  if eUtf8Chars.len != eCodePoints.len:
    echo "eUtf8Chars.len != eCodePoints.len"
    return false
  if eUtf8Chars.len != eValid.len:
    echo "eUtf8Chars.len != eValid.len"
    return false

  var ixStartChar: int
  var ixEndChar: int
  var codePoint: uint32
  var ix = 0
  for valid in yieldUtf8Chars(str, ixStartChar, ixEndChar, codePoint):
    if valid != eValid[ix]:
      echo "$1[u$2]" % [str, $ix]
      echo "expected: " & $eValid[ix]
      echo "     got: " & $valid
      return false
    var utf8Char: string
    try:
      utf8Char = str[ixStartChar .. ixEndChar]
    except:
      echo "$1[u$2]" % [str, $ix]
      echo "ixStartChar: " & $ixStartChar
      echo "ixEndChar: " & $ixEndChar
      echo getCurrentExceptionMsg()
      return false

    if utf8Char != eUtf8Chars[ix]:
      echo "$1[u$2]" % [str, $ix]
      echo "expected char hex: <$1> str: $2" % [stringToHex(eUtf8Chars[ix]), eUtf8Chars[ix]]
      echo "     got char hex: <$1> str: $2" % [stringToHex(utf8Char), utf8Char]
      return false

    if codePoint != eCodePoints[ix]:
      echo "$1[u$2]" % [str, $ix]
      echo "expected code point: " & $eCodePoints[ix]
      echo "     got code point: " & $codePoint
      return false
    inc(ix)

  return true

suite "utf8decoder.nim":

  test "yieldUtf8Char":
    check testYieldUtf8Char("", newSeq[string](), newSeq[uint32](), newSeq[bool]())
    check testYieldUtf8Char("a", @["a"], @[97u32], @[true])
    check testYieldUtf8Char("ab", @["a", "b"], @[97u32, 98], @[true, true])
    check testYieldUtf8Char("abc", @["a", "b", "c"], @[97u32, 98, 99], @[true, true, true])

    check testYieldUtf8Char("\xC2\xA9", @["\xC2\xA9"], @[0xA9u32], @[true])
    check testYieldUtf8Char("\xE2\x80\x90", @["\xE2\x80\x90"], @[0x2010u32], @[true])

    check testYieldUtf8Char("\xE2\x80\x90ab\xC2\xA9",
      @["\xE2\x80\x90", "a", "b", "\xC2\xA9"],
      @[0x2010u32, 97, 98, 0xA9],
      @[true, true, true, true])

    check testYieldUtf8Char("\xff", @["\xff"], @[0u32], @[false])
    check testYieldUtf8Char("a\xffb",
                            @["a", "\xff", "b"],
                            @[97u32, 0, 98],
                            @[true, false, true])

    # Invalid four byte sequence <f1 80 80 C0>.
    check testYieldUtf8Char("\xF1\x80\x80\xC0",
                            @["\xF1\x80\x80", "\xC0"],
                            @[0u32, 0],
                            @[false, false])

    check testYieldUtf8Char("a\xff\xF1\x80\x80\xC0",
                            @["a", "\xff", "\xF1\x80\x80", "\xC0"],
                            @[97u32, 0, 0, 0],
                            @[true, false, false, false])

    check testYieldUtf8Char("a\xff\xF1\x80\x80\xC0\xC2\xA9",
                            @["a", "\xff", "\xF1\x80\x80", "\xC0", "\xC2\xA9"],
                            @[97u32, 0, 0, 0, 169],
                            @[true, false, false, false, true])

    check testYieldUtf8Char("\xf0\x31\xf1\x32",
      @["\xf0", "1", "\xf1", "2"],
      @[0u32, 0x31, 0, 0x32],
      @[false, true, false, true])

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
