use v6;
use Test;
use DBIish;

plan 12;

my %con-parms = :database<dbdishtest>, :user<testuser>, :password<testpass>;
my $dbh;

try {
  $dbh = DBIish.connect('mysql', |%con-parms);
  CATCH {
	    when X::DBIish::LibraryMissing | X::DBDish::ConnectionFailed {
		diag "$_\nCan't continue.";
	    }
            default { .throw; }
  }
}
without $dbh {
    skip-rest 'prerequisites failed';
    exit;
}

ok $dbh,    'Connected';
lives-ok { $dbh.do('DROP TABLE IF EXISTS test') }, 'Clean';
try {
    $dbh.do(q|
    CREATE TABLE test (
	adate DATE,
	atime TIME,
	atimestamp DATETIME(6)
    )|);
    CATCH {
	skip-rest "This version of mysql don't like precision in DATETIME";
	exit;
    }
};

pass 'Table created';

my $sth = $dbh.prepare('INSERT INTO test (adate, atimestamp) VALUES(?, ?)');
my $now = DateTime.now;
lives-ok {
    $sth.execute($now, $now);
}, 'Insert Perl6 values';
$sth.dispose;
$sth = $dbh.prepare('SELECT adate, atimestamp FROM test');
my @coltype = $sth.column-types;
ok @coltype eqv [Date, DateTime],	    'Column-types';

is $sth.execute, 1,			    'One row';
my ($date, $datetime) = $sth.row;
isa-ok $date, Date;
isa-ok $datetime,  DateTime;
is $date, $now.Date,			    'Today';
is $datetime, $now,			    'Right now';
$sth.dispose;
$sth = $dbh.prepare('SELECT NOW()');
is $sth.execute, 1,			    'One now';
$datetime = $sth.row[0];
isnt $datetime, $now,			    'Server drift';
diag $datetime.Instant - $now.Instant;
$dbh.do('DROP TABLE IF EXISTS test');