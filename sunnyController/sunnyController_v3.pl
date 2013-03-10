#/usr/bin/perl
use IO::Socket;
use strict;
use Switch;
use POSIX qw/strftime/;
use std_functions;
use controller_config;


my $scriptStartTimestamp = timestampUnderLine(time());

my $ARGC = scalar(@ARGV);
# timeout check. solution: fork & wait pid
if($ARGC > 0){
	my $tArgvIndex = 0;
}



# Declare variables
	my $connect = connectMYSQL();
	my ($query,$queryHANDLE);
	my $sProcess = 'NA'; # current function / process name.

	# Test configurations
	#my $exp_number;
	my $test_number;
	my $traceFile;
	my $startTestTime;

	# Configuration
	my $cur_delay;
	my $cur_jitter;
	my $cur_bw;
	my $cur_loss;
	my $cur_c_ca;
	my $cur_s_ca;
	my $cur_tcpc_buf;
	my $cur_tcps_buf;
	my $cur_player_buf;
	my $cur_res;	

	# Result
	my $init_buf;
	my $m_rebuf_time;
	my $rebuf_count;
	my $stat_loss;
	my $stat_delay;

	# Others
	my ($cmdInput,$command,$value);
	my $rx_buf;
	my $socket_videoplayer;
# Reset test
	default_config();
	#setConfig();
	reset_result();
	#checkManagers();
	#system('clear'); # clear screen

startPlayer();
$socket_videoplayer = Connect_Videoplayer(); # Waiting for video player connection
setRES('1080p');
setPBUF('3');

while(1){
	if ($ARGC == 0){
		print "<- ";
		$cmdInput = <STDIN>;
		#chomp($cmdInput);
	}else{
		$cmdInput = $ARGV[$tArgvIndex];
	}

	($command, $value) = extract_cmdInput($cmdInput);

	switch($command){
		case("show"){
			show();
		}
		case("play"){
			play();
			show();
		}
		case("playDebug"){
			$socket_videoplayer->send("play:\n");
			$socket_videoplayer->recv($rx_buf,128);
			console("Videoplayer return: $rx_buf");
		}
		case("setRES"){
			if(setRES($value)==1){
					$cur_res = $value;
					reset_result();
			}
		}
		case("setCCA"){
			if(setCCA($value)==1){
					$cur_c_ca = $value;
					reset_result();
			}
		}
		case("setSCA"){
			if(setSCA($value)==1){
					$cur_s_ca = $value;
					reset_result();
			}
		}
		case("setSBUF"){
			if(setSBUF($value)==1){
					$cur_tcps_buf = $value;
					reset_result();
			}
		}
		case("setCBUF"){
			if(setCBUF($value)==1){
				$cur_tcpc_buf = $value;
				reset_result();
			}
		}
		case("setPBUF"){
			if(setPBUF($value)==1){
					$cur_player_buf = $value;
					reset_result();
			}
		}
		case("setLoss"){
			if(setLoss($value)==1){
					$cur_loss = $value;
					reset_result();
			}
		}
		case("setBw"){
			if(setBw($value)==1){
					$cur_bw = $value;
					reset_result();
			}
		}
		case("startTest"){
				$value =~ /^(.+)-(.*)$/;
				consoleNlog("Start: $1 Stop: $2");
				startTest($1, $2);
		}
		case("exit"){
			exitController();
		}
		else{
			console("CRAP:ERR: Unknow command $command");
		}
	}

	if ($ARGC != 0){
		$tArgvIndex = 1 + $tArgvIndex;
		if ($tArgvIndex == $ARGC){
			play();
			last;
		}
	}
}

exitController();

sub exitController(){
	close($socket_videoplayer);
	exit(0);
}

