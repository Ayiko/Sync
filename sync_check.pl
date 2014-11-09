#!perl -w
use strict;
use warnings;
use 5.010_000;
require 5.010_000;
use feature ':5.10';
use Cwd;
use Sys::Hostname;
use Fcntl qw(:flock SEEK_END); # import LOCK_* and SEEK_END constants
use Digest;
use Carp qw(confess);
use Config;
die 'Cannot guarantee correct handling of large files' if $Config{intsize} < 4;

my $DIGEST_LENGTH_MB = 5;
my $limit = 1; # 1 = md5 of only 5MB, 0 = md5 of entire file
if ($limit) { say "Using up to $DIGEST_LENGTH_MB MB for hash digest generation"; }
else { say "Warning: using complete file for hash generation!"; }
my $DIGEST_LENGTH = $DIGEST_LENGTH_MB *1024*1024;
my $DIGEST_ALGO = 'SHA512';
my $digest = select_digest($DIGEST_ALGO);
my $digest2 = select_digest('SHA-1');

my $base = shift @ARGV or die "Use sync_generate_csv.pl basepath [csvfile]";
$base eq '' or $base =~ s'/?$'/'; # make sure there's a trailing /
my $PART_SIZE = 256 * 1024;


sub select_digest {
    my $algo = shift;
    if ($algo eq 'MD5') { return Digest->new('MD5'); }
    elsif ($algo =~ /^([A-Z_]+)-?(\d+(\/\d+)?)?$/) { return Digest->new($1, $2); }
    else { die 'Unknown hash algorithm'; }
}



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
my %config = ();
# ;** CWD: c:/Dev/Sync
# ;** HOST: Owika
# ;** STARTED: 1415527408
# ;** HASH_ALGO: SHA512
# ;** HASH_LENGTH: 5 MB

while (my $line = <$if>) {
    if ($line =~ /^\s*;\*\*\s+ (\w+):s*(.+)$/o) { # config setting
        die 'Double config setting: ' . $1 if defined $config{$1};
        $config{$1} = $2;
        if ($1 eq 'CWD') {  }
        if ($1 eq 'HASH_ALGO') {
            if ($2 ne $DIGEST_ALGO) {
                say 'Switching to hash algo ' . $2;
                $DIGEST_ALGO = $2;
                $digest = select_digest($DIGEST_ALGO);
            }
        }
        if ($1 eq 'HASH_LENGTH') {
            if ($2 eq 'all') { $limit = 0; }
            elsif ($2 =~ /(\d+) ?MB/io) {
                $limit = 1;
                say 'Switching to hash length ' . $1;
                $DIGEST_LENGTH_MB = $1;
                $DIGEST_LENGTH = $DIGEST_LENGTH_MB * 1024 * 1024;   
            } else { die 'Bad HASH_LENGTH';}
        }
    }
    elsif ($line =~ /^\s*;/o) { next; } # normal comment
    elsif ($line =~ /^<(.*)>$/o) { # dir name
        $curdir = $1;
		say "-> $curdir";
        if ($curdir eq '') { $curdir = '.'; }
        # die 'Duplicate dir: '. $line if $dirs{$curdir}++;
    }
    elsif ($line =~ /^\s*\)\s*$/o) { next; } # previous file blocks weren't read?
    elsif ($line =~ /^\t[0-9a-z]+\s*$/o) { next; } # previous file blocks weren't read?
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
					if ($limit && $size > $DIGEST_LENGTH) {
						my $data;
						my $length = read $file, $data, $DIGEST_LENGTH;
						$digest->add($data);
					} else {
						$digest->addfile($file);
					}
					my $hash = $digest->hexdigest();
                    
                    if ($hash ne $ohash) { say "$fn changed hash: was $ohash, is now $hash"; }
                    
                    if ($oparts) { # also check all blocks
                        seek($file,0,0);
                        my $partpos = 0;
                        my $data;
                        defined($line = <$if>) or die 'bad format';
                        while ($line =~ /^\t([a-f0-9]+)$/) {
                            my $opart = $1;
                            my $length = read $file, $data, $PART_SIZE;
                            die 'empty read at ' . $partpos . 'for file ' . $fn  if $length == 0;
                            $digest2->add($data);
                            my $part =  $digest2->hexdigest();
                            if ($opart ne $part) { say 'Diff for startpos ' . $partpos; }
                            $partpos += $length;
                            $line = <$if>;
                        }
                        if ($line !~ /^\s*\)\s*$/) { die "Wrong line: ($line)"; }
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
