# Procedures

This page tells how to reproduce the results shown in the readme's
table for the code that fails and for the browser tests. It also tells
what failed and why it failed.

* [Chrome 97.0.4692.71](#chrome-970469271) &mdash; Chrome
* [Emacs 25.3.1](#emacs-2531) &mdash; Emacs
* [Iconv 1.11](#iconv-111) &mdash; Iconv
* [Firefox 95.0.2](#firefox-9502) &mdash; Firefox
* [Less 487](#less-487) &mdash; Less
* [Nano 2.0.6](#nano-206) &mdash; Nano
* [Nim 1.4.8](#nim-148) &mdash; Nim
* [Perl 5.30.2](#perl-5302) &mdash; Perl
* [Safari 14.1.2](#safari-1412) &mdash; Safari
* [Textedit 1.16](#textedit-116) &mdash; Textedit
* [Vim 8.2.2029](#vim-822029) &mdash; Vim

# Chrome 97.0.4692.71

* Launch chrome
* Open utf8tests.html: File > Open File...
* scroll down to the 36.x tests.

The 36 tests look as expected:
~~~
36.1:valid:replacement character=�=�.
36.2:invalid:�=�.
36.3:invalid:��=��.
36.4:invalid:���=���.
36.5:invalid:����=����.
36.6:invalid:����=����.
36.7:invalid:����=����.
36.8:invalid:���=���.
36.10:invalid:���=���.
36.9:valid:￿=￿.
36.9.1:valid:￾=￾.
~~~

# Emacs 25.3.1

Test the emacs text editor.

__What failed?__

* Invalid UTF-8 byte sequences are written to a file when saving as
  utf-8.

__Why it Failed?__

The [Unicode
Specification](https://www.unicode.org/versions/Unicode14.0.0/ch03.pdf)
says you must not write ill-formed byte sequences.

Conformance, page 80, section 3.2:

   >C9
   >When a process generates a code unit sequence which purports to be
in a Unicode character encoding form, it shall not emit ill-formed
code unit sequences.

Conformance page 125, section 3.9:

   >A conformant encoding form conversion will treat any ill-formed code
unit sequence as an error condition. (See conformance clause C10.)
This guarantees that it will neither interpret nor emit an ill-formed
code unit sequence. Any implementation of encoding form conversion
must take this requirement into account, because an encoding form
conversion implicitly involves a verification that the Unicode strings
being converted do, in fact, contain well-formed code unit sequences.

__Version Tested__

Emacs 27.2 is the current version as of this writing. Maybe it is
fixed in a new version?

~~~
GNU Emacs 25.3.1 (x86_64-apple-darwin16.7.0,
  NS appkit-1504.83 Version 10.12.6 (Build 16G29)) of 2017-10-08
~~~

__Steps to Reproduce__

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

__Commentary__

It is nice that emacs shows the invalid byte sequences in their
original form when you open the file and that saving without editing
does not change it. The problem is that saving as UTF-8 always writes
the invalid sequences. Would it conform if it asked the user what to
do when saving with a prompt: leave, remove, or replace?

# Iconv 1.11:

__Version Tested__

This is an old version maybe it is fixed in a new version?

~~~
iconv --version
iconv (GNU libiconv 1.11)
Copyright (C) 2000-2006 Free Software Foundation, Inc.
This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
Written by Bruno Haible.
~~~

__What failed?__

* Iconv 1.11 allows characters over U+10FFFF.
* Iconv 1.11 allows surrogates.

__Steps to Reproduce__

See the procedure writeValidUtf8FileIconv in the
writevalidutf8file.nim file in this project.

# Firefox 95.0.2

* launch Firefox
* open utf8tests.html: File > Open File...
* scroll down to the 36.x tests.

The 36 tests look as expected:
~~~
36.1:valid:replacement character=�=�.
36.2:invalid:�=�.
36.3:invalid:��=��.
36.4:invalid:���=���.
36.5:invalid:����=����.
36.6:invalid:����=����.
36.7:invalid:����=����.
36.8:invalid:���=���.
36.10:invalid:���=���.
36.9:valid:￿=￿.
36.9.1:valid:￾=￾.
~~~

# Less 487

Less is a file viewer for the command line.

__Version Tested__

```
less --version

less 487 (POSIX regular expressions)
Copyright (C) 1984-2016  Mark Nudelman

less comes with NO WARRANTY, to the extent permitted by law.
For information about the terms of redistribution,
see the file named README in the less distribution.
Homepage: http://www.greenwoodsoftware.com/less
```

__Visual Tests__

Since Less does not write files we can only evaluate its UTF-8
handling visually. It detects the invalid sequences and shows them a
few different ways, so it passes.

~~~
36.1:valid:replacement character=�=�.
36.2:invalid:�=<FF>.
36.3:invalid:��=<E0><80>.
36.4:invalid:���=<F0><80><80>.
36.5:invalid:����=<F0><80><80><80>.
36.6:invalid:����=<E0><80><E0><80>.
36.7:invalid:����=????.
36.8:invalid:���=<U+D800>.
36.10:invalid:���=<E0><80><AF>.
36.9:valid:￿=￿.
36.9.1:valid:￾=￾.
~~~

# Nano 2.0.6

Nano is a command line text editor.

__Version Tested__

```
nano --version
 GNU nano version 2.0.6 (compiled 22:22:48, Sep  5 2021)
 Email: nano@nano-editor.org	Web: http://www.nano-editor.org/
 Compiled options: --disable-nls --enable-color --enable-extra --enable-multibuffer --enable-nanorc --enable-utf8
```

__Steps to Reproduce__

Open the artifact file, add "# edited in nano" to the top of the file
then save it:

~~~
cp utf8tests.bin artifacts/utf8.replace.nano.2.0.6.txt
nano artifacts/utf8.replace.nano.2.0.6.txt
# edited in nano
ctrl-x
~~~

Evaluate the artifact:

~~~
bin/utf8tests -e=utf8tests.txt -r=artifacts/utf8.replace.nano.2.0.6.txt | less
~~~

__What failed?__

* nano writes invalid byte sequences to the file and leaves most of
  the invalid bytes unchanged

__Visual Tests__

Here are the visual tests:

~~~
36.1:valid:replacement character=�=�.
36.2:invalid:�=�.
36.3:invalid:��= �.
36.4:invalid:���=���.
36.5:invalid:����=����.
36.6:invalid:����= � �.
36.7:invalid:����=����.
36.8:invalid:���=���.
36.10:invalid:���= ��.
36.9:valid:�=�.
36.9.1:valid:�=�.
~~~

# Nim 1.4.8:

__Version Tested__

~~~
nim --version
Nim Compiler Version 1.4.8 [MacOSX: amd64]
Compiled at 2021-05-25
Copyright (c) 2006-2021 by Andreas Rumpf

git hash: 44e653a9314e1b8503f0fa4a8a34c3380b26fff3
active boot switches: -d:release -d:danger
~~~

__What Failed?__

* Nim 1.4.8 allows characters over U+10FFFF.
* Nim 1.4.8 allows surrogates.
* Nim 1.4.8 allows over long sequences.

__Steps to Reproduce__

See the procedure writeValidUtf8FileNim in the
writevalidutf8file.nim file in this project.

See Nim Issue:

https://github.com/nim-lang/Nim/issues/19333

# Perl 5.30.2:

__What Failed?__

* Perl 5.30.2 changes internal use characters to the replacement character.
* Perl 5.30.2 replaces some invalid sequence inconsistent with current best practices.

__Why it Failed?__

It is invalid to replace noncharacters with the replacement character
when Perl encodes text since the text could be for internal use and
stored.

Perl conforms how it replaces invalid byte sequences, but it is
inconsistent with current best practices.  See the readme section
"Invalid Byte Sequences" for more information.

__Steps to Reproduce__

See the procedure writeValidUtf8FilePerl in the writevalidutf8file.nim
file in this project and the "Perl tests" section in
test_writevalidutf8file.nim.

Perl issue:
* [Perl Encode](https://github.com/dankogai/p5-encode/issues/156) &mdash; Perl encode issue 156.


# Safari 14.1.2

* Launch safari: Version 14.1.2 (16611.3.10.1.6)
* On utf8tests.html: File > File Open...
* scroll down to the 36.x tests.

The 36 tests look as expected:

~~~
36.1:valid:replacement character=�=�.
36.2:invalid:�=�.
36.3:invalid:��=��.
36.4:invalid:���=���.
36.5:invalid:����=����.
36.6:invalid:����=����.
36.7:invalid:����=����.
36.8:invalid:���=���.
36.10:invalid:���=���.
36.9:valid:￿=￿.
36.9.1:valid:￾=￾.
~~~


# Textedit 1.16

Textedit is a GUI file editor on the mac.

__Version Tested__

~~~
Version 1.16 (365.2)
~~~

Testedit application doesn't open the utf8test.bin file as UTF-8.  It
shows the error message:

~~~
The document “utf8tests.bin” could not be opened. Text encoding
Unicode (UTF-8) isn’t applicable.
~~~

# Vim 8.2.2029

Vim is a command line text editor.

Vim version:

```
vim --version
VIM - Vi IMproved 8.2 (2019 Dec 12, compiled Sep  6 2021 01:30:12)
macOS version
Included patches: 1-2029
Compiled by root@apple.com
Normal version without GUI.
...

```

__Steps to Reproduce__

In your .vimrc, add "set encoding=utf-8":

```
vim ~/.vimrc
set encoding=utf-8
:wq
```

Make the vim artifact file.  Copy of the utf8test.bin file then edit the copy.   Run some encoding commands, add "# edited in vim" to the top of the file, then save the artifact file:

```
cp utf8tests.bin artifacts/utf8.replace.vim8.2.2029.txt
vim artifacts/utf8.replace.vim8.2.2029.txt
:e ++enc=utf-8
:set fileencoding=utf-8
# edited in vim
:wq!
```

Evaluate the artifact just created:

```
bin/utf8tests -e=utf8tests.txt -s=artifacts/utf8.replace.vim8.2.2029.txt | less
```

__What Failed?__

* vim allows too big characters
* vim allows surrogate characters
* vim allows overlong sequences
* vim replaces invalid bytes with ? (3f)

__Visual Tests__

The visual tests:

~~~
36.1:valid:replacement character=�=�.
36.2:invalid:�=?.
36.3:invalid:��=??.
36.4:invalid:���=???.
36.5:invalid:����=<00>.
36.6:invalid:����=????.
36.7:invalid:����=????.
36.8:invalid:���=<d800>.
36.10:invalid:���=/.
36.9:valid:<ffff>=<ffff>.
36.9.1:valid:<fffe>=<fffe>.
~~~