sub startTest{
	$connect = connectMYSQL();
	my $startTest = $_[0];
	my $stopTest 	= $_[1];
	$test_number = $startTest;
	while($test_number <= $stopTest){
		$query = "SELECT * FROM `".$db_name."`.`exp_".$exp_number."` WHERE `test_number` = '".$test_number."'";
		$queryHANDLE = $connect->prepare($query);
		$queryHANDLE->execute() or die "Unable to execute : $queryHANDLE::errstr\n";
		my @temp = $queryHANDLE->fetchrow_array;
		$cur_tcps_buf 		= $temp[7];
		$cur_s_ca 			= $temp[8];
		$cur_tcpc_buf 		= $temp[9];
		$cur_c_ca 			= $temp[10];

		$cur_loss 			= $temp[11];
		$cur_bw 			= $temp[12];
		$cur_delay 			= $temp[13];
		$cur_jitter 		= $temp[14];
		$cur_player_buf 	= $temp[15];
		$cur_res			= $temp[16];
		play();
		my $tTimestamp = timestampRfc($startTestTime);
		$query = "UPDATE `$db_name`.`exp_$exp_number` SET `start_test_time`='$tTimestamp', `init_buf_time`='$init_buf', `m_rebuf_time`='$m_rebuf_time',`rebuf_count`='$rebuf_count', `stat_loss`='$stat_loss', `stat_delay`='$stat_delay' WHERE `test_number`='$test_number' ";
		$queryHANDLE = $connect->prepare($query);
		$queryHANDLE->execute() or die "Unable to execute : $queryHANDLE::errstr\n";
		show();
		startPlayer();
		$socket_videoplayer = Connect_Videoplayer();
		$test_number++;
	}
	setRES('1080p');
	setPBUF('3');
	$test_number--;
	system ("perl email.pl done$exp_number.$test_number");
	system ("echo '' >> /home/ats/thesis/dropbox_sync_fs/EE-getConsumerPid.log");
}

sub play{
	$sProcess = 'play';
	$startTestTime = time();
	#show(); # review config

	if(!setConfig()){
		consoleNlog("ERR: fail to set configs");
		return 1;
	}
	#if(!syncMP()){
		#consoleNlog("ERR: fail to sync MP");
		#return 1;
	#}
	#if(!startConsumer($startTestTime)){
		#consoleNlog("ERR: fail to start consumer");
		#exit;
	#}

	# play
	$socket_videoplayer->send("play:");
	$socket_videoplayer->recv($rx_buf,128);
	consoleNlog("Player return: $rx_buf");

	# get result
	if(foundERR($rx_buf)){
		consoleNlog("ERR: returned result is invalid.");
	}else{
		($init_buf,$rebuf_count,$m_rebuf_time) = extract_qod($rx_buf);
	}
	stopPlayer();
	#if(!stopConsumer()){
		#consoleNlog("ERR: fail to stop Consumer");
		#exit;
	#}
	#$stat_loss = getStatLoss();
	#print "getStatLoss->:$stat_loss";
	#$stat_delay = getStatDelay();
	#print "getStatDelay:$stat_delay";
}

#sub startMp{
	#$traceFile = "e".$exp_number."\/e".$exp_number."_t".$test_number."_".timestampUnderLine($_[0]).".cap";
	#my $socket = MP_manager();
	#$socket->send("startMp:".$traceFile."\n");
	#$socket->recv($rx_buf,256);
	#consoleNlog("MP return: $rx_buf");
	#close($socket);
	#if(foundERR($rx_buf)){
		#return 0;
	#}else{
		#return 1;
	#}
#}

sub startConsumer{
	$sProcess = 'startConsumer';
	$traceFile = "e".$exp_number."_$scriptStartTimestamp\/e".$exp_number."_t".$test_number."_".timestampUnderLine($_[0]); # this is only the file prefix
	my $socket = Consumer_manager();
	$socket->send("startConsumer:".$traceFile."\n");
	$socket->recv($rx_buf,256);
	consoleNlog("consumer return: $rx_buf");
	close($socket);
	if(foundERR($rx_buf)){
		return 0;
	}else{
		return 1;
	}
}
sub startPlayer{
	$sProcess = 'startPlayer';
	my $socket = Player_manager();
	$socket->send("startPlayer:".$traceFile."\n");
	$socket->recv($rx_buf,256);
	consoleNlog("Player_manager return: $rx_buf");
	close($socket);
	if(foundERR($rx_buf)){
		return 0;
	}else{
		return 1;
	}
}


