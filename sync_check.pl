#!perl -w
use strict;
use warnings;
use 5.010_000;
require 5.010_000;
use feature ':5.10';
use Cwd;
use Sys::Hostname;
use Fcntl qw(:flock SEEK_END); # import LOCK_* and SEEK_END constants
use Carp qw(confess);
use Config;
die 'Cannot guarantee correct handling of large files' if $Config{intsize} < 4;
use lib '.';
use Sync;

my $base = shift @ARGV or die "Use sync_check.pl basepath [csvfile]";
$base eq '' or $base =~ s'/?$'/'; # make sure there's a trailing /

# read csv file
my $infile = shift @ARGV;
if (not(-e $infile && -r _)) {
    die "File $infile isn't readable...";
}
my $time = time;
say 'Starting at ' . scalar localtime();

open my $if, '<', $infile or die 'Could not open output file ' . $infile . ";" . $!;
die unless <$if> =~ /^CATALOG/;

my $curdir;
my $digest = Sync->new()->init();

while (my $line = <$if>) {
    if ($line =~ /^\s*;\*\*\s+ (\w+):s*(.+)$/o) { # config setting
        $digest->configitem($1,$2);
    }
    elsif ($line =~ /^\s*;/o) { next; } # normal comment
    elsif ($line =~ /^<(.*)>$/o) { # dir name
        $curdir = $1;
		say "-> $curdir";
        if ($curdir eq '') { $curdir = '.'; }
    }
    elsif ($line =~ /^(.+)\t(\d+)\t(\d+)\t(\w+)(\t\(?\d*)?$/o) { #file info
        my ($ofile, $omodification_time, $osize, $ohash, $oparts) = ($1, $2, $3, $4, $5);
        
        # check file
			my $fn = "$base$curdir/$ofile";
			if (-f -r $fn) {
				my (undef,undef, $chmod, $nlink, undef, undef, undef, $size, undef, $mtime, undef, undef, undef) = stat _;
                
                if ($size != $osize) { say "$fn changed size: was $osize, is now $size"; }
                if ($omodification_time != $mtime) { say "$fn changed modification time: was $omodification_time, is now $mtime"; }
                
				# $totalsize += $size;
				if (open my $file, '<', $fn) {
                    flock($file, LOCK_EX);
					binmode $file;
					my $hash = $digest->hashforfile($file, $size);
                    
                    if ($hash ne $ohash) { say "$fn changed hash: was $ohash, is now $hash"; }
                    
                    if ($oparts) { # also check all blocks
                        my @b = $digest->blocksforfile($file);
                        my $i = 0;
                        defined($line = <$if>) or die 'bad format';
                        while ($line =~ /^\t([a-f0-9]+)$/) {
                            if ($1 ne $b[$i]) { say "Diff for $1 <> $b[$i]"; }
                            $i++;
                            $line = <$if>;
                        }
                    }
                    flock($file, LOCK_UN);
					close $file;
				} else {
					say "ERROR OPENING: $fn";
				}
			} else {
                say 'Missing file: ' . $fn;
            }
    }
    else {
        die 'Incorrect line: ' . $line;
    }
}
close $if;

my $endtime = time;
say 'Done at ' . localtime() . ', needed ' . ($endtime - $time) . ' seconds.';
