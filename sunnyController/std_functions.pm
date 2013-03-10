package std_functions;
use strict;
use warnings;
use Exporter;
use Socket;
use DBI;

our @ISA= qw( Exporter );

# these are exported by default.
our @EXPORT = qw(
	connectMYSQL
	consoleNlog
	console
	checkROOT
	extract_cmd
);

sub console{
	print STDOUT "-> ".$_[0]."\n";
}
sub consoleNlog{
	print STDOUT "-> ".$_[0]."\n";
}



sub connectMYSQL{	
	my $platform 	= "mysql";
	my $dbhost		= "localhost";
	my $port 		= "3306";
	my $dbuser 		= 'marc';
	my $dbpass 		= 'konko';
	my $database 	= "marc";

	my $dsn = "dbi:mysql:$database:$dbhost:$port";
	my $connect = DBI->connect($dsn, $dbuser, $dbpass) or die "Unable to connect: $DBI::errstr\n";
	return $connect;
}

sub checkROOT{
	unless ($> == 0 || $< == 0) { die consoleNlog("You must be root to execute") };
}

sub extract_cmd{
	$_[0] =~ /^(.+):(.*)$/;
	# Debug
	#print "command: $1 value: $2\n";
	return ($1,$2);
}
