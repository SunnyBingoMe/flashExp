#/usr/bin/perl
use IO::Socket;
use strict;
use Switch;
#use POSIX qw(strftime);
use std_functions;
use controller_config;

# Declare variables
my $rx_buf;
my $client_socket;
my $exit;
my($command, $value);
my $socket;

# Clear console screen
system('clear');

# Check root permission
checkROOT();

my $scriptStartTime = timestampRfc();
print "\n[$scriptStartTime]\n";

$socket = new IO::Socket::INET (
	#LocalHost => $tcpc_ip,
	LocalPort => $tcpc_port,
	Proto => 'tcp',
	Listen => 1,
	Reuse => 1,
) || die console("Could not create socket: $!");
console("TCP c/s manager is ready");

while(1){
	$client_socket = $socket->accept();
	$exit = 0;
	while($exit == 0){
		# read from socket
		$client_socket->recv($rx_buf,128);
		my $tTime = timestampRfc();
		print "\n[$tTime] \nrxbuf: $rx_buf\n";
		#chomp($rx_buf);
		# extract command
		($command, $value) = extract_cmd($rx_buf);
		# execute command
		print $value;
		exec_cmd();
		#print $value;
		# 1 = drop connection after execute a command, 0 = do not drop
		$exit = 1;
	}
	close($client_socket);
}
close($socket);

sub setCA{
	my $new_CA = $_[0];
	my $result = `sysctl -w net.ipv4.tcp_congestion_control=$new_CA 2>&1`;
	$result =~ /.+= (.+)$/;
	if($1 eq $new_CA){
		cleanup();
		console "The new CA:$new_CA is applied.\n";
		return 1;
	}else{
		console "ERR: Fail to apply CA:$new_CA\n";
		return 0;
	}
}

sub setBUF{
	print "[Debug] $_[0]";
	my $result = `sysctl -w net.ipv4.tcp_rmem='$_[0] $_[0] $_[0]' 2>&1`;
	my $resultW = `sysctl -w net.ipv4.tcp_wmem='$_[0] $_[0] $_[0]' 2>&1`;
	$result =~ /.+ = (\d+)\s+(\d+)\s+(\d+)$/;
	if(($1+$2+$3) eq ($_[0]*3)){
		cleanup();
		console "The new buffer size $_[0] is applied !\n";
		return 1;
	}else{
		console "ERR: Fail to apply buffer size $_[0]\n";

		cleanup();
		console "do not worry, this is for exp 42.\n";
		return 1; # for exp 42

		return 0;
	}
}

sub cleanup{
	my $result = `sysctl -w net.ipv4.route.flush=1 2>&1`;
}

sub exec_cmd{
	switch($command){
		case("setCA"){
			if(setCA($value)){
				$client_socket->send("setCA:".$value);
			}else{
				$client_socket->send("ERR: unable to set CA");
			}
		}
		case("setBUF"){
			if(setBUF($value)){
				$client_socket->send("setBUF:".$value);
			}else{
				$client_socket->send("ERR: unable to set buffer");
			}
		}
		else{
			$client_socket->send("ERR: wrong command:$command.\n");
		}
	}
}

sub timestampRfc { #use POSIX qw/strftime/
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($_[0]?$_[0]:time());
	$year = $year + 1900; $mon = sprintf("%02d", $mon + 1); $mday = sprintf("%02d", $mday);
	$sec = sprintf("%02d", $sec); $min = sprintf("%02d", $min); $hour = sprintf("%02d", $hour);
	return "$year-$mon-$mday $hour:$min:$sec"; 
}

