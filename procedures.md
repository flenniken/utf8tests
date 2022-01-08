# Procedures

This page tells how to reproduce the results shown in the readme's
table for the code that fails. It also tells what failed and why it
failed.

# Emacs 25.3.1

Test the emacs text editor.

## What failed?

* Invalid UTF-8 byte sequences are written to a file when saving as
  utf-8.

## Why it Failed?

The [Unicode
Specification](https://www.unicode.org/versions/Unicode14.0.0/ch03.pdf)
says you must not write ill-formed byte sequences.

Conformance, page 80, section 3.2:

~~~
C9
When a process generates a code unit sequence which purports to be
in a Unicode character encoding form, it shall not emit ill-formed
code unit sequences.

The definition of each Unicode character encoding form specifies the
ill-formed code unit sequences in the character encoding form. For
example, the definition of UTF-8 (D92) specifies that code unit
sequences such as <C0 AF> are ill-formed.
~~~

Conformance page 125, section 3.9:

~~~
A conformant encoding form conversion will treat any ill-formed code
unit sequence as an error condition. (See conformance clause C10.)
This guarantees that it will neither interpret nor emit an ill-formed
code unit sequence. Any implementation of encoding form conversion
must take this requirement into account, because an encoding form
conversion implicitly involves a verification that the Unicode strings
being converted do, in fact, contain well-formed code unit sequences.
~~~

## Version Tested

Emacs 27.2 is the current version as of this writing. Maybe it is
fixed in a new version?

~~~
GNU Emacs 25.3.1 (x86_64-apple-darwin16.7.0,
  NS appkit-1504.83 Version 10.12.6 (Build 16G29)) of 2017-10-08
~~~

## Steps to Reproduce

* open a terminal, copy the test file and open the copy:

~~~
cp utf8tests.bin artifacts/utf8.skip.emacs.25.3.1.txt
emacs -nw artifacts/utf8.skip.emacs.25.3.1.txt
~~~

* Switch to UTF-8: M-x revert-buffer-with-coding-system RET utf-8 RET yes RET
* Add line at the top of the file: "# edited in emacs"
* Scroll down to the 36 tests.

The 36 lines are shown below. The invalid characters appear as octal
numbers. Emacs does not skip or replace the invalid character with the
replacement characters. This is consistent how it treats invalid
characters in other encodings. It is handy to see invalid bytes this way.

If you save the file without changes, the file is unchanged.

~~~
36.1:valid:replacement character=�=�.
36.2:invalid:�=\377.
36.3:invalid:��=\340\200.
36.4:invalid:���=\360\200\200.
36.5:invalid:����=\360\200\200\200.
36.6:invalid:����=\340\200\340\200.
36.7:invalid:����=\x1FFFFF.
36.8:invalid:���=\355\240\200.
36.9:valid:￿=￿.
36.9.1:valid:￾=￾.
36.10:invalid:���=\340\200\257.
~~~

* Save the file as UTF-8 and exit: C-x C-c, y, utf-8
* Check that all the valid type tests passed.  No output means they all passed:

~~~
bin/utf8tests -e=utf8tests.txt -r=utf8.replace.emacs.25.3.1.txt | grep " valid"
~~~

* Check all the test results:

Emacs leaves the invalid UTF-8 byte sequences in the file unchanged.

~~~
bin/utf8tests -e=utf8tests.txt -s=utf8.replace.emacs.25.3.1.txt | less
~~~

An example case:

~~~
22.2: invalid test case: c0 af
22.2:          expected: nothing
22.2:               got: c0 af
~~~

## Commentary

It is nice that emacs shows the invalid byte sequences in their
original form when you open the file and that saving without editing
does not change it. The problem is that saving as UTF-8 always writes
the invalid sequences. Would it conform if it asked the user what to
do when saving with a prompt: leave, remove, or replace?

# Iconv 1.11:

## Version Tested

This is an old version maybe it is fixed in a new version?

~~~
iconv --version
iconv (GNU libiconv 1.11)
Copyright (C) 2000-2006 Free Software Foundation, Inc.
This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
Written by Bruno Haible.
~~~

## What failed?

* Iconv 1.11 allows characters over U+10FFFF.
* Iconv 1.11 allows surrogates.

## Steps to Reproduce

See the procedure writeValidUtf8FileIconv in the
writevalidutf8file.nim file in this project.

# Nim 1.4.8:

## Version Tested

~~~
nim --version
Nim Compiler Version 1.4.8 [MacOSX: amd64]
Compiled at 2021-05-25
Copyright (c) 2006-2021 by Andreas Rumpf

git hash: 44e653a9314e1b8503f0fa4a8a34c3380b26fff3
active boot switches: -d:release -d:danger
~~~

## What Failed?

* Nim 1.4.8 allows characters over U+10FFFF.
* Nim 1.4.8 allows surrogates.
* Nim 1.4.8 allows over long sequences.

## Steps to Reproduce

See the procedure writeValidUtf8FileNim in the
writevalidutf8file.nim file in this project.

# Perl 5.30.2:

## What Failed?

* Perl 5.30.2 changes internal use characters to the replacement character.
* Perl 5.30.2 replaces invalid sequence runs with one replacement
  character.

## Why it Failed?

My interpertation of the specification is that it is invalid to
replace noncharacters with the replacement character then Perl encodes
text since the text could be for internal use.

I don't understand when it is ever appropriate to replace with the
replacement character even though it says that is best practices.

Special Areas and Format Characters, page 924, section 23.7 Noncharacters

~~~
Applications are free to use any of these noncharacter code points
internally. They have no standard interpretation when exchanged
outside the context of internal use. However, they are not illegal in
interchange, nor does their presence cause Unicode text to be
ill-formed.  The intent of noncharacters is that they are permanently
prohibited from being assigned interchangeable meanings by the Unicode
Standard. They are not prohibited from occurring in valid Unicode
strings which happen to be interchanged. This distinction, which might
be seen as too finely drawn, ensures that noncharacters are correctly
preserved when “interchanged” internally, as when used in strings in
APIs, in other interprocess protocols, or when stored.

If a noncharacter is received in open interchange, an application is
not required to interpret it in any way. It is good practice,
however, to recognize it as a noncharacter and to take appropriate
action, such as replacing it with U+FFFD replacement character, to
indicate the problem in the text. It is not recommended to simply
delete noncharacter code points from such text, because of the
potential security issues caused by deleting uninterpreted
characters. (See conformance clause C7 in Section 3.2, Conformance
Requirements, and Unicode Technical Report #36, “Unicode Security
Considerations.”)
~~~

It is cool to replace runs of invalid characters with one replacement
character and it does conform to the rules.  However, it is
inconsitent with the current best paractices being promoted by the w2c
and documented in the Unicode Specification.

## Steps to Reproduce

See the procedure writeValidUtf8FilePerl in the
writevalidutf8file.nim file in this project.
