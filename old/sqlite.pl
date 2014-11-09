#!perl -w
use strict;
use warnings;
use 5.010_000;
require 5.010_000;
use feature ':5.10';
use DBI;

# my $dbh = DBI->connect("dbi:SQLite:dbname=mydb.sqlite","","");
my $dbh = DBI->connect(
				'DBI:mysql:mysql_server_prepare=1;host=localhost',
				'root',		# username for MySQL server
				'',		# password for MySQL server
				{ RaiseError => 1, AutoCommit => 0, mysql_auto_reconnect => 1 }
		);

$dbh->{unicode} = 1;

$dbh->do('USE collector');
my $dirsth = $dbh->prepare('INSERT INTO DIRS VALUES (NULL,?,?)');
my $filesth = $dbh->prepare('INSERT INTO FILES VALUES (NULL,?,?,?,?,?,?)');

my $coll;
open $coll, '__hashes.txt' or die "File not found.";

my $curdid = undef;
while (<$coll>) {
	next if /^;|^$/; # skip empty lines or lines starting with ";"
	if (/^DIR\t(.+)$/) {
		#handle dir
		#say $1;
		$dirsth->execute($1,0);
		$curdid = $dbh->last_insert_id(undef,undef,undef,undef,undef);
	} else {
		#handle file
		/^(.+?)\t(\d++)\t(\d++)\t(\w++)$/ or die "Not a file line: '$_'";
		$filesth->execute($1,$curdid,$2,$3,$4,0)
	}
}
$dirsth->finish();
$filesth->finish();

$dbh->commit();
say 'Finished.';


__END__

-- invoegen in temp table
INSERT INTO TEMP
SELECT md5
FROM `files`
GROUP BY md5
HAVING COUNT(*) > 1

-- opvragen van dupes
SELECT did, dname, fname, size, md5, fid
FROM temp
JOIN files USING (md5)
JOIN dirs USING (did)
ORDER BY md5



SELECT md5, COUNT(*) AS n
FROM `files`
HAVING n > 1


SELECT a.fid, a.name, a.did, a.size, FROM_UNIXTIME(a.mtime) As m, md5
FROM `files` AS a
WHERE md5 IN (
  SELECT md5 FROM files GROUP BY md5 HAVING count(*)>=2
)
ORDER BY md5,name






SELECT * FROM files AS a WHERE a.md5 IN (
SELECT b.md5
FROM `files` AS b
WHERE b.md5 < "05"
GROUP BY b.md5
HAVING COUNT(*) > 1
)




use DBI;
# my $dbh = DBI->connect("dbi:SQLite:dbname=syncdb.sqlite","","");
# $dbh->{unicode} = 1;

# $dbh->do('
# CREATE TABLE entries (
	# id INTEGER PRIMARY KEY,
	# name,
	# path,
	# md5
# )
# ');
# my $insert = $dbh->prepare('
# INSERT INTO entries(name,path,md5) VALUES (?,?,?)
# ');

# $insert->execute('naaaam','pad','dsfdsfg');