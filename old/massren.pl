use strict;
use warnings;
opendir my $dh, "." or die;
while (my $f = readdir $dh) {
	next if ($f =~ /^\.\.?$/);
	if ($f =~ /(.+)\.-\.7x(\d\d)\.-\.(.+)\.avi/) {
        my $prefix = $1;
		my $n = $2;
		my $name = $3;
		$name =~ s/\./ /g;
		rename $f, "$prefix [7x$n] $name.avi";
	}
}