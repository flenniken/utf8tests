#!/usr/bin/env perl
use strict;
use warnings;
use Encode;

# Get the command line arguments.
my ($inFilename, $outFilename, $skipOrReplace) = @ARGV;
if (not defined $outFilename) {
  print "Usage writeValidUtf8 inFilename outFilename [skip|replace]\n";
  exit
}
if (not defined $skipOrReplace) {
 $skipOrReplace = "replace"
}
# print "$inFilename\n";
# print "$outFilename\n";
# print "$skipOrReplace\n";

# Read the input file into memory.
my $content;
open(my $fh, '<', $inFilename) or die "Unable to open the input file: '$inFilename'.\n";
{
  local $/;
  $content = <$fh>;
}
close($fh);
#print "$content\n";

# Decode the content as UTF-8.
my $utf8string;
if ($skipOrReplace eq "replace") {
  $utf8string = decode('UTF-8', $content);
} else {
  print "Skip currently not supported.\n";
  exit
  # Seems like you could use FB_QUIET to implement skip.
  # my($buffer, $string) = ("", "");
  # while (read($fh, $buffer, 256, length($buffer))) {
  #     $string .= decode($encoding, $buffer, Encode::FB_QUIET);
  #     # $buffer now contains the unprocessed partial character
  # }
}
#print "$utf8string\n";

# Write the UTF-8 string to the output file.
use open ':std', ':encoding(UTF-8)';
open(FH, '>', $outFilename) or die $!;
print FH $utf8string;
