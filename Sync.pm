#!perl -w
use strict;
use warnings;
use 5.010_000;
require 5.010_000;
use feature ':5.10';
use Cwd;
use Sys::Hostname;
use Digest;
use Fcntl qw(:flock SEEK_END); # import LOCK_* and SEEK_END constants

package Sync;

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    return $self;
}

sub init {
    my $self = shift;
    $self->{'LIMIT'} = 1;
    $self->{'DIGEST_LENGTH_MB'} = 5;
    $self->{'DIGEST_LENGTH'} = $self->{'DIGEST_LENGTH_MB'} * 1024 * 1024;
    $self->{'DIGEST_ALGO'} = 'SHA-224';
    
    $self->{'PART_SIZE'} = 256 * 1024;
    $self->{'MIN_SIZE_FOR_PARTS'} = 2 * $self->{'PART_SIZE'};
    
    $self->{'base'} = '';
    $self->{'_digest_main'} = undef;
    $self->{'_digest_block'} = undef;
    $self;
}

my %ALLOWED_CONFIG_ITEMS = (
    'DIGEST_ALGO' => 1,
    'DIGEST_LENGTH_MB' => 1,
    'CWD' => 1,
    'HOST' => 1,
    'STARTED' => 1,
    'STOPPED' => 1,
    'RUNTIME' => 1,
    'TOTALDIRS' => 1,
    'TOTALFILES' => 1,
    'TOTALSKIPPED' => 1,
);
sub configitem {
    my ($self, $item, $value) = @_;
    if (!$ALLOWED_CONFIG_ITEMS{$item}) { die "Invalid item: $item, with value $value"; }
    $self->{$item} = $value;
    if ($item eq '') {}
    elsif ($item eq 'DIGEST_LENGTH_MB') {
        if ($value =~ /^\s*(\d+) *MB\s*$/) { $self->{'LIMIT'} = 1; $self->{'DIGEST_LENGTH'} = $1 * 1024 * 1024; }
        elsif ($value =~ /^\s*all\s*$/) { $self->{'LIMIT'} = 0; }
        else { die 'Unknown digest block length'; }
    }
    elsif ($item eq 'PART_SIZE' and $value =~ /^\s*(\d+)\s*$/) { $self->{'MIN_SIZE_FOR_PARTS'} = 2 * $1; }
    elsif ($item eq 'DIGEST_ALGO') { $self->{'_digest_main'} = undef; }
    elsif ($item eq '') {}
}

sub select_digest {
    my ($self, $algo) = @_;
    if ($algo eq 'MD5') { return Digest->new('MD5'); }
    elsif ($algo =~ /^([A-Z_]+)-?(\d+(\/\d+)?)?$/) { return Digest->new($1, $2); } 
    else { die 'Unknown hash algorithm'; }
}

sub getmaindigest {
    my $self = shift;
    return $self->{'_digest_main'} if $self->{'_digest_main'};
    $self->{'_digest_main'} = $self->select_digest($self->{'DIGEST_ALGO'});
}

sub getblockdigest {
    my $self = shift;
    return $self->{'_digest_block'} if $self->{'_digest_block'};
    $self->{'_digest_block'} = $self->select_digest('SHA-1');
}

sub hashforfile {
    my ($self, $file, $size) = @_;
    my $digest = $self->getmaindigest();
    seek($file,0,0);
    binmode $file;
    if ($self->{'LIMIT'} && $size > $self->{'DIGEST_LENGTH'}) {
        my $length = read $file, my $data, $self->{'DIGEST_LENGTH'};
        $digest->add($data);
    } else {
        $digest->addfile($file);
    }
    
    $digest->hexdigest();
}

sub blocksforfile {
    my ($self, $file) = @_;
    my $digest = $self->getblockdigest();
    seek($file,0,0);
    binmode $file;
    my @blocks = ();
    my $partsize = $self->{'PART_SIZE'};
    while ((read $file, my $data, $partsize) == $partsize) {
        $digest->add($data);
        push @blocks, $digest->hexdigest();
    }
    @blocks;
}


my @SIZES = ('', 'k', 'M', 'G', 'T', 'P', 'E', 'Z', 'Y');
sub format_bytes($) {
    my ($bytes) = @_;
    my $factor = 0;
    use integer;
    while ($bytes >= 1024) {
        $bytes /= 1024;
        $factor++;
    }
    return sprintf('%3.2f %sB', $bytes, $SIZES[$factor]);
}
