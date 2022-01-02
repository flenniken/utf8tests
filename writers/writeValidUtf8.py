#!/usr/bin/env python3

# Read a binary file and write a utf-8 file.

import sys
import argparse
import os
import unittest

def writeValidUtf8(in_filename, out_filename, skipInvalid):
  """
  Read the input file bytes and write it to the output file as
  UTF-8. When skipInvalid is true, drop the invalid bytes, else
  replace them with U+FFFD.
  """
  # Read the input file into memory as bytes.
  if not os.path.exists(in_filename):
    print("File is missing: %s" % in_filename)
    return 0
  with open(in_filename, "rb") as fh:
    fileData = fh.read()

  # Decode the bytes as utf8 to produce a utf8 string. Drop the
  # invalid bytes.
  if skipInvalid:
    option = 'ignore'
  else:
    option = 'replace'
  string = fileData.decode("utf-8", option)

  # Write the string to the output file.
  with open(out_filename, "w") as fh:
    fh.write(string)

def parse_command_line(argv):
  """
  Parse the command line and return an object that has the
  parameters as attributes.
  """
  # Handle -t or --test because they doesn't require files arguments.
  for arg in argv:
    if arg in ['-t', '--test']:
      return argparse.Namespace(test = True)

  parser = argparse.ArgumentParser(description="""\
Read an input file and write it to a utf8 output file.
""")
  parser.add_argument("-s", "--skipInvalid", action="store_true", default=False,
                       help="skip invalid bytes, else replace them with U+FFFD")
  parser.add_argument("-t", "--test", action="store_true", default=False,
                       help="run unit tests")
  parser.add_argument("in_filename", type=str,
                        help="the input file",
                        default=None)
  parser.add_argument("out_filename", type=str,
                        help="the output file",
                        default=None)
  args = parser.parse_args(argv[1:])
  return args

def create_file(filename, content):
  fh = open(filename, 'wb')
  fh.write(content)
  fh.close()

def hexBytes(byteData):
  return " ".join(["{:02x}".format(x) for x in byteData])

def run_writeValidUtf8(in_bytes, skipInvalid = True):
  """
  Call writeValidUtf8 passing in the given input bytes. Return the
  resulting bytes.
  """
  in_filename = "in_temp.txt"
  create_file(in_filename, in_bytes)

  out_filename = "out_temp.txt"
  writeValidUtf8(in_filename, out_filename, skipInvalid)

  if not os.path.exists(out_filename):
    return "out_filename was not created."

  with open(out_filename, "rb") as fh:
    fileData = fh.read()

  os.remove(in_filename)
  os.remove(out_filename)
  return fileData

def test_writeValidUtf8(in_bytes, expected_bytes, skipInvalid = True):
  """
  Call writeValidUtf8 passing in the given input bytes, then verify the
  result file contains the given expected bytes.
  """
  in_filename = "in_temp.txt"
  create_file(in_filename, in_bytes)

  out_filename = "out_temp.txt"
  writeValidUtf8(in_filename, out_filename, skipInvalid)

  rc = True
  if not os.path.exists(out_filename):
    print("out_filename was not created.")
    rc = False

  with open(out_filename, "rb") as fh:
    fileData = fh.read()

  if fileData != expected_bytes:
    print("     got: %s" % fileData)
    print("     got: %s" % hexBytes(fileData))
    print("expected: %s" % hexBytes(expected_bytes))
    rc = False

  os.remove(in_filename)
  os.remove(out_filename)
  return rc