#sub stopMp{
	#my $socket = MP_manager();
	#$socket->send("stopMp:\n");
	#$socket->recv($rx_buf,256);
	#consoleNlog("MP return: $rx_buf");
	#close($socket);
	#if(foundERR($rx_buf)){
		#return 0;
	#}else{
		#return 1;
	#}
#}

sub stopConsumer{
	$sProcess = 'stopConsumer';
	my $socket = Consumer_manager();
	$socket->send("stopConsumer:\n");
	$socket->recv($rx_buf,256);
	consoleNlog("consumer return: $rx_buf");
	close($socket);
	if(foundERR($rx_buf)){
		return 0;
	}else{
		return 1;
	}
}
sub stopPlayer{
	$sProcess = 'stopPlayer';
	my $socket = Player_manager();
	$socket->send("stopPlayer:\n");
	$socket->recv($rx_buf,256);
	consoleNlog("Player_manager return: $rx_buf");
	close($socket);
	if(foundERR($rx_buf)){
		return 0;
	}else{
		return 1;
	}
}

sub getStatLoss{
	$sProcess = 'getStatLoss';
	my $socket = Consumer_manager();
	$socket->send("getStatLoss:".$traceFile."\n");
	$socket->recv($rx_buf,256);
	consoleNlog("consumer return: $rx_buf");
	close($socket);
	if(foundERR($rx_buf)){
		return $rx_buf;
	}else{
		$rx_buf =~ /:(.+)/;
		return $1;
	}
}

sub getStatDelay{
	$sProcess = 'getStatDelay';
	my $socket = Consumer_manager();
	$socket->send("getStatDelay:".$traceFile."\n");
	$socket->recv($rx_buf,256);
	consoleNlog("consumer return: $rx_buf");
	close($socket);
	if(foundERR($rx_buf)){
		return $rx_buf;
	}else{
		$rx_buf =~ /:(.+)/;
		return $1;
	}
}

sub setSBUF{
	$sProcess = 'setSBUF';
	my $socket = TCPS_manager();
	$socket->send("setBUF:".$_[0]);
	$socket->recv($rx_buf,128);
	consoleNlog("TCPS return: $rx_buf");
	close($socket);
	if(foundERR($rx_buf)){
		return 0;
	}else{
		return 1;
	}
}
sub setSCA{
	$sProcess = 'setSCA';
	my $socket = TCPS_manager();
	$socket->send("setCA:".$_[0]);
	$socket->recv($rx_buf,128);
	consoleNlog("TCPS return: $rx_buf");
	close($socket);
	if(foundERR($rx_buf)){
		return 0;
	}else{
		return 1;
	}
}
sub setCBUF{
	$sProcess = 'setCBUF';
	my $socket = TCPC_manager();
	$socket->send("setBUF:".$_[0]);
	$socket->recv($rx_buf,128);
	consoleNlog("TCPC return: $rx_buf");
	close($socket);
	if(foundERR($rx_buf)){
		return 0;
	}else{
		return 1;
	}
}
sub setCCA{
	$sProcess = 'setCCA';
	my $socket = TCPC_manager();
	$socket->send("setCA:".$_[0]);
	$socket->recv($rx_buf,128);
	consoleNlog("TCPC return: $rx_buf");
	close($socket);
	if(foundERR($rx_buf)){
		return 0;
	}else{
		return 1;
	}
}
sub setPBUF{
	$sProcess = 'setPBUF';
	$socket_videoplayer->send("setPBUF:".$_[0]);
	$socket_videoplayer->recv($rx_buf,128);
	consoleNlog("Videoplayer return: $rx_buf");
	if(foundERR($rx_buf)){
		return 0;
	}else{
		return 1;
	}
}
sub setRES{
	$sProcess = 'setRES';
	$sProcess = 'setRES';
	#$_[0] = '300'; # tmp hot fix: sunny.
	if ($_[0] == '360p'){
		$_[0] = '300';
	}
	print "sunny hot fix, will setRES: $_[0]";
	$socket_videoplayer->send("setRES:".$_[0]);
	$socket_videoplayer->recv($rx_buf,128);
	consoleNlog("Videoplayer return: $rx_buf");
	if(foundERR($rx_buf)){
		return 0;
	}else{
		return 1;
	}
}

