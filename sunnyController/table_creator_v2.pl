#!/usr/local/bin/perl -w
use strict;
use DBI;
use std_functions;
use controller_config;

## Declare variables
our $cur_delay;
our $cur_jitter;
our $cur_bw;
our $cur_loss;
our $cur_c_ca;
our $cur_s_ca;
our $cur_tcpc_buf;
our $cur_tcps_buf;
our $cur_player_buf;
our $cur_res;
our $test_number = $test_start_number - 1;
our $start_test_number;
our $table_duplicate = 0;

# CONNECT TO MSSQL
our $connect = connectMYSQL();
our ($query,$queryHANDLE);

# Chek duplicate table
if(checkTable($exp_number)){
	console("Duplicate experimental number. Delete existing data? [y/N]");
	my $userinput = <>; chomp($userinput);
	if($userinput eq "y"){
		# Drop duplicate table
		dropTable($exp_number);
		consoleNlog("Delete exp_$exp_number");
		createTable($exp_number);
	}
}else{
	createTable($exp_number);
}


our $repeatIndex = 1;

# Resolution
foreach $cur_res(@res){ # Resolution
	foreach $cur_s_ca(@ca_s){ # S CA
		foreach $cur_c_ca(@ca_c){ # C CA
			foreach $cur_tcps_buf(@tcps_buf){ # S TCP buffer size
				foreach $cur_tcpc_buf (@tcpc_buf){
					for ($cur_player_buf = $start_player_buf; $cur_player_buf <= $stop_player_buf; $cur_player_buf = $cur_player_buf + $step_player_buf){
						foreach $cur_delay (@delayList){
							foreach $cur_jitter (@jitterList){ # Jitter
								for ($cur_bw = $start_bw; $cur_bw <= $stop_bw; $cur_bw = $cur_bw + $step_bw){               # Bandwidth
									for ($cur_loss = $start_loss; $cur_loss <= $stop_loss; $cur_loss = $cur_loss + $step_loss){ # Loss
										for ($repeatIndex = 1; $repeatIndex <= $repeatTime; $repeatIndex ++){
											$test_number++;
											print "[Exp $exp_number: $test_number]\tRes:$cur_res\tSCA:$cur_s_ca\tCCA:$cur_c_ca\tSBUF:$cur_tcps_buf\tCBUF:$cur_tcpc_buf\tPBUF:$cur_player_buf\tDELAY:$cur_delay\tJitter:$cur_jitter\tBW:$cur_bw\tLOSS:$cur_loss\n";
											writeConfig();
										}
									}
								}
							}
						}
					}
				}
			}
		}
	}
}


sub writeConfig{
	$query = "INSERT INTO `".$db_name."`.`exp_$exp_number`(
		`start_test_time`,
		`test_number`,
		`init_buf_time`,
		`m_rebuf_time`,
		`rebuf_count`,
		`stat_loss`,
		`stat_delay`,
		`server_socket_size`,
		`server_ca`,
		`client_socket_size`,
		`client_ca`,
		`network_loss`,
		`network_bandwidth`,
		`network_delay`,
		`network_jitter`,
		`player_buffer`,
		`player_resolution`,
		`note`
	) VALUES (
		FROM_UNIXTIME(1),
		'$test_number',
		NULL,
		NULL,
		NULL,
		NULL,
		NULL,
		'$cur_tcps_buf',
		'$cur_s_ca',
		'$cur_tcpc_buf',
		'$cur_c_ca',
		'$cur_loss',
		'$cur_bw',
		'$cur_delay',
		'$cur_jitter',
		'$cur_player_buf',
		'$cur_res',
		NULL
	)";
	#print "$query\n.";
	$queryHANDLE = $connect->prepare($query);
	$queryHANDLE->execute() || die "ERR: db exec: $queryHANDLE->errstr.";
}

sub checkTable{
	$query = "SELECT COUNT(*)FROM information_schema.tables WHERE table_schema = '".$db_name."' AND table_name = 'exp_".$_[0]."'";
	$queryHANDLE = $connect->prepare($query);
	$queryHANDLE->execute() or console("Unable to execute : $query_handle::errstr\n");
	my $table_exist_flag = $queryHANDLE->fetchrow_array;
	return $table_exist_flag;
}

sub dropTable{
	$query = "DROP TABLE ".$db_name.".exp_".$_[0];
	$queryHANDLE = $connect->prepare($query);
	$queryHANDLE->execute() or console("Unable to execute : $query_handle::errstr\n");
}

sub createTable{
	$query = "CREATE TABLE `".$db_name."`.`exp_".$_[0]."` (
	`start_test_time` timestamp NOT NULL default CURRENT_TIMESTAMP,
	`test_number` 						INT,
	`init_buf_time` 					INT,
	`m_rebuf_time` 						INT,
	`rebuf_count` 						INT,
	`stat_loss` 						VARCHAR(100),
	`stat_delay` 						VARCHAR(200),
	`server_socket_size` 				INT,
	`server_ca` 						VARCHAR(100),
	`client_socket_size`				INT,
	`client_ca` 						VARCHAR(100),
	`network_loss` 						FLOAT,
	`network_bandwidth` 				INT,
	`network_delay` 					INT,
	`network_jitter` 					INT,
	`player_buffer` 					INT,
	`player_resolution` 				VARCHAR(20),
	`note` 								VARCHAR(200)
	)";
	$queryHANDLE = $connect->prepare($query);
	$queryHANDLE->execute() or console("Unable to execute : $query_handle::errstr\n");
}

sub connectMYSQL{	
	my $dsn = "dbi:mysql:$db_name:$db_ip:$db_ip";
	my $connect = DBI->connect($dsn, $db_user, $db_pass) or die "Unable to connect: $DBI::errstr\n";
	return $connect;
}

