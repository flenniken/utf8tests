# Validate UTF-8

The file utf8test.txt contains test cases for testing UTF-8
decoders and validators.  You "compile" the file to generate
the file utf8test.bin used for testing.

## About the File Format 

This file is line oriented. Blank lines or lines that start
with a # are comments that are skipped.

The other lines test valid UTF-8 byte sequences or invalid byte
sequences.  A test line starts with a unique number.

For the valid test cases you specify the test case text. The
test code checks that the output matches the text case. You can
specify the test case as normal text or using hex. Examples:

1.9.3:valid:this is test text
1.9.6: valid hex: 45 6a 31

The replacment character is U+FFFD <EFBFBD>.

For the invalid test cases you specify the test case and the expected
output in two forms, one when skipping invalid bytes and one when
replacing invalid bytes. The comment lines before the test line tell
what you are testing.

Examples:

~~~
# Too big U+001FFFFF, <F7 BF BF BF>
6.0: invalid: F7 BF BF BF : nothing : EFBFBD EFBFBD EFBFBD EFBFBD
~~~

When the output does not match the expected values you will see
messages similar to this:

~~~
6.0: invalid: F7 BF BF BF
6.0:   skip expected: nothing
6.0:   skip      got: F7 BF BF BF
6.0:   replace expected: EFBFBD  EFBFBD  EFBFBD  EFBFBD
6.0:   replace      got: F7 BF BF BF
~~~

Line types:

* # <comment line>
* <blank line>
* num:valid:string
* num:valid hex:hexString
* num:invalid:hexString:hexString2:hexString3

* hexString2 is the expected value when skipping invalid bytes.
* hexString2 is the expected value when replacing invalid bytes with U+FFFD <EFBFBD>.

## UTF-8 Axioms and General Information

The following UTF-8 facts are important for testing:

* Code points must be in the range U+0000 to U+10FFFF (1,114,111).
* A UTF-8 code point is encoded with 1 to 4 bytes.
* The first UTF-8 characters are ascii, 0 - 7f.

Bit patterns for 1 - 4 byte UTF-8 code points:

~~~
0xxxxxxx
110xxxxx 10xxxxxx
1110xxxx 10xxxxxx 10xxxxxx
11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
~~~

It's common practice to replace invalid bytes with U+FFFD. You
replace the first invalid byte then restart at the next byte
and repeat if necessary.

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

