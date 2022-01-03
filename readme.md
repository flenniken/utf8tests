# Utf8tests

The utf8test.txt file in this project contains test cases for UTF-8
decoders and validators.  You "compile" the file to generate the file
utf8test.bin used for testing.

## UTF-8 General Information

Important UTF-8 facts for testing:

* Code points must be in the range U+0000 to U+10FFFF.
* A UTF-8 code point is encoded with 1 to 4 bytes.
* One byte UTF-8 characters are ASCII characters, 0 - 7f.
* The surrogate characters are not valid in UTF-8.

## Bit Patterns

Bit patterns for 1 to 4 byte UTF-8 code point sequences:

~~~
0xxxxxxx
110xxxxx 10xxxxxx
1110xxxx 10xxxxxx 10xxxxxx
11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
~~~

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

## Invalid Byte Sequences

Some byte sequences are invalid. It's common practice to replace
invalid bytes sequences with with the Unicode replacement character
U+FFFD, &lt;EF BF BD&gt;.

Following best practices you replace "Maximal Subpart" runs of invalid
byte sequences with one replacement character, not every invalid
byte. See page 126, section 3.9 of:

* [Unicode 14.0](https://www.unicode.org/versions/Unicode14.0.0/ch03.pdf) -- Unicode 14.0 Specification

## Other UTF-8 Information

Wikipedia has a good explanation of UTF-8:

* [Wikipedia UTF-8](https://en.wikipedia.org/wiki/UTF-8) -- UTF-8 is a variable-width character encoding used for electronic communication...

You can look up unicode characters by code point:

* [Unicode Charts](https://unicode.org/charts/) -- Unicode 14.0 Character Code Charts

You can convert from code point to UTF-8 hex byte sequences and
visa-versa using an online app:

* [Code Point <-> UTF-8 byte sequence](https://www.cogsci.ed.ac.uk/~richard/utf-8.cgi) -- Online UTF-8 converter

Many test cases in utf8tests.txt were inspired by Markus Kuhn tests. See:

* [Markus Kuhn UTF-8 Tests](https://www.cl.cam.ac.uk/~mgk25/ucs/examples/UTF-8-test.txt) -- UTF-8 decoder capability and stress test

## Test Your Decoder

You can run the utf8tests.bin file through your decoder then check its
output against the expected output shown in the utf8test.txt file. You
can do this automatically by passing your file to utf8tests command
line app.

For the example, using the iconv command line app you can decode the
utf8tests.bin file producing the file utf8.skip.icon.txt.

~~~
iconv -c -f UTF-8 -t UTF-8 utf8tests.bin >utf8.skip.icon.txt
~~~

You pass the resulting file to utf8tests and it checks each test line and
reports the tests that fail.

In my version of iconv, it allows values bigger than the maximum and
it allows surrogates. Here is a sample of the output:

~~~
bin/utf8tests -e=utf8tests.txt --skip=utf8.skip.icon.txt

6.0: test case: f7 bf bf bf
6.0:  expected: nothing
6.0:       got: f7 bf bf bf

6.1: test case: f8 88 80 80 80
6.1:  expected: nothing
6.1:       got: f8 88 80 80 80

6.2: test case: f7 bf bf bf bf
6.2:  expected: nothing
6.2:       got: f7 bf bf bf
...
~~~

The utf8tests.txt file has comments telling what the test does. Here
is the 6.0 test:

~~~
# too big
# too big U+001FFFFF, <F7 BF BF BF>
6.0:invalid hex:F7 BF BF BF:nothing:EFBFBD  EFBFBD  EFBFBD  EFBFBD
~~~

My version of iconv is very old but it is the current version on an
up-to-date mac.

~~~
iconv --version
iconv (GNU libiconv 1.11)
Copyright (C) 2000-2006 Free Software Foundation, Inc.
~~~

## Reference Decoder

I ported Bjoern Hoehrmann's decoder to Nim and that is the reference
code in the unicodes.nim file in this project.

* [Bjoern Hoehrmann Decoder](http://bjoern.hoehrmann.de/utf-8/decoder/dfa/)

## UTF-8 Finite State Machine

I created a state diagram for UTF-8. I started from the standard
diagram created by Bjoern Hoehrmann and then added the error state. I
then edited the resulting svg file in inkscape adding a legend and
tweeking it in a text editor.

* [Finite State Machine Editor](http://madebyevan.com/fsm/) - simple on-line finite state machine editor
* [Unicode 14.0](https://www.unicode.org/versions/Unicode14.0.0/ch03.pdf) -- See Table 3-7. Well-Formed UTF-8 Byte Sequences


[![UTF-8 Finite State Machine](utf8statemachine.svg)](#utf-8-finite-state-machine)