sub setDelay{
	$sProcess = 'setDelay';
	my $socket = Shaper_manager();
	$socket->send("setDelay:".$_[0]."\n");
	$socket->recv($rx_buf,128);
	consoleNlog("Shaper return: $rx_buf");
	close($socket);
	if(foundERR($rx_buf)){
		return 0;
	}else{
		return 1;
	}
}
sub setJitter{
	$sProcess = 'setJitter';
	my $socket = Shaper_manager();
	$socket->send("setJitter:".$_[0]."\n");
	$socket->recv($rx_buf,128);
	consoleNlog("returned: $rx_buf");
	close($socket);
	if(foundERR($rx_buf)){
		return 0;
	}else{
		return 1;
	}
}
sub setLoss{
	$sProcess = 'setLoss';
	my $socket = Shaper_manager();
	$socket->send("setLoss:".$_[0]."\n");
	$socket->recv($rx_buf,128);
	consoleNlog("Shaper return: $rx_buf");
	close($socket);
	if(foundERR($rx_buf)){
		return 0;
	}else{
		return 1;
	}
}
sub setBw{
	$sProcess = 'setBw';
	my $socket = Shaper_manager();
	$socket->send("setBw:".$_[0]."\n");
	$socket->recv($rx_buf,128);
	consoleNlog("Shaper return: $rx_buf");
	close($socket);
	if(foundERR($rx_buf)){
		return 0;
	}else{
		return 1;
	}
}

# ######################################
sub setConfig{
	if(
		setSBUF($cur_tcps_buf) &&
		setSCA($cur_s_ca) &&
		setCBUF($cur_tcpc_buf) &&
		setCCA($cur_c_ca) &&
		setPBUF($cur_player_buf) &&

		#&&
		setDelay($cur_delay) &&
		setJitter($cur_jitter) &&
		setLoss($cur_loss) &&
		setBw($cur_bw) &&

		setRES($cur_res)
	){
		return 1;
	}else{
		return 0;
	}
}

sub show{
	#system('clear');
	print "\n############# start: test done summary. ############\n";
	print "Start:".timestampRfc($startTestTime)."\n";
	print "file :$traceFile\n";
	print "exp  :$exp_number\n";
	print "test :$test_number\n";
	print "\n            ### Result:\n";
	print "Init buf time:$init_buf ms.\n";
	print "Mean re time :$m_rebuf_time ms.\n";
	print "Re-buf count :$rebuf_count times\n";
	print "stat loss    :$stat_loss (unit: 1)\n";
	print "stat delay   :$stat_delay (min/avg/max/std)\n";
	print "\n            ### With Config:\n";
	print "sBuf:  $cur_tcps_buf Kb.\n";
	print "sCa :  $cur_s_ca\n";
	print "cBuf:  $cur_tcpc_buf Kb.\n";
	print "cCa :  $cur_c_ca\n";
	print "delay: $cur_delay ms.\n";
	print "jitter:$cur_jitter ms.\n";
	print "bw  :  $cur_bw Mbps\n";
	print "loss:  $cur_loss %\n";
	print "pBuf:  $cur_player_buf second\n";
	print "res :  $cur_res\n";
	print "############# end: test done summary. ##############\n\n";
}

sub reset_result{
	$startTestTime	= 0;
	$init_buf 			="";
	$m_rebuf_time		="";
	$rebuf_count		="";
	$traceFile			="";
}

sub default_config{
	# Default config
	#$exp_number 			= 3;
	$test_number 			= 1;
	$cur_delay 				= 0;
	$cur_bw 					= 11;
	$cur_loss 				= 0;
	$cur_c_ca 				= "reno";
	$cur_s_ca 				= "reno";
	$cur_tcpc_buf 		= 4096;
	$cur_tcps_buf 		= 4096;
	$cur_player_buf 	= 4;
	$cur_res 					= 360;
}

