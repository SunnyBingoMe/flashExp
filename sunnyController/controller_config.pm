package controller_config;
use strict;
use warnings;
use base 'Exporter';

our @EXPORT = qw(
	$controller_ip
	$controller_port

	$tcpc_ip
	$tcpc_port
	$tcps_ip
	$tcps_port
	$shaper_ip
	$shaper_port
	$mp_ip
	$mp_port
	$consumer_ip
	$consumer_port
	$playerManagerIp
	$playerManagerPort

	$db_ip
	$db_port
	$db_user
	$db_pass
	$db_name

	$exp_number
	$test_start_number
	$repeatTime

	$start_tcps_buf
	$stop_tcps_buf
	$step_tcps_buf
	@tcps_buf
	@ca_s

	$start_tcpc_buf
	$stop_tcpc_buf
	$step_tcpc_buf
	@tcpc_buf
	@ca_c
	
	$start_delay
	$stop_delay
	$step_delay
	@delayList
	$start_jitter
	$stop_jitter
	$step_jitter
	@jitterList
	$start_bw
	$stop_bw
	$step_bw
	$start_loss
	$stop_loss
	$step_loss
	
	$start_player_buf
	$stop_player_buf
	$step_player_buf
	@res
);
our @EXPORT_OK = qw(

);

# Exp/Test conditions configuration
# Experimental number
our $exp_number				= 34;
our $test_start_number		= 6001;
our $repeatTime				= 22;

	# S mem size
		our @tcps_buf = (
		1000000,
		);
	# S CA
		our @ca_s = (
		'bic',
		'cubic',
		'reno',
		'highspeed',
		'htcp',
		'westwood',
		'hybla',
		'lp',
		'illinois',
		'scalable',
		'vegas',
		'veno',
		'yeah'
		);

	# C mem size
		our @tcpc_buf = (
		1000000,
		);
	# C CA
		our @ca_c = (
		#"reno",
		"cubic",
		#'bic',
		#"highspeed",
		#"westwood",
		#"htcp",
		);

	# Delay
		#our $start_delay 			= 1;
		#our $stop_delay 			= 270;
		#our $step_delay				= 20;
		our @delayList = (
		100,
		);
	# Jitter 
		#our $start_jitter 			= 10;
		#our $stop_jitter 			= 50;
		#our $step_jitter			= 10;
		our @jitterList = (
			10,20,30,40,50,
		);

	# Bandwidth
		our $start_bw 				= 12;
		our $stop_bw 				= 12;
		our $step_bw				= 9;

	# Loss
		our $start_loss 			= 0;
		our $stop_loss				= 0;
		our $step_loss				= 0.01;

	# Videoplayer's buffer
		our $start_player_buf	= 3;
		our $stop_player_buf	= 3;
		our $step_player_buf	= 1;
	# res
		our @res = (
		#"240",
		#"300",
		#"480",
		#"720",
		"1080p",
		);

# Controller
	our $controller_ip 		= "router";
	#our $controller_ip 			= "192.168.34.134";
	our $controller_port 		= 9001;

# TCPC manager
	#our $tcpc_ip 						= "192.168.34.134";
	our $tcpc_ip 						= "client";
	our $tcpc_port 					= 9000;

# TCPS manager
	#our $tcps_ip 						= "192.168.34.134";
	our $tcps_ip 						= "server";
	our $tcps_port 					= 9000;

# Shaper manager
	our $shaper_ip 					= "shaper";
	our $shaper_port 				= 9000;

# Setting for MP manager
	our $mp_ip 							= "mp";
	our $mp_port 							= 9000;

# Setting for consumer manager
	our $consumer_ip 							= "consumer";
	our $consumer_port 							= 9000;

# Setting for player manager
	our $playerManagerIp		= "client";
	our $playerManagerPort		= 9001;

# Database configuration
	our $db_ip							= "localhost";
	our $db_port 						= "3306";
	our $db_user 						= 'marc';
	our $db_pass 						= 'konko';
	our $db_name 	  				= "marc";
1;

