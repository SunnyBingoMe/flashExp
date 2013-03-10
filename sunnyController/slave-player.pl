#/usr/bin/perl -w
use IO::Socket;
use File::Basename;
use POSIX qw/strftime/;
use strict;
use Switch;

sub say
{
	my $timestampYmd = timestampRfcYmd();
	my $timestampRfc = timestampRfc();
	system ("echo '[$timestampRfc]' >> /home/ats/thesis/$timestampYmd.log");
	foreach(@_){
		my $tString = $_."\n";
		print $tString;
		system("echo '$tString' >>/home/ats/thesis/$timestampYmd.log");
	}
}

######################################################################
my $sayOk = 0; my $debug = 1; my $debug2 = 1; my $debugOk = 0; my $debug2Ok = 0;
#sub say		{foreach (@_){print "$_\n";}}
sub nl{say "";}
sub sayOk	{if($sayOk){say @_;}}			sub endl{print "\n";}
sub debug	{if($debug){say @_;}}			sub debugOk	{if($debugOk){say @_;}}
sub debug2 {if($debug2){say @_;}}			sub debug2Ok{if($debug2Ok){say @_;}}
######################################################################

my $defaultFilePath='/data/qodoh/';
my $dagLockFile = '/data/qodoh/dag.lock';
my $originalFilePrefix = 'test';
my $childPid;

my $user = trim(`echo \$USER`);
debug "user:$user.";
if ($user ne 'root'){
	say "Permission denied.";
	exit (1);
}

my $socket = new IO::Socket::INET (
	LocalPort => '9001',
	Proto => 'tcp',
	Listen => 1,
	Reuse => 1,
);
die "Could not create socket: $!\n" unless $socket;

my ($client_socket, $client_address) = ();
while(1)
{
	($client_socket, $client_address) = $socket->accept();
	my $tTime = timestampRfc();
	my $exit = 0;
	my $rx_buf;
	$rx_buf = <$client_socket>;
	say "\n\n[$tTime] rx_buf: $rx_buf";
	my ($command, $value) = extract_cmd($rx_buf);
	switch($command){
		case ("restart"){
			stopPlayer();
			$value = startPlayer($value);
			clientSocketSend("$command:$value");
		}
		case ("startPlayer"){
			$value = startPlayer($value);
			clientSocketSend("$command:$value");
		}
		case ("stopPlayer"){
			$value = stopPlayer($value);
			clientSocketSend("$command:$value");
		}
		case ("getPlayerPid"){
			$value = getPlayerPid();
			clientSocketSend("$command:$value");
		}
		else {
			clientSocketSend("ERR:unknown cmd:$command. i am player-restarter.");
		}
	}
	close($client_socket);
	#$exit = 1;
}
close($socket);

sub clientSocketSend
{
	$client_socket->send("$_[0]\n");
	return 0;
}
sub extract_cmd
{
	debugOk @_;
	$_[0] =~ /^(.+):(.*)$/;
	# debug
	#print "command: $1 value: $2\n";
	return ($1,$2);
}
sub startPlayer
{
	$childPid = fork ();
	if ($childPid == 0){
		debug "i am fork->child";
		close ($socket);
		close ($client_socket);
		system ("/home/ats/Desktop/flashplayer /home/ats/Desktop/videoplayer_new_timer.swf");
		debug "player exited.";
		exit (0);
	}else {
		debug "i am fork->parent, mitt barn: $childPid.";
		select (undef,undef,undef,0.25);
		my $playerPid = getPlayerPid();
		return "player started with pid: $playerPid.";
	}
}
sub stopPlayer
{
	my $playerPid = getPlayerPid();
	if ($playerPid =~ /ERR/){
		#system ("echo '$originalFilePrefix' >>/home/ats/thesis/dropbox_sync_fs/dataAndregression/getplayerPid-EE.log");
		return "ERR: getPlayerPid.";
	}else {
		if (system("kill -KILL $playerPid")){
			return "ERR: failed to stop pid: $playerPid.";
		}
		debug "wait ing pid";
		waitpid ($childPid,0);
		debug "wait pid done";

		return "stopped pid: $childPid.";
	}
}
sub getPlayerPid
{
	my $playerPid = `ps aux |grep '/home/ats/Desktop/flashplayer' |grep -v grep |cut -c 9-15`;
	chomp ($playerPid);
	$playerPid = trim ($playerPid);
	debug "playerPid: $playerPid.";
	if ($playerPid =~ /^\d+$/){
		return $playerPid;
	}else {
		return "ERR: getPlayerPid() failed, not running?";
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
sub timestampRfc 
{
	return strftime('%Y-%m-%d %H:%M:%S',localtime($_[0]?$_[0]:time())); 
}
sub timestampUnderline
{
	return strftime('%Y%m%d_%H%M%S',localtime($_[0]?$_[0]:time())); 
}
sub timestampRfcYmd
{
	return strftime('%Y-%m-%d',localtime($_[0]?$_[0]:time())); 
}

