#/usr/bin/perl
use IO::Socket;
use strict;
use POSIX qw/strftime/;
use Switch;

sub say 
{
	my $timestampYmd = strftime('%Y-%m-%d',localtime(time())); 
	my $timestampYmdHms = strftime('%Y-%m-%d %H:%M:%S',localtime(time())); 
	system("echo '[$timestampYmdHms]'>>/home/ats/thesis/$timestampYmd.log ");
	foreach (@_){
		my $tString = "$_\n";
		print $tString;
		system("echo '$tString'>>/home/ats/thesis/$timestampYmd.log ");
	}
}
####################################################################################
my $sayOk = 0; my $debug = 0; my $debug2 = 0; my $debugOk = 0; my $debug2Ok = 0;
#sub say		{foreach (@_){print "$_\n";}}
sub nl{say "";}
sub sayOk	{if($sayOk){say @_;}}			sub endl{print "\n";}
sub debug	{if($debug){say @_;}}			sub debugOk	{if($debugOk){say @_;}}
sub debug2 {if($debug2){say @_;}}			sub debug2Ok{if($debug2Ok){say @_;}}
####################################################################################

my $plpFile = '/usr/home/ats/thesis/qodoh.plp';
my $plpTxtFile = '/usr/home/ats/thesis/qodoh.plp.txt';

my $tbfDefaultRate = 12;
my $tbfDefaultBuffer = 1600;
my $tbfDefaultLimit = 3000;
my $netemDefaultDelay = 1;
my $netemDefaultJitter = 1;
my $netemDefaultLoss = 0*100;
my $jitterIsUs = 0;


my $user = trim(`echo \$USER`);
debugOk "user:$user.";
if ($user ne 'root'){
	say "Permission denied.";
	exit (1);
}

# shaping init: no shaping
say "init clean";
system ('tc qdisc del dev eth1 root');
system ('tc qdisc del dev eth2 root');
checkNetemConfig();

my $socket = new IO::Socket::INET (
	LocalPort => '9000',
	Proto => 'tcp',
	Listen => 1,
	Reuse => 1,
) || die "ERR: new socket: $!\n";

