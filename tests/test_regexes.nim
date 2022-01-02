import std/unittest
import std/options
import std/strutils
import regexes

proc expectedItem[T](name: string, item: T, expectedItem: T): bool =
  ## Compare the item with the expected item and show them when
  ## different. Return true when they are the same.

  if item == expectedItem:
    result = true
  else:
    echo name
    echo "     got: $1" % $item
    echo "expected: $1" % $expectedItem
    result = false

proc testMatchPattern(str: string, pattern: string, start: Natural = 0,
    eMatchesO: Option[Matches] = none(Matches)): bool =
  ## Test matchPattern
  let matchesO = matchPattern(str, pattern, start)
  var header = """
line: "$1"
start: $2
pattern: $3""" % [str, $start, pattern]
  if not expectedItem(header, matchesO, eMatchesO):
    result = false
    echo ""
  else:
    result = true

suite "regexes.nim":
  test "no groups":
    let pattern = r"^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$"
    check testMatchPattern("0.1.0", pattern, 0, some(newMatches(5, 0)))
    check testMatchPattern("0.12.345", pattern, 0, some(newMatches(8, 0)))
    check testMatchPattern("999.888.777", pattern, 0, some(newMatches(11, 0)))

  test "no match":
    let pattern = r"^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$"
    check testMatchPattern("0.1", pattern, 0)
    check testMatchPattern("0.1.3456", pattern, 0)
    check testMatchPattern("0.1.a", pattern, 0)

  test "one simple match":
    let pattern = r".*abc$"
    check testMatchPattern("123 abc", pattern, 0, some(newMatches(7, 0)))

  test "no match":
    let pattern = r"^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$"
    check testMatchPattern("b.67.8", pattern)

  test "one group":
    let pattern = r"^.*(def)$"
    let matchesO = matchPattern("  abc asdfasdfdef def", pattern, 0)
    check matchesO.isSome
    let one = matchesO.get().getGroups(1)
    check one[0] == "def"

  test "two groups":
    let pattern = r"(abc).*(def)$"
    check testMatchPattern("  abc asdfasdfdef def", pattern, 2, some(newMatches(19, 2, "abc", "def")))

    let matchesO = matchPattern("  abc asdfasdfdef def", pattern, 2)
    check matchesO.isSome
    let groups = matchesO.get().getGroups(2)
    check groups[0] == "abc"
    check groups[1] == "def"

  test "three groups":
    let pattern = r"^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$"
    check testMatchPattern("999.888.777", pattern, 0, some(newMatches(11, 0, "999", "888", "777")))
    check testMatchPattern("5.67.8", pattern, 0, some(newMatches(6, 0, "5", "67", "8")))
    let matchesO = matchPattern("5.67.8", pattern, 0)
    check matchesO.isSome
    let groups = matchesO.get().getGroups(3)
    check groups[0] == "5"
    check groups[1] == "67"
    check groups[2] == "8"

  test "getGroups":
    let pattern = r"^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$"
    check testMatchPattern("999.888.777", pattern, 0, some(newMatches(11, 0, "999", "888", "777")))
    check testMatchPattern("5.67.8", pattern, 0, some(newMatches(6, 0, "5", "67", "8")))
    let matchesO = matchPattern("5.67.8", pattern, 0)
    check matchesO.isSome

    var groups = matchesO.get().getGroups(0)
    check groups.len == 0

    groups = matchesO.get().getGroups(1)
    check groups.len == 1
    check groups[0] == "5"

    groups = matchesO.get().getGroups(2)
    check groups.len == 2
    check groups[0] == "5"
    check groups[1] == "67"

    groups = matchesO.get().getGroups(3)
    check groups.len == 3
    check groups[0] == "5"
    check groups[1] == "67"
    check groups[2] == "8"

    groups = matchesO.get().getGroups(4)
    check groups.len == 4
    check groups[0] == "5"
    check groups[1] == "67"
    check groups[2] == "8"
    check groups[3] == ""

  test "start not zero":
    # Using ^ to anchor doesn't work as I expect when start is not 0.
    # let matcher = newMatcher(r"^(abc)", 1)

    let pattern = r"(abc)"
    check testMatchPattern("  abc asdfasdfdef def", pattern, 2, some(newMatches(3, 2, "abc")))

  test "matchPattern":
    let pattern = r".*ll(o)(testing)*"
    check testMatchPattern("hellotesting", pattern, 0, some(newMatches(12, 0, "o", "testing")))

  test "matchPattern one match":
    check testMatchPattern("nomatch", ".*match", 0, some(newMatches(7, 0)))

  test "matchPattern one group":
    check testMatchPattern("nomatch", ".*(match)", 0, some(newMatches(7, 0, "match")))

  test "matchPattern two groups":
    check testMatchPattern("yesmatch", "(yes)(match)", 0, some(newMatches(8, 0, "yes", "match")))

  test "matchPattern 10 groups":
    let eMatchesO = some(newMatches(10, 0, "y", "e", "s", "m", "a", "t", "c", "h", "e", "s"))
    check testMatchPattern("yesmatches", "(y)(e)(s)(m)(a)(t)(c)(h)(e)(s)", 0, eMatchesO)

  test "matchPattern length":
    check testMatchPattern("   match = ", ".*(match) =", 0, some(newMatches(10, 0, "match")))

  test "matchPattern start":
    check testMatchPattern("   match = ", ".*(match) =", 3, some(newMatches(7, 3, "match")))

  test "matchPattern anchor":
    check testMatchPattern("match = asdf", "^match", 0, some(newMatches(5, 0)))

  test "matchPattern start anchor":
    # This doesn't match because nim sets the anchor option.
    check testMatchPattern(" match = asdf", "^match", 1)

  test "matchPattern no match":
    check testMatchPattern("nomatch", "he(ll)o")
    check testMatchPattern("hellotesting", "ll(o8)(testing)*")
    check testMatchPattern("nomatch", ".*match3")
    check testMatchPattern("nomattchtjj", ".*match")
    check testMatchPattern("nomatch", ".*(match) ")
    check testMatchPattern("yesmatch", "(yes)7(match)")
    check testMatchPattern("yesmatches", "(y)(s)(m)(a)(t)(c)(h)(e)(s)")
    check testMatchPattern("   match = ", "(match) =")
    check testMatchPattern("   match = ", "(match) 7", 3)
    check testMatchPattern(" match = asdf", "^match")

  test "matchPattern exception":
    # The pattern has unmatched parentheses which generates an
    # expection in the compilePattern method.
    let pattern = r"^----------file: ([^\s]*)\s(\([^)]\)\s*$"
    let matchesO = matchPattern("line", pattern, 0)
    check matchesO.isSome == false
