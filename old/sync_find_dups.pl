#!perl -w
use strict;
use warnings;
use 5.010_000;
require 5.010_000;
use feature ':5.10';
use Cwd;
use Sys::Hostname;
#use Number::Format qw(format_bytes);
use Digest::MD5;
use Digest::SHA;
use Carp qw(confess);
use Config;
die 'Cannot guarantee correct handling of large files' if $Config{intsize} < 4;

my $DIGEST_LENGTH_MB = 5;
my $limit = 1; # 1 = md5 of only 5MB, 0 = md5 of entire file
if ($limit) { say "Using up to $DIGEST_LENGTH_MB MB for hash digest generation"; }
else { say "Warning: using complete file for hash generation!"; }
my $DIGEST_LENGTH = $DIGEST_LENGTH_MB *1024*1024;
my $DIGEST_ALGO = 'SHA512';
my $digest = Digest::SHA->new(512);
#my $digest = Digest::MD5->new;


# read csv file
my $file = shift @ARGV;
if (not(-e $file && -r _)) {
    die "File $file isn't readable...";
}
my $time = time;
say 'Starting at ' . scalar localtime();

open my $if, '<', $file or die 'Could not open output file ' . $file . ";" . $!;
die unless <$if> =~ /^CATALOG/;

my %dirs;
my %hashes;

my $curdir;
while (my $line = <$if>) {
    next if $line =~ /^\s*;/o;
    if ($line =~ /^<(.*)>$/o) {
        $curdir = $1;
        if ($curdir eq '') { $curdir = '.'; }
        die 'Duplicate dir: '. $line if $dirs{$curdir}++;
        next;
    }
    if ($line =~ /^(.+)\t(\d+)\t(\d+)\t(\w+)$/) {
        my($file, $modification_time, $size, $hash) = ($1, $2, $3, $4);
        if (defined $hashes{$hash}) { say "Duplicate ".substr($hash,0,8).": $file in $curdir, with $hashes{$hash}"; }
        else { $hashes{$hash} = "$file in $curdir"; }
    } else {
        die 'Incorrect line: ' . $line;
    }
}

my $endtime = time;
say 'Done at ' . localtime() . ', needed ' . ($endtime - $time) . ' seconds.';