class TestWriteValidUtf8(unittest.TestCase):
  def test_me(self):
    self.assertEqual(1, 1)

  def test_writing_binary(self):
    with open("test.txt", "wb") as fh:
      fh.write(b'\xC2\xA9')
    os.remove("test.txt")

  def assert_got(self, got, expected):
    if got != expected:
      show = """\

     got: %s
     got: %s
expected: %s
""" % (got, hexBytes(got), hexBytes(expected))
      self.assertTrue(0, show)

  def test_writeValidUtf8_abc(self):
    got = run_writeValidUtf8(b"abc")
    self.assert_got(got, b"abc")

  def test_two_byte_char(self):
    # Test two byte character.
    input_bytes = b'\xC2\xA9'
    got = run_writeValidUtf8(input_bytes)
    self.assert_got(got, input_bytes)

  def test_invalid_byte(self):
    # Test invalid byte.
    input_bytes = b'\xff'
    expectedSkip = b''
    expectedReplace = b'\xEF\xBF\xBD'
    got = run_writeValidUtf8(input_bytes, True)
    self.assert_got(got, expectedSkip)
    got = run_writeValidUtf8(input_bytes, False)
    self.assert_got(got, expectedReplace)

  def test_invalid_two_bytes(self):
    input_bytes = b'\xff\xfe'
    expectedSkip = b''
    expectedReplace = b'\xEF\xBF\xBD\xEF\xBF\xBD'
    got = run_writeValidUtf8(input_bytes, True)
    self.assert_got(got, expectedSkip)
    got = run_writeValidUtf8(input_bytes, False)
    self.assert_got(got, expectedReplace)

  def test_invalid_three_bytes(self):
    input_bytes = b'\xff\xfe\xfd'
    expectedSkip = b''
    expectedReplace = b'\xEF\xBF\xBD\xEF\xBF\xBD\xEF\xBF\xBD'
    got = run_writeValidUtf8(input_bytes, True)
    self.assert_got(got, expectedSkip)
    got = run_writeValidUtf8(input_bytes, False)
    self.assert_got(got, expectedReplace)

  def test_invalid_four_bytes(self):
    input_bytes = b'\xff\xfe\xfd\xfe'
    expectedSkip = b''
    expectedReplace = b'\xEF\xBF\xBD\xEF\xBF\xBD\xEF\xBF\xBD\xEF\xBF\xBD'
    got = run_writeValidUtf8(input_bytes, True)
    self.assert_got(got, expectedSkip)
    got = run_writeValidUtf8(input_bytes, False)
    self.assert_got(got, expectedReplace)

  def test_invalid_two_bytes_seq(self):
    input_bytes = b'\xc2\xc0'
    expectedSkip = b''
    expectedReplace = b'\xEF\xBF\xBD\xEF\xBF\xBD'
    got = run_writeValidUtf8(input_bytes, True)
    self.assert_got(got, expectedSkip)
    got = run_writeValidUtf8(input_bytes, False)
    self.assert_got(got, expectedReplace)

  def test_invalid_1(self):
    input_bytes = b'\xc2\x31'
    expectedSkip = b'1'
    expectedReplace = b'\xEF\xBF\xBD1'
    got = run_writeValidUtf8(input_bytes, True)
    self.assert_got(got, expectedSkip)
    got = run_writeValidUtf8(input_bytes, False)
    self.assert_got(got, expectedReplace)

  def test_invalid_2(self):
    input_bytes = b'\xe1\x80'
    expectedSkip = b''
    expectedReplace = b'\xEF\xBF\xBD'
    got = run_writeValidUtf8(input_bytes, True)
    self.assert_got(got, expectedSkip)
    got = run_writeValidUtf8(input_bytes, False)
    self.assert_got(got, expectedReplace)

  def test_invalid_3(self):
    input_bytes = b'\xf4\x80\x80'
    expectedSkip = b''
    expectedReplace = b'\xEF\xBF\xBD'
    got = run_writeValidUtf8(input_bytes, True)
    self.assert_got(got, expectedSkip)
    got = run_writeValidUtf8(input_bytes, False)
    self.assert_got(got, expectedReplace)

  def test_invalid_f0(self):
    input_bytes = b'\xf0\x8f'
    expectedSkip = b''
    expectedReplace = b'\xEF\xBF\xBD\xEF\xBF\xBD'
    got = run_writeValidUtf8(input_bytes, True)
    self.assert_got(got, expectedSkip)
    got = run_writeValidUtf8(input_bytes, False)
    self.assert_got(got, expectedReplace)

  def test_invalid_f0_2(self):
    input_bytes = b'\xf0\x90\xc0'
    expectedSkip = b''
    expectedReplace = b'\xEF\xBF\xBD\xEF\xBF\xBD'
    got = run_writeValidUtf8(input_bytes, True)
    self.assert_got(got, expectedSkip)
    got = run_writeValidUtf8(input_bytes, False)
    self.assert_got(got, expectedReplace)

if __name__ == "__main__":
  if sys.version_info < (3, 0):
    print("This program requires python 3 or above.")
    sys.exit(1)

  args = parse_command_line(sys.argv)
  if args.test:
    sys.argv = sys.argv[1:]
    unittest.main()
  else:
    writeValidUtf8(args.in_filename, args.out_filename, args.skipInvalid)
