#/usr/bin/perl
use IO::Socket;
use strict;

############################## Sunny debug BinSun#mail.com ###################
my $sayOk = 0; my $debug = 1; my $debug2 = 1; my $debugOk = 0; my $debug2Ok = 0;
sub say		{foreach (@_){print "$_\n";}}	sub nl{say "";}
sub sayOk	{if($sayOk){say @_;}}			sub endl{print "\n";}
sub debug	{if($debug){say @_;}}			sub debugOk	{if($debugOk){say @_;}}
sub debug2 {if($debug2){say @_;}}			sub debug2Ok{if($debug2Ok){say @_;}}
###############################################################################

$SIG{'TSTP'} = 'noStop';
sub noStop
{
	say "plz use Ctrl+c, instead of Ctrl+z.";
	exit (130);
}

## don't buffer output
my $old_fh = select socketSession;
$| = 1;
select $old_fh;

my $server = $ARGV[0] || 'localhost';
my $port = $ARGV[1] || '9000';
if (!($server =~ /[\d\.]+/)){
	debug2Ok "server: $server";
	$server = dns($server);
	debug2Ok "gethostbyname:$server.";
}

my $rx_buf;
my $user_input;

my $exit = 0;
while($exit eq 0){
	print STDOUT "<-: ";
	$user_input = <STDIN>;
	debugOk "input: $user_input";
	chomp($user_input);
	debugOk "chomped input: $user_input";
	my($command, $value) = extract_cmd($user_input);
	
	my $sock = new IO::Socket::INET (
		PeerAddr => $server,
		PeerPort => $port,
		Proto => 'tcp',
	) || die "Could not create socket: $!\n";

	$sock->send("$command:$value\n");
	$rx_buf = "\0";
	while (<$sock>){
		debugOk "reading...";
		$rx_buf = $rx_buf.$_;
	}
	print STDOUT " -> $rx_buf\n";
	close($sock);
	#$exit = 1;
}

sub extract_cmd{
	debugOk "will extract_cmd: $_[0]";
	if ($_[0] =~ /^(.+):(.*)$/){
		return ($1,$2);
	}else{
		return ($_[0],"no-arg");
	}
}

# Perl trim function to remove whitespace from the start and end of the string
sub trim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}
# Left trim function to remove leading whitespace
sub ltrim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	return $string;
}
# Right trim function to remove trailing whitespace
sub rtrim($)
{
	my $string = shift;
	$string =~ s/\s+$//;
	return $string;
}
sub dns()
{
	my $server = gethostbyname($_[0]) or die "ERR: gethostbyname()";
	return $server = inet_ntoa($server);
}

