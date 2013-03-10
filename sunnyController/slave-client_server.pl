#/usr/bin/perl
use IO::Socket;
use strict;
use POSIX qw/strftime/;
use Switch;

####################################################################################
my $sayOk = 0; my $debug = 1; my $debug2 = 1; my $debugOk = 0; my $debug2Ok = 0;
sub say		{foreach (@_){print "$_\n";}}	sub nl{say "";}
sub sayOk	{if($sayOk){say @_;}}			sub endl{print "\n";}
sub debug	{if($debug){say @_;}}			sub debugOk	{if($debugOk){say @_;}}
sub debug2 {if($debug2){say @_;}}			sub debug2Ok{if($debug2Ok){say @_;}}
####################################################################################

my $plpFile = '/usr/home/ats/thesis/qodoh.plp';
my $plpTxtFile = '/usr/home/ats/thesis/qodoh.plp.txt';

my $user = trim(`echo \$USER`);
debugOk "user:$user.";
if ($user ne 'root'){
	say "Permission denied.";
	exit (1);
}

# shaping init: no shaping
#system('ipfw del 10');
#system('ipfw -f pipe flush');
#bwDelayLossCheck();

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
	debug "rx_buf: $rx_buf";
	my ($command, $value) = extract_cmd($rx_buf);
	switch($command){
		case("getCA"){
			$value = getCA();
			clientSocketSend("$command:$value");
		}
		case("setCA"){
			$value = setCA($value);
			clientSocketSend("$command:$value");
		}
		case("getTCP_WMEM"){
			$value = getTCP_WMEM();
			clientSocketSend("$command:$value");
		}
		case("setTCP_WMEM"){
			$value = setTCP_WMEM($value);
			clientSocketSend("$command:$value");
		}
		case("getCORE_WMEM"){
			$value = getCORE_WMEM();
			clientSocketSend("$command:$value");
		}
		case ("getRx"){
			# int. return number of received packets
			$value = getRx();
			clientSocketSend("$command:$value");
		}
		case ("getTx"){
			# int. return number of transmitted packets
			$value = getTx();
			clientSocketSend("$command:$value");
		}
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
		case ("getBw"){
			$value = getBw();
			clientSocketSend("$command:$value".", unit: Mbit/s");
		}
		case ("setBw"){
			$value = setBw($value);
			clientSocketSend("$command:$value".", unit: Mbit/s");
		}
		case ("getPlr"){
			goto case_getLoss;
		}
		case ("getLoss"){
			case_getLoss:
			$value = getLoss();
			clientSocketSend("$command:$value".", unit: 1, not %.");
		}
		case ("setPlr"){
			goto case_setLoss;
		}
		case ("setLoss"){
			case_setLoss:
			$value = setLoss($value);
			clientSocketSend("$command:$value".", unit: 1.");
		}
		case ("startMp"){
			$value = startMp($value);
			clientSocketSend("$command:$value");
		}
		case ("stopMp"){
			$value = stopMp($value);
			clientSocketSend("$command:$value");
		}
		case ("getMpPid"){
			$value = getMpPid($value);
			clientSocketSend("$command:$value");
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
sub getCA
{
	# Read current congestion avoidance version
	my $result = `sysctl net.ipv4.tcp_congestion_control 2>&1`;
	$result =~ /.+= (.+)$/;
	return $1;
}
sub setCA
{
	# Set congestion avoidance version
	my $new_CA = $_[0];
	my $result = `sysctl -w net.ipv4.tcp_congestion_control=$new_CA 2>&1`;
	$result =~ /.+= (.+)$/;
	return $1;
}
sub getTCP_WMEM
{
	# Read ...
	my $result = `sysctl net.ipv4.tcp_wmem 2>&1`;
	$result =~ /.+ = (\d+)\s+(\d+)\s+(\d+)$/;
	# debug
	#print "Min:$1 Def:$2 Max:$3\n";
	return $result;
	#return ("tcp_wmem min: $1 , default: $2, max: $3");
}
sub setTCP_WMEM{
	# Read ...
	my $result = `sysctl -w net.ipv4.tcp_wmem='$_[0] $_[0] $_[0]' 2>&1`;
	$result =~ /.+ = (\d+)\s+(\d+)\s+(\d+)$/;
	# debug
	#print "Min:$1 Def:$2 Max:$3\n";
	return ("tcp_wmem min: $1 , default: $2, max: $3");
}
sub getCORE_WMEM{
	# Read ...
	my $result = `sysctl net.core.wmem_max 2>&1`;
	$result =~ /.+ = (\d+)$/;
	# debug
	#print "wmem_max:$1\n";
	my $wmem_max = $1;
	my $result = `sysctl net.core.wmem_default 2>&1`;
	$result =~ /.+ = (\d+)$/;
	my $wmem_default = $1;
	return ("core_wmem default: $wmem_default, max: $wmem_max");
}
sub extract_cmd
{
	debugOk @_;
	$_[0] =~ /^(.+):(.*)$/;
	# debug
	#print "command: $1 value: $2\n";
	return ($1,$2);
}
sub getRx
{
	my $rxOk = getNetstat('rxOk');
	return $rxOk;
}
sub getTx
{
	my $txOk = getNetstat('txOk');
	return $txOk;
}
sub getNetstat
{
	my $result = `netstat -i 2>&1`;
	debugOk $result;
	my $ifName = 'eth1';
	if (system('ifconfig eth1')){
		$ifName = 'eth0';
	}
	$result =~ /$ifName\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+BMRU/;
	my $mtu = $1;
	my $rxOk = $3;
	my $rxErr = $4;
	my $rxDrp = $5;
	my $rxOvr = $6;
	my $txOk = $7;
	my $txErr = $8;
	my $txDrp = $9;
	my $txOvr = $10;
	debug2Ok "txovr: $txOvr.";
	debug2Ok "tx,rx: $rxOk,$txOk.";
	switch($_[0]){
		case ('rxOk'){
			return $rxOk;
		}
		case ('txOk'){
			return $txOk;
		}
		else {
			return "ERR: unknow interface param: $_[0]."
		}
	}
}
sub getDelay
{
	bwDelayLossCheck();
	my $result = `ipfw pipe show`;
	debugOk "result=$result.";
	if ($result =~ m/00001:.*\s+(\d+)\s+ms/){
		my $delay = $1;
		return $delay;
	}else {
		say "ERR: getDelay: no mtach.";
		return "ERR: no regular match.";
	}
}
sub setDelay
{
	bwDelayLossCheck();
	my $delay = $_[0];
	chomp ($delay);
	if (!($delay =~ m/^\d+$/)) {
		return "ERR: allow int only, unit: ms.";
	}
	my $errMsg = '';
	my $bw = getBw();
	if (!($bw > 0)){
		$bw = 10;
		$errMsg = ".setDelay WARNNING: bw not set, using 10 by default.";
	}
	debug "in setDelay, bw=$bw.";
	system ('ipfw -f pipe flush');
	my $returnedValue = system ("ipfw pipe 1 config bw ${bw}Mbit/s delay ${delay}ms pattern $plpFile");
	my $result = getDelay();
	if ( ($result != $delay) || ($returnedValue != 0) ){
		return "ERR: delay is $result, failed to set to $delay.";
	}
	return $result.$errMsg;
}
sub getBw
{
	bwDelayLossCheck();
	my $result = `ipfw pipe show`;
	debugOk "result=$result.";
	$result =~ m/00001:.*\s+(\d+)\.\d+\s+Mbit/;
	my $bw = $1;
	debugOk "bw=$bw.";
	return $bw;
}
sub setBw
{
	bwDelayLossCheck();
	my $bw = $_[0];
	chomp ($bw);
	if ( (!($bw =~ m/^\d+$/)) || ($bw == 0) || ($bw > 100)) {
		return "ERR: allow 1<= x >= 100, int only, unit: Mbit/s.";
	}
	my $errMsg = '';
	my $delay = getDelay();
	if (!($delay >= 0)){
		$delay = 0;
		$errMsg = ".WARNNING: delay not set, using 0 by default.";
	}
	debug "in setBw, delay=$delay.";
	system ('ipfw -f pipe flush');
	my $returnedValue = system ("ipfw pipe 1 config bw ${bw}Mbit/s delay ${delay}ms pattern $plpFile");
	my $result = getBw();
	if ( ($result != $bw) || ($returnedValue) ){
		return "ERR: bw is $result, failed to set to $bw.";
	}
	return $result.$errMsg;
}
sub getLoss
{
	bwDelayLossCheck();
	my $result = `cat $plpTxtFile`;
	chomp ($result);
	return $result;
}
sub setLoss
{
	bwDelayLossCheck();
	my $errMsg = '';
	my $loss = $_[0];
	chomp ($loss);
	#if (!($loss =~ m/^0(\.\d{1,3}){0,1}$/)) {
		#return "ERR: allow 0~1 max 3 decimals only, unit: 1, not %.";
	#}
	if (!($loss =~ m/^0(\.\d{1,2}){0,1}$/)) {
		return "ERR: allow 0~1 max 2 decimals only, unit: 1, not %.";
	}
	my $numberOfPackageLoss= $loss * 100;
	my $lossStart = 100 - $numberOfPackageLoss;
	debug "lossStart=$lossStart.";
	my $lossPattern = `patt_gen -pkt -int $plpFile data 100 $lossStart,100`;
	if ( $lossPattern != 0 ){
		$errMsg += "ERR: setLoss() patt gen fails.";
	}
	my $delay = getDelay();
	if (!($delay >= 0)){
		$delay = 0;
		$errMsg += ".WARNNING: delay not set, using 0 by default.";
	}
	my $bw = getBw();
	if (!($bw > 0)){
		$bw = 10;
		$errMsg += ".setLoss WARNNING: bw not set, using 10 by default.";
	}
	debug "in setLoss, delay=$delay, bw=$bw.";
	system ('ipfw -f pipe flush');
	if (system ("ipfw pipe 1 config bw ${bw}Mbit/s delay ${delay}ms pattern $plpFile")){
		return "ERR: setLoss failed when ipfw.";
	}
	system ("echo $loss > $plpTxtFile");
	my $result = getLoss();
	if ($result != $loss){
		return "ERR: setLoss failed impossible.";
	}
	return "$result,$errMsg";
}
sub bwDelayLossCheck
{
	if (system('ipfw show |grep "pipe 1" > /dev/null') || system('ipfw pipe show |grep "00001" > /dev/null')){
		say "in check, will initialize.";
		system('ipfw del 10');
		system('ipfw add 10 pipe 1 ip from server10 to any layer2');
		system('ipfw -f pipe flush');
		system("echo 0 > $plpTxtFile");
		system("patt_gen -pkt -int $plpFile data 100 100,100");
		system("ipfw pipe 1 config bw 100Mbit/s delay 0ms pattern $plpFile");
	}
	return 0;
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
#sub timestampRfc {
	#my ($sec,$min, $hour, $mday, $mon,$year,$wday,$yday,$isdst);
	#($sec,$min, $hour, $mday, $mon,$year,$wday,$yday,$isdst)=localtime(time);
	#$year+=1900;
	#$mon+=1;
	#return "$year-$mon-$mday"." $hour:$min:$sec";
#}
sub timestampRfc {
	#use POSIX qw/strftime/
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($_[0]);
	$year = $year + 1900;
	return strftime('%Y-%m-%d %H:%M:%S',localtime(time())); 
}