sub foundERR{
	if ($_[0] =~ /EE/){
		my $emailSubject = "$traceFile: controller got: ".$_[0];
		chomp ($emailSubject);
		system ("perl email.pl EE:$exp_number.$test_number.$sProcess.".timestampUnderLine());
		print "EE found.";
	}
	if ($_[0] =~ /ERR/){
		my $emailSubject = "$traceFile: controller got: ".$_[0];
		chomp ($emailSubject);
		system ("perl email.pl ERR:$exp_number.$test_number.$sProcess.".timestampUnderLine());
		print "ERR found, press any key to continue.";
		#<>;
		return 0;
	}else{
		return 0;
	}
}

sub syncMP{
	return 1;
}

sub extract_cmdInput{
	chomp($_);
	$_[0] =~ /^([a-zA-Z]+):(.*)$/; # $1 = command ; $2 = value
	return ($1,$2);
}

sub extract_qod{
	$_[0] =~ /^(.+)-(.*)-(.*)$/;
	# $1 = initial buffering time
	# $2 = re-buffering count
	# $3 = mean re-buffering time 
	return ($1,$2,$3);
}

sub timestampUnderLine{
	return strftime('%Y%m%d_%H%M%S',localtime($_[0]?$_[0]:time()));
}

sub Connect_Videoplayer{
	my $socket = new IO::Socket::INET (
		LocalHost => $controller_ip,
		LocalPort => $controller_port,
		Proto => 'tcp',
		Listen => 1,
		Reuse => 1);
	die consoleNlog("Could not connect Videoplayer: $!\n") unless $socket;
	consoleNlog("Waiting for vido player to connect ...");
	my $new_socket = $socket->accept();
	consoleNlog("video player connected.");
	# Close unused socket
	close($socket);
	return $new_socket;
}

sub MP_manager{
	# Setting for MP manager
	my $IP 		= $mp_ip;
	my $PORT 	=	$mp_port;

	my $socket = new IO::Socket::INET (PeerAddr => $IP, PeerPort => $PORT, Proto => 'tcp');
	die consoleNlog("Could not connect MP: $!") unless $socket;
	return $socket;
}

sub Consumer_manager{
	my $IP 		= $consumer_ip;
	my $PORT 	=	$consumer_port;
	my $socket = new IO::Socket::INET (PeerAddr => $IP, PeerPort => $PORT, Proto => 'tcp') || die consoleNlog("Could not connect MP: $!");
	return $socket;
}

sub Shaper_manager{
	# Setting for Shaper manager
	my $IP 		= $shaper_ip;
	my $PORT 	=	$shaper_port;

	my $socket = new IO::Socket::INET (PeerAddr => $IP, PeerPort => $PORT, Proto => 'tcp');
	die consoleNlog("Could not connect Shaper: $!") unless $socket;
	return $socket;
}

sub TCPC_manager{
	# Setting for TCPC manager
	my $IP 		= $tcpc_ip;
	my $PORT 	= $tcpc_port;

	my $socket = new IO::Socket::INET (PeerAddr => $IP, PeerPort => $PORT, Proto => 'tcp');
	die consoleNlog("Could not connect TCPC: $!") unless $socket;
	return $socket;
}
sub Player_manager{
	my $IP 		= $playerManagerIp;
	my $PORT 	= $playerManagerPort;

	my $socket = new IO::Socket::INET (PeerAddr => $IP, PeerPort => $PORT, Proto => 'tcp');
	die consoleNlog("Could not connect player_manager: $!") unless $socket;
	return $socket;
}


sub TCPS_manager{
	# Setting for TCPS manager
	my $IP 		= $tcps_ip;
	my $PORT 	=	$tcps_port;

	my $socket = new IO::Socket::INET (PeerAddr => $IP, PeerPort => $PORT, Proto => 'tcp');
	die consoleNlog("Could not connect TCPS: $!") unless $socket;
	return $socket;
}

sub checkManagers{
	my $socket;
	$socket = TCPC_manager();
	$socket = TCPS_manager();
	$socket = Shaper_manager();
	$socket = MP_manager();
	$socket = Consumer_manager();
}
sub timestampRfc {
	#my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($_[0]);
	#$year = $year + 1900;
	return strftime('%Y-%m-%d %H:%M:%S',localtime(time())); 
}

