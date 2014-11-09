#!perl -w
use strict;
use warnings;
use 5.010_000;
require 5.010_000;
use feature ':5.10';
use Cwd;
use Sys::Hostname;
#use Number::Format qw(format_bytes);
use Digest;
use Carp qw(confess);
use Fcntl qw(:flock SEEK_END); # import LOCK_* and SEEK_END constants
use Config;
die 'Cannot guarantee correct handling of large files' if $Config{intsize} < 4;

sub select_digest {
    my $algo = shift;
    if ($algo eq 'MD5') { return Digest->new('MD5'); }
    elsif ($algo =~ /^([A-Z_]+)-?(\d+(\/\d+)?)?$/) { return Digest->new($1, $2); } 
    else { die 'Unknown hash algorithm'; }
}

my $DIGEST_LENGTH_MB = 5;
my $limit = 1; # 1 = md5 of only 5MB, 0 = md5 of entire file
my $DIGEST_LENGTH;
if ($limit) { say "Using up to $DIGEST_LENGTH_MB MB for hash digest generation"; $DIGEST_LENGTH = $DIGEST_LENGTH_MB *1024*1024; }
else { say "Warning: using complete file for hash generation!"; $DIGEST_LENGTH = -1; }
my $DIGEST_ALGO = 'SHA512';
my $digest = select_digest($DIGEST_ALGO);
my $digest2 = select_digest('SHA-1');

my $PART_SIZE = 256 * 1024;
my $MIN_SIZE_FOR_PARTS = 2 * $PART_SIZE;

my $base = shift @ARGV or die "Use sync_generate_csv.pl basepath [csvfile]";
$base eq '' or $base =~ s'/?$'/'; # make sure there's a trailing /
my $outputfile = shift @ARGV // ( $base =~ m'([^/]++)/' && "$1.csv" ) // '_hashes.csv';
say "Using base folder: " . $base;
say "Using output file: " . $outputfile ;
die 'Error: output file already exists: ' . $outputfile if -e $outputfile; 
die 'Error: base dir doesn\'t exist: ' . $base if !-e $base; 

my $filecount = 0;
my $skipcount = 0;
my $dircount = 0;
my $catalog = 3;
my $totalsize = 0;
my $digestsize = 0;
my $of;

my @SIZES = ('', 'k', 'M', 'G', 'T', 'P', 'E', 'Z', 'Y');
sub format_bytes($) {
    my ($bytes) = @_;
    my $factor = 0;
    while ($bytes >= 1024) {
        $bytes /= 1024;
        $factor++;
    }
    return sprintf('%3.2f %sB', $bytes, $SIZES[$factor]);
}

sub parse($) {
	my @dirs = (@_);
	while (defined (my $dir = shift @dirs)) {
		$dircount++;
		say "-> $dir";
		say $of "<$dir>";
		opendir(my $dh, "$base$dir") || die "can't opendir $dir: $!";
		for (sort readdir($dh)) {
			next if /^\.\.?$/o; # ignore .  and .. in dir listing
            # skip the following files as they are not useful for backup/comparing
            if (   /\.wdmc$/o                    # WD NAS index stuff
			    || /\.tgmd$/o                    # movie sheets
			    || /^thumbs\.db$/io              # Windows thumbnail images
			    || /^picasa\.ini$/io             # Picasa config
			    || /^desktop\.ini$/io            # Windows folder stuff
			    || /^SyncToy_[-\w]++\.dat$/io    # SyncToy
			    || /_sheet(?:\.sheet)?\.jpg$/o   # auto-generated cover sheets
			    || /^Sample$/o                   # Sample dir for movies, don't go into those
			    || /^VIDEO_TS.BUP$/o             # VCD backup files (copy of VIDEO_TS.IFO)
			    || /^VTS_(\d\d)_(\d).BUP$/o      # more VCD backup files
			    || /^AlbumArt.*\.jpg$|^folder.jpg$/io # album art
            ) {
                $skipcount++;
                next;
            }
			my $fn = "$base$dir/$_";
			if (-f $fn) {
				#my (undef,undef, $chmod, $nlink, undef, undef, undef, $size, $atime, $mtime, $ctime, undef, undef) = stat _;
				my (undef,undef, $chmod, $nlink, undef, undef, undef, $size, undef, $mtime, undef, undef, undef) = stat _;
				next if $size == 0;
				$totalsize += $size;
				if (open my $file, '<', $fn) {
                    flock($file, LOCK_EX);
					binmode $file;
					if ($limit && $size > $DIGEST_LENGTH) {
						my $data;
						my $length = read $file, $data, $DIGEST_LENGTH;
						$digest->add($data);
						$digestsize += $length;
					} else {
						$digest->addfile($file);
						$digestsize += $size;
					}
					my $hash = $digest->hexdigest();
                    
                    if ($size >= $MIN_SIZE_FOR_PARTS) {
                        say $of "$_\t$mtime\t$size\t$hash\t(";
                        seek($file,0,0);
                        my $partpos = 0;
                        my $data;
                        while ($partpos < $size) {
                            my $length = read $file, $data, $PART_SIZE;
                            die 'empty read at ' . $partpos . 'for file ' . $fn  if $length == 0;
                            $digest2->add($data);
                            say $of "\t" . $digest2->hexdigest();
                            $partpos += $length;
                        }
                        say $of ')';
                    }
                    else {
                        say $of "$_\t$mtime\t$size\t$hash";
                    }
                    flock($file, LOCK_UN);
					close $file;
				} else {
					say "ERROR OPENING: $fn";
				}
				# db_run('addfile', $_, $mtime, $size, $hash, $dir, $catalog);
				$filecount++;
			}
			elsif (-d _) { push @dirs, "$dir/$_"; }
			
		}
		closedir $dh;
	}
}

my $time = time;
my $dir = '';

open $of, '>', $outputfile or die 'Could not open output file ' . $outputfile . ";" . $!;
say $of "CATALOG v2";
say $of '; Starting at ' . localtime $time;
say $of ';** CWD: ' . getcwd();
say $of ';** HOST: ' . hostname();
say $of ';** STARTED: ' . time;
say $of ';** HASH_ALGO: ' . $DIGEST_ALGO;
say $of ';** HASH_LENGTH: ' . ($limit ? $DIGEST_LENGTH_MB . ' MB' : 'all');
say $of "; file	modification_time	size	hash";
say 'Starting at ' . scalar localtime();

parse($dir);

my $endtime = time;
say $of ';** STOPPED: ' . $endtime;
say $of ';** RUNTIME: ' . ($endtime - $time) . ' seconds';
say $of ';** TOTALDIRS: ' . $dircount;
say $of ';** TOTALFILES: ' . $filecount;
say $of ';** TOTALSKIPPED: ' . $skipcount;
say $of '; Total file size ' . format_bytes($totalsize);
say $of '; Processed ' . format_bytes($digestsize) . ' for hashes';
say $of '; Done at ' . localtime $endtime;
close $of;
say 'Done at ' . localtime() . ', needed ' . ($endtime - $time) . ' seconds.';
say "Handled, $filecount files, $dircount dirs, skipped $skipcount files/dirs.";
say sprintf('Total file size: %s, processed %s for hashes.', format_bytes($totalsize), format_bytes($digestsize) );
