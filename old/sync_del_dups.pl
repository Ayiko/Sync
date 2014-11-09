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



# CATALOG v2
# ; Starting at Mon Oct 20 18:15:47 2014
# ;** CWD: /DataVolume/shares/Public
# ;** HOST: StrobiCloud
# ;** STARTED: 1413821747
# ;** HASH_ALGO: SHA512
# ;** HASH_LENGTH: 5 MB
# ; file	modification_time	size	hash


# read csv file
my $file = shift @ARGV;
if (not(-e $file && -r _)) {
    die "File $file isn't readable...";
}
my $time = time;
say 'Starting at ' . scalar localtime();

open my $if, '<', $file or die 'Could not open output file ' . $file . ";" . $!;
die 'Incorrect source file' unless <$if> =~ /^CATALOG v2/;

# read header to set first config values
my %opts;
while (my $line = <$if>) {
    if ($line =~ /^\s*;\*\* (\w+): (.+)\s*$/) {
        $opts{$1} = $2;
    }
    else { last if $line =~ /\s*;\s*file\s+modification_time\s+size/; }
}

my $DIGEST_LENGTH_MB;
my $limit;
if ($opts{'HASH_LENGTH'} =~ /^(\d+) *MB/) {
    $DIGEST_LENGTH_MB = $1;
    $limit = 1;
} else {
    $limit = 0;
    $DIGEST_LENGTH_MB = 0;
}
my $DIGEST_LENGTH = $DIGEST_LENGTH_MB *1024*1024;
my $DIGEST_ALGO = 'SHA512';
my $digest;

if ($opts{'HASH_ALGO'} =~ /^SHA(\d+)$/) { $digest = Digest::SHA->new($1); }
elsif ($opts{'HASH_ALGO'} eq 'MD5') { $digest = Digest::MD5->new(); }
elsif ($opts{'HASH_ALGO'} eq 'MD4') { $digest = Digest::MD4->new(); }
else { die 'unknown hash algorithm' }

my %dirs;
my %hashes;

# read rest of file
my $curdir;
while (my $line = <$if>) {
    if ($line =~ /^<(.*)>$/o) {
        $curdir = $1;
        die 'Duplicate dir: '. $line if $dirs{$curdir}++;
    }
    elsif ($line =~ /^\s*;\*\* (\w+): (.*)$/o) {
        if (defined $opts{$1}) { die "Option $1 already exists, was: <$opts{$1}>, redefined as <$2>"; }
        $opts{$1} = $2;
    }
    elsif ($line =~ /^\s*;/) { next; }
    elsif ($line =~ /^(.+)\t(\d+)\t(\d+)\t(\w+)$/o) {
        my($file, $modification_time, $size, $hash) = ($1, $2, $3, $4);
        if (defined $hashes{$hash}) {
            if (!-e $hashes{$hash}) {say $hashes{$hash} . ' already gone?'; }
            elsif (!-e ".$curdir/$file") {say "Original .$curdir/$file" . ' already gone!'; }
            else {
                say "Delete $hashes{$hash} ?";
                say "Duplicate of .$curdir/$file";
                my $a = <STDIN>;
                chomp($a);
                if ($a eq 'y') {
                    unlink $hashes{$hash}
                        or die "Couldn't unlink file $hashes{$hash}: $!"; say 'Deleted.'
                } else {
                    say 'Skipped.'
                }
            }
        }
        $hashes{$hash} = ".$curdir/$file"; # always put next file in, if there's a 3rd copy it will delete the 2nd, not delete the 1st a second time
    } else {
        die 'Incorrect line: ' . $line;
    }
}

my $endtime = time;
say 'Done at ' . localtime() . ', needed ' . ($endtime - $time) . ' seconds.';