my ($client_socket, $client_address) = ();
while(1)
{
	($client_socket, $client_address) = $socket->accept();
	my $tTimestamp = timestampRfc();
	say "\n[$tTimestamp]. received connection.";
	my $exit = 0;
	my $rx_buf;
	$rx_buf = <$client_socket>;
	say "rx_buf: $rx_buf";
	my ($command, $value) = extract_cmd($rx_buf);
	switch($command){
		case ("getDelay"){
			# int. return number of ms delayed
			$value = getDelay();
			clientSocketSend("$command:$value".", unit: ms.");
		}
		case ("setDelay"){
			# int. return number of ms delayed, could be used to check
			$value = setDelay($value);
			clientSocketSend("$command:$value".", unit: ms.");
		}
		case ("getJitter"){
			$value = getJitter();
			clientSocketSend("$command:$value".", unit: ms, normal");
		}
		case ("setJitter"){
			$value = setJitter($value);
			clientSocketSend("$command:$value".", unit: ms, normal");
		}
		case ("getBw"){
			$value = getBw();
			$value = $value/1000; # OBS: internal, Kbit
			clientSocketSend("$command:$value".", unit: Mbit/s");
		}
		case ("setBw"){
			$value = setBw($value);
			clientSocketSend("$command:$value".", unit: Mbit/s");
		}
		case ("getLoss"){
			$value = getLoss();
			$value = $value/100; # OBS: internal, %
			clientSocketSend("$command:$value".", unit: 1, not %.");
		}
		case ("setLoss"){
			$value = setLoss($value);
			$value = $value/100; # OBS: internal, %
			clientSocketSend("$command:$value".", unit: 1.");
		}
		else {
			clientSocketSend("ERR:unknown cmd:$command.");
		}
	}
	close($client_socket);
	$exit = 1;
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

sub getDelay
{
	debug2 "in getDelay";
	checkNetemConfig();
	my $delayEth1;
	my $jitterEth1;
	my $delayEth2;
	my $jitterEth2;

	my $resultEth1 = `tc -s qdisc ls dev eth1`;
	if ($resultEth1 =~ m/netem.*delay\s+(\d+)\.0ms\s+(\d+)\.0ms/){
		$delayEth1 = $1;
		$jitterEth1 = $2;
	}elsif ($resultEth1 =~ m/netem.*delay\s+(\d+)\.0ms/){
		$delayEth1 = $1;
		$jitterEth1 = 0;
	}else {
		say "ERR: getDelay: eth1 no reg mtach.";
		return "ERR: eth1 no reg match.";
	}
	my $resultEth2 = `tc -s qdisc ls dev eth2`;
	if ($resultEth2 =~ m/netem.*delay\s+(\d+)\.0ms\s+(\d+)\.0ms/){
		$delayEth2 = $1;
		$jitterEth2 = $2;
	}elsif ($resultEth2 =~ m/netem.*delay\s+(\d+)\.0ms/){
		$delayEth2 = $1;
		$jitterEth2 = 0;
	}else {
		say "ERR: getDelay: eth2 no reg mtach.";
		return "ERR: eth2 no reg match.";
	}
	if ($delayEth1 == $delayEth2){
		return $delayEth2;
	}else {
		return "ERR: dealy not match.";
	}
}
sub setDelay
{
	debug2 "in setDelay";
	#return "ERR: cannot change constant delay: xxx.";
	checkNetemConfig();
	my $delay = $_[0];
	chomp ($delay);
	if (!($delay =~ m/^\d+$/)) {
		return "ERR: $delay. allow int only, unit: ms.";
	}
	if (($delay < 1)||($delay > 1000)){
		return "ERR: $delay. delay should >= 1, <= 1000, ms.";
	}
	my $jitter = getJitter();
	if ($jitter =~ /ERR/){
		return "ERR: setDelay()-> $jitter."
	}
	my $loss = getLoss();
	if ($loss =~ /ERR/){
		return "ERR: setDelay()-> $loss."
	}
	setNetem($delay, $jitter, $loss);
	if ($delay != getDelay()){
		return "ERR: setDelay() failed."
	}else {
		return $delay;
	}
}
sub getJitter
{
	$jitterIsUs = 0;
	debug2 "in getJitter";
	checkNetemConfig();
	my $delayEth1;
	my $jitterEth1;
	my $delayEth2;
	my $jitterEth2;

	my $resultEth1 = `tc -s qdisc ls dev eth1`;
	if ($resultEth1 =~ m/netem.*delay\s+(\d+)\.0ms\s+(\d+)\.0ms/){
		$delayEth1 = $1;
		$jitterEth1 = $2;
	}elsif ($resultEth1 =~ m/netem.*delay\s+(\d+)\.0ms\s+(\d+)us/){
		$jitterIsUs = 1;
		$delayEth1 = $1;
		return ($jitterEth1 = $2/1000);
	}elsif ($resultEth1 =~ m/netem.*delay\s+(\d+)\.0ms/){
		$delayEth1 = $1;
		$jitterEth1 = 0;
	}else {
		say "ERR: getJitter: eth1 no reg mtach.";
		return "ERR: eth1 no reg match.";
	}
	my $resultEth2 = `tc -s qdisc ls dev eth2`;
	if ($resultEth2 =~ m/netem.*delay\s+(\d+)\.0ms\s+(\d+)\.0ms/){
		$delayEth2 = $1;
		$jitterEth2 = $2;
	}elsif ($resultEth2 =~ m/netem.*delay\s+(\d+)\.0ms\s+(\d+)us/){
		$jitterIsUs = 1;
		$delayEth2 = $1;
		return ($jitterEth2 = $2/1000);
	}elsif ($resultEth2 =~ m/netem.*delay\s+(\d+)\.0ms/){
		$delayEth2 = $1;
		$jitterEth2 = 0;
	}else {
		say "ERR: getDelay: eth2 no reg mtach.";
		return "ERR: eth2 no reg match.";
	}
	if ($jitterEth1 == $jitterEth2){
		return $jitterEth1;
	}else {
		return "ERR: jitter not match.";
	}
}
sub setJitter
{
	debug2 "in setJitter";
	my $jitter = $_[0];
	chomp ($jitter);
	if ($jitter > 5000 || $jitter < 0){
		return 'ERR: 0< $jitter <5000, int.';
	}
	my $delay = getDelay();
	if ($delay =~ /ERR/){
		return "ERR: setJitter()-> $delay."
	}
	my $loss = getLoss();
	if ($loss =~ /ERR/){
		return "ERR: setJitter()-> $loss."
	}
	setNetem($delay, $jitter, $loss);
	if ($jitterIsUs == 1){
		return getJitter();
	}
	if ($jitter != getJitter()){
		return "ERR: setJitter() failed."
	}else {
		return $jitter;
	}
}
sub getBw
{
	debug2 "in getBw";
	checkNetemConfig();
	my $bwEth1;
	my $bwEth2;

	my $resultEth1 = `tc -s qdisc ls dev eth1 |grep tbf`;
	if ($resultEth1 =~ m/rate\s*(\d+)\S{1}bit/){
		$bwEth1 = $1;
	}else {
		say "ERR: getBw-> eth1.";
		return "ERR: getBw-> eth1.";
	}
	my $resultEth2 = `tc -s qdisc ls dev eth2 |grep tbf`;
	if ($resultEth2 =~ m/rate\s*(\d+)\S{1}bit/){
		$bwEth2 = $1;
	}else {
		say "ERR: getBw-> eth1.";
		return "ERR: getBw-> eth1.";
	}
	if ($bwEth1 == $bwEth2){
		debug "getBw, bw: $bwEth1 Kb";
		return $bwEth1;
	}else {
		return "ERR: two bw not match.";
	}
}
sub setBw
{
	debug2 "in setBw";
	#return "ERR: bw should be constant 12mbit.";
	checkNetemConfig();
	my $bw = $_[0];
	chomp ($bw);
	if ( (!($bw =~ m/^\d+$/)) || ($bw == 0) || ($bw > 100)) {
		return "ERR: allow 1<= x >= 100, int only. mbit.";
	}
	# OBS: get netem config before set tbf
	my $delay = getDelay();
	if ($delay =~ /ERR/){
		return "ERR: setBw->getDelay:$delay."
	}
	my $loss = getLoss();
	if ($loss =~ /ERR/){
		return "ERR: setBw->getLoss:$loss."
	}
	my $jitter = getJitter();
	if ($jitter =~ /ERR/){
		return "ERR: setBw->getJitter:$jitter";
	}

	if (system("tc qdisc change dev eth1 root handle 1: tbf rate ${bw}mbit buffer $tbfDefaultBuffer limit $tbfDefaultLimit")){
		return "ERR: setBw -> eth1.";
	}
	if (system("tc qdisc change dev eth2 root handle 1: tbf rate ${bw}mbit buffer $tbfDefaultBuffer limit $tbfDefaultLimit")){
		return "ERR: setBw -> eth2.";
	}

	if (system ("tc qdisc add dev eth1 parent 1: handle 10: netem delay ${delay}ms ".($jitter?" ${jitter}ms distribution normal ":'')." loss ${loss}%")){
		return 328;
	}
	if (system ("tc qdisc add dev eth2 parent 1: handle 10: netem delay ${delay}ms ".($jitter?" ${jitter}ms distribution normal ":'')." loss ${loss}%")){
		return 331;
	}

	my $result = getBw()/1000;
	debug "setBw->getBw()/1000:$result";
	if ($result != $bw){
		return "ERR: now, bw is $result, failed to set to $bw.";
	}
	return $result;
}
sub getLoss
{
	debug2 "in getLoss";
	checkNetemConfig();
	my $lossEth1;
	my $lossEth2;

	my $resultEth1 = `tc -s qdisc ls dev eth1`;
	if ($resultEth1 =~ m/netem.*delay\s+(\d+)\.0ms/){
		if ($resultEth1 =~ m/netem.*delay\s+(\d+)\.0ms\s+(\d+)\.0ms\s+loss\s+([\.\d]+)%/){
			$lossEth1 = $3;
		}elsif ($resultEth1 =~ m/netem.*delay\s+(\d+)\.0ms\s+loss\s+([\.\d]+)%/){
			$lossEth1 = $2;
		}else {
			$lossEth1 = 0;
		}
	}else {
		say "ERR: getLoss: eth1 no reg mtach.";
		return "ERR: eth1 no reg match.";
	}
	my $resultEth2 = `tc -s qdisc ls dev eth2`;
	if ($resultEth2 =~ m/netem.*delay\s+(\d+)\.0ms/){
		if ($resultEth2 =~ m/netem.*delay\s+(\d+)\.0ms\s+(\d+)\.0ms\s+loss\s+([\.\d]+)%/){
			$lossEth2 = $3;
		}elsif ($resultEth2 =~ m/netem.*delay\s+(\d+)\.0ms\s+loss\s+([\.\d]+)%/){
			$lossEth2 = $2;
		}else {
			$lossEth2 = 0;
		}
	}else {
		say "ERR: getLoss: eth2 no reg mtach.";
		return "ERR: eth2 no reg match.";
	}
	if ($lossEth1 == $lossEth2){
		debug "getLoss, loss: $lossEth1%";
		return $lossEth1;
	}else {
		return "ERR: two loss not match.";
	}
}
sub setLoss
{
	debug2 "in setLoss";
	checkNetemConfig();
	my $loss = $_[0];
	chomp ($loss);
	if (! ($loss =~ m/^0(\.\d{1,3}){0,1}$/)){
		return "ERR: loss >= 0, loss <=0.999, max 3 decimals(res: 0.1%).";
	}
	$loss = $loss * 100;

	my $delay = getDelay();
	if ($delay =~ /ERR/){
		return "ERR: setLoss->getDelay";
	}
	my $jitter = getJitter();
	if ($jitter =~ /ERR/){
		return "ERR: setLoss->getJitter";
	}
	debug "in setLoss, delay=$delay, jitter=$jitter.";
	setNetem($delay, $jitter, $loss);
	my $result = getLoss();
	debug "setLoss->getLoss:$result";
	if ($result != $loss){
		return "ERR: setLoss failed.";
	}
	return "$loss";
}
sub setNetem
{
	debug2 "in setNetem";
	my $delay = $_[0];
	#debug "dealy:$delay";
	my $jitter = $_[1];
	my $loss = $_[2];
	say ("CMD: tc qdisc change dev eth1 parent 1: handle 10: netem delay ${delay}ms ".($jitter?" ${jitter}ms distribution normal ":'')." loss ${loss}%");
	if (system ("tc qdisc change dev eth1 parent 1: handle 10: netem delay ${delay}ms ".($jitter?" ${jitter}ms distribution normal ":'')." loss ${loss}%")){
		return 328;
	}
	if (system ("tc qdisc change dev eth2 parent 1: handle 10: netem delay ${delay}ms ".($jitter?" ${jitter}ms distribution normal ":'')." loss ${loss}%")){
		return 331;
	}
	return 0;
}
sub checkNetemConfig
{
	debug2 "in check";
	if (configExisting() != 0){
		say "check() will clean.";
		system ('tc qdisc del dev eth1 root');
		system ('tc qdisc del dev eth2 root');
		say "check(), will init.";
		my $result = (   system("tc qdisc add dev eth1 root handle 1: tbf rate ${tbfDefaultRate}mbit buffer $tbfDefaultBuffer limit $tbfDefaultLimit")
			|| system("tc qdisc add dev eth1 parent 1: handle 10: netem delay ${netemDefaultDelay}ms ${netemDefaultJitter}ms distribution normal loss $netemDefaultLoss%")
			|| system("tc qdisc add dev eth2 root handle 1: tbf rate ${tbfDefaultRate}mbit buffer $tbfDefaultBuffer limit $tbfDefaultLimit")
			|| system("tc qdisc add dev eth2 parent 1: handle 10: netem delay ${netemDefaultDelay}ms ${netemDefaultJitter}ms distribution normal loss $netemDefaultLoss%")
		);
		debug2 "check(), init finished.";
		if ($result){
			say "ERR: init failed in check().";
		}else {
			return 0;
		}
	}else {
		return 0;
	}
}
sub configExisting
{
	debug2 "in configExisting()";
	my $result1 = system('tc -s qdisc|grep eth1|grep tbf>/dev/null');
	debug "result1=$result1";
	my $result2 = system('tc -s qdisc|grep eth1|grep netem>/dev/null');
	debug "result2=$result2";
	my $result3 = system('tc -s qdisc|grep eth2|grep tbf>/dev/null');
	debug "result3=$result3";
	my $result4 = system('tc -s qdisc|grep eth2|grep netem>/dev/null');
	debug "result4=$result4";
	my $result = ($result1||$result2||$result3||$result4);
	debug "configExisting=$result";
	return $result;
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
	my $server = gethostbyname($_[0]) || die "ERR: gethostbyname()";
	return $server = inet_ntoa($server);
}
sub timestampRfc { #use POSIX qw/strftime/
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($_[0]);
	$year = $year + 1900;
	return strftime('%Y-%m-%d %H:%M:%S',localtime($_[0]?$_[0]:time())); 
}

