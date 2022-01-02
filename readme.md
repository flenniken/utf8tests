# Validate UTF-8

The file utf8test.txt contains test cases for testing UTF-8
decoders and validators.  You "compile" the file to generate
the file utf8test.bin used for testing.

## UTF-8 General Information

The following UTF-8 facts are important for testing:

* Code points must be in the range U+0000 to U+10FFFF.
* A UTF-8 code point is encoded with 1 to 4 bytes.
* Unicode contains all the ASCII characters, 0 - 7f.
* The surrogate characters are not valid in UTF-8.

Bit patterns for 1 to 4 byte UTF-8 code point sequences:

~~~
0xxxxxxx
110xxxxx 10xxxxxx
1110xxxx 10xxxxxx 10xxxxxx
11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
~~~

# Invalid Byte Sequences

Some byte sequences are invalid. It's common practice to replace
invalid bytes sequences with with the Unicode replacement character
U+FFFD, <EF BF BD>.

pg 126, section 3.9

"U+FFFD Substitution of Maximal Subparts"

An increasing number of implementations are adopting the handling of
ill-formed subsequences as specified in the W3C standard for
encoding to achieve consistent U+FFFD replacements. See:

http://www.w3.org/TR/encoding/

Although the Unicode Standard does not require this practice for
conformance, the following text describes this practice and gives
detailed examples.

This definition of the maximal subpart is used in describing how far
to advance processing when making substitutions: always process at
least one code unit, or as many code units as match the beginning of a
well-formed character, up to the point where the next code unit would
make it ill-formed, that is, an offset is reached that does not
continue this partial character.

Binary to hex table:

~~~
0000 0
0001 1
0010 2
0011 3
0100 4
0101 5
0110 6
0111 7
1000 8
1001 9
1010 a
1011 b
1100 c
1101 d
1110 e
1111 f
~~~

# Other UTF-8 Information

Wikipedia has a good explaination of UTF-8:
https://en.wikipedia.org/wiki/UTF-8

You can look up unicode characters by code point:
https://unicode.org/charts/

You can convert from code point to UTF-8 hex byte sequences and
visa-versa using an online app:
https://www.cogsci.ed.ac.uk/~richard/utf-8.cgi

The test cases were inspired by Markus Kuhn and we use many of his test
cases:
https://www.cl.cam.ac.uk/~mgk25/ucs/examples/UTF-8-test.txt

# Test From File

You can run the utf8tests.bin file through your decoder then check it
output against the expected output shown in the utf8test.txt file.

You can do this automatically by passing your file to utf8tester
command line app.

For the example below, iconv will read the utf8tests.bin file and produce the utf8.skip.icon.txt.  You pass that to utf8tester.

~~~
iconv -i -f UTF-8 -t UTF-8 testfiles/utf8tests.bin -o utf8.skip.icon.txt
utf8tester --skip utf8.skip.icon.txt

or

iconv --byte-subst='\xEF\xBF\xBD' -f UTF-8 -t UTF-8 testfiles/utf8tests.bin \
  -o utf8.replace.icon.txt
utf8tester --replace utf8.skip.icon.txt
~~~

