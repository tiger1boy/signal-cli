#!/usr/bin/perl

## PERL event loop (EV) driven interface for signal-cli

# Non standard module dependencies: 
#	EV

# /**
#  * Copyright (C) 2017 Carl Bingel
#  *
#  * This program is free software: you can redistribute it and/or modify
#  * it under the terms of the GNU General Public License as published by
#  * the Free Software Foundation, either version 3 of the License, or
#  * (at your option) any later version.
#  *
#  * This program is distributed in the hope that it will be useful,
#  * but WITHOUT ANY WARRANTY; without even the implied warranty of
#  * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  * GNU General Public License for more details.
#  *
#  * You should have received a copy of the GNU General Public License
#  * along with this program.  If not, see <http://www.gnu.org/licenses/>.
#  */

package SignalCLI;

use strict;
use EV;
use IPC::Open2;
use IPC::Open3;
use JSON;
use Data::Dumper;

##
##	opts:
##		telephone_number	(MANDATORY) Telephone number of account to logon to signal-cli service as (user must already be registered)
##		signal_cli_executable (Optional) Path to signal-cli executable, default to current build path (../build/install/signal-cli/bin/signal-cli) TODO: fix this to better default
##		ev_loop				(Optional) EV loop object, defaulting to "default event loop"
##		debug 				(Optional) Turn on debug logging (to stderr)
##		debug_io			(Optional) Dump all incoming/outgoing JSON data structures
##
sub new {
	my( $class, %opts) = @_;

	my $self = { 'opts' => \%opts};
	bless $self;

	if( !defined $opts{'telephone_number'} || $opts{'telephone_number'} eq "") {
		print STDERR "SignalCLI.pm: ERROR: telephone_number must be specified to start signal-cli\n";
		exit(1);
	}
	$self->{'debug'} = $opts{'debug'};
	$self->{'debug_io'} = $opts{'debug_io'};

	## Default event handlers
	$self->{'cblist'}->{'message'} = 
	$self->{'cblist'}->{'groupMessage'} = sub {
		my($request) = @_;
		$self->handle_incoming_message($request);
	};
	$self->{'cblist'}->{'error'} = sub {
		my($request) = @_;
		$self->handle_error($request);
	};
	$self->{'cblist'}->{'result'} = sub {
		my($request) = @_;
		$self->handle_result($request);
	};
	$self->{'cblist'}->{'receipt'} = sub {
		my($request) = @_;
		$self->handle_receipt($request);
	};
	$self->{'cblist'}->{'jsonevtloop_alive'} = sub {
		$self->{'last_alive'} = localtime();
	};
	$self->{'cblist'}->{'jsonevtloop_exit'} = sub {
	};
	$self->{'cblist'}->{'groupInfo'} = sub {
		my( $request) = @_;
		$self->handle_groupInfo($request);
	};


	##
	##	Build cmdline and execute signal-cli in background
	##
	my @cmdline = (
		(defined $opts{'signal_cli_executable'}) ? $opts{'signal_cli_executable'} : '../build/install/signal-cli/bin/signal-cli',
		'-u',
		$opts{'telephone_number'},
		'jsonevtloop'
	);

	## Start child signal-cli process
	#$self->{'signal_pid'} = open3( $self->{'signal_cli_stdin'}, $self->{'signal_cli_stdout'}, $self->{'signal_cli_stderr'}, @cmdline) || die "SignalCLI.pm: ERROR: Could not execute signal-cli: ".$!."\n";
	$self->{'signal_pid'} = open2( $self->{'signal_cli_stdout'}, $self->{'signal_cli_stdin'}, @cmdline) || die "SignalCLI.pm: ERROR: Could not execute signal-cli: ".$!."\n";

	binmode( $self->{'signal_cli_stdout'}, ":raw");
	binmode( $self->{'signal_cli_stdin'}, ":raw");

	$self->{'ev_loop'} = (defined $opts{'ev_loop'}) ? $opts{'ev_loop'} : EV::default_loop;

	## Add STDOUT watcher to child process
	$self->{'signal_stdout_watcher'} = $self->{'ev_loop'}->io( $self->{'signal_cli_stdout'}, EV::READ, sub {
		my( $w, $revents) = @_;
		#my $line = <$self->{'signal_cli_stdout'}>;
		my $line = readline( $self->{'signal_cli_stdout'});
		#my $line;
		chomp($line);
		return if( $line eq "");
		print STDERR "DEBUG(JSON-IN): ".$line."\n" if( $self->{'debug_io'});
		if( $line ne "") {
			my $msg = decode_json($line);
			#my $msg = from_json($line);
			if( $msg) { 
				$self->handle_incoming($msg);
			}
		} else {
			print STDERR "DEBUG(JSON-IN): Empty string received\n";
		}
	});

#	$self->{'signal_stderr_watcher'} = $self->{'ev_loop'}->io( $self->{'signal_cli_stderr'}, EV::READ, sub {
#		my($w, $revents) = @_;
#		my $l = readline( $self->{'signal_cli_stderr'});
#		print STDERR "WARNING(signal-cli-stderr): ".$l;
#	});

	## Add watcher for child termination (upon which we exit unless otherwise told)
	$self->{'child_watcher'} = $self->{'ev_loop'}->child( $self->{'signal_pid'}, 666, sub {
		my( $w, $revents) = @_;
		print STDERR "SignalCLI.pm: signal-cli child process died, exiting\n";
		waitpid( $self->{'signal_pid'}, 0);
		my $exit_value = 0;
		if( $self->{'cblist'}->{'cleanup'}) {
			$exit_value = &{$self->{'cblist'}->{'cleanup'}}();
		}
		exit($exit_value);
	});

	return $self;
}

## get EV (Event Loop) instance
sub EV {
	my($self) = @_;
	return $self->{'ev_loop'};
}

sub submit_request {
	my( $self, $request) = @_;
	my $json = encode_json($request);
	print STDERR "DEBUG(JSON-OUT): ".$json."\n" if( $self->{'debug_io'});
	print {$self->{'signal_cli_stdin'}} $json."\n";
}

## EXAMPLES of incoming messages

# direct message
# {
#   'type' => 'message',
#   'envelope' => {
#                   'timestampISO' => '2017-06-20T13:26:06.829Z',
#                   'callMessage' => undef,
#                   'isReceipt' => bless( do{\(my $o = 0)}, 'JSON::XS::Boolean' ),
#                   'syncMessage' => undef,
#                   'sourceDevice' => 1,
#                   'timestamp' => '1497965166829',
#                   'dataMessage' => {
#                                      'message' => 'Test ',
#                                      'attachments' => [],
#                                      'expiresInSeconds' => 0,
#                                      'timestamp' => '1497965166829',
#                                      'groupInfo' => undef
#                                    },
#                   'relay' => undef,
#                   'source' => '+1234'
#                 }
# };

# group message
# {
# 	'envelope' => {
# 	              'relay' => undef,
# 	              'callMessage' => undef,
# 	              'sourceDevice' => 1,
# 	              'timestamp' => '1497966451171',
# 	              'syncMessage' => undef,
# 	              'dataMessage' => {
# 	                                 'expiresInSeconds' => 86400,
# 	                                 'attachments' => [],
# 	                                 'message' => 'Grupp',
# 	                                 'timestamp' => '1497966451171',
# 	                                 'groupInfo' => {
# 	                                                  'name' => 'testgruppen testabbet w',
# 	                                                  'members' => undef,
# 	                                                  'groupId' => 'hyo+GHM6IlVAxab348n6kQ==',
# 	                                                  'type' => 'DELIVER'
# 	                                                }
# 	                               },
# 	              'timestampISO' => '2017-06-20T13:47:31.171Z',
# 	              'source' => '+1234',
# 	              'isReceipt' => bless( do{\(my $o = 0)}, 'JSON::XS::Boolean' )
# 	            },
# 	'type' => 'message'
# };

# group message with attachment
# {
#     "type": "message",
#     "envelope": {
#     "callMessage": null,
#     "source": "+1234",
#     "sourceDevice": 1,
#     "relay": null,
#     "timestamp": 1498034590185,
#     "timestampISO": "2017-06-21T08:43:10.185Z",
#     "isReceipt": false,
#     "dataMessage": {
#         "groupInfo": {
#             "type": "DELIVER",
#             "name": "testgruppen testabbet",
#             "members": null,
#             "groupId": "hyo+GHM6IlVAxab348n6kQ=="
#         },
#         "attachments": [
#             {
#                 "storedFilename": "/home/kk/.config/signal/attachments/3418098425625037690",
#                 "size": 3803076,
#                 "id": 3418098425625038000,
#                 "contentType": "image/jpeg"
#             }
#         ],
#         "expiresInSeconds": 86400,
#         "message": "",
#         "timestamp": 1498034590185
#     },
#     "syncMessage": null
#     }
# }


# receipt
# {
#   'envelope' => {
#                   'isReceipt' => bless( do{\(my $o = 1)}, 'JSON::XS::Boolean' ),
#                   'sourceDevice' => 3,
#                   'source' => '+1234',
#                   'relay' => undef,
#                   'timestampISO' => '2017-06-20T13:38:32.617Z',
#                   'timestamp' => '1497965912617',
#                   'callMessage' => undef,
#                   'syncMessage' => undef,
#                   'dataMessage' => undef
#                 },
#   'type' => 'message'
# };

# groupInfo
# {
#   'type' => 'message',
#   'envelope' => {
#       'timestampISO' => '2017-06-20T15:35:21.091Z',
#       'timestamp' => '1497972921091',
#       'sourceDevice' => 1,
#       'source' => '+1234',
#       'dataMessage' => {
#                          'message' => '',
#                          'attachments' => [],
#                          'expiresInSeconds' => 0,
#                          'groupInfo' => {
#                                           'name' => 'testgruppen testabbet',
#                                           'groupId' => 'hyo+GHM6IlVAxab348n6kQ==',
#                                           'members' => [
#                                                          '+1234',
#                                                          '+2345'
#                                                        ],
#                                           'type' => 'UPDATE'
#                                         },
#                          'timestamp' => '1497972921091'
#                        },
#       'relay' => undef,
#       'callMessage' => undef,
#       'isReceipt' => bless( do{\(my $o = 0)}, 'JSON::XS::Boolean' ),
#       'syncMessage' => undef
#     }
# };


sub handle_incoming {
	my( $self, $msg) = @_;

	print STDERR "DEBUG(JSON-Parsed Dump): ".Dumper($msg)."\n" if( $self->{'debug_io'});
	
	##
	## Determine message type and refine event to: message, groupMessage, receipt, groupInfo
	##
	if( $msg->{'type'} eq "message" && exists $msg->{'envelope'}->{'dataMessage'} && $msg->{'envelope'}->{'dataMessage'}->{'groupInfo'} && $msg->{'envelope'}->{'dataMessage'}->{'groupInfo'}->{'type'} eq "UPDATE") {
		$msg->{'type'} = "groupInfo";
	} elsif( $msg->{'type'} eq "message" && exists $msg->{'envelope'}->{'dataMessage'} && $msg->{'envelope'}->{'dataMessage'}->{'groupInfo'}) {
		$msg->{'type'} = "groupMessage";
	} elsif( $msg->{'type'} eq "message" && $msg->{'envelope'}->{'isReceipt'}) {
		$msg->{'type'} = "receipt";
	}
	print STDERR "DEBUG: msg->{'type'}: ".$msg->{'type'}."\n" if( $self->{'debug'});

	if( exists $self->{'cblist'}->{$msg->{'type'}}) {
		## call on callback handler for this message type
		print STDERR "DEBUG: Calling callback for message type '".$msg->{'type'}."'\n" if( $self->{'debug'});
		&{$self->{'cblist'}->{$msg->{'type'}}}($msg);
	} else {
		print STDERR "DEBUG: No callback defined for message type '".$msg->{'type'}."'\n" if( $self->{'debug'});					
	}


}

sub handle_incoming_message {
	my( $self, $request) = @_;
	print STDERR "SignalCLI::handle_incoming_message default_handler: ".Dumper($request)."\n" if( $self->{'debug'});
}

sub handle_error {
	my($self, $request) = @_;
    # public String type;
    # public String id;			// Transaction ID, copied from request
    # public String error;        // Error name (fixed string)
    # public String message;      // Human readable error message
    # public String subject;      // Number or otherwise context relevant information about the error
	print STDERR "SignalCLI::handle_error ERROR(signal-cli): error='".$request->{'error'}."', message='".$request->{'message'}."', subject='".$request->{'subject'}."'\n";
}

sub handle_result {
	my($self, $request) = @_;
	print STDERR "SignalCLI::handle_result status='".$request->{'status'}."', id='".$request->{'id'}."'\n" if( $self->{'debug'});
	if( $request->{'status'} eq "ok" && exists $self->{'trans_cb'}->{$request->{'id'}}->{'success'}) {
		&{$self->{'trans_cb'}->{$request->{'id'}}->{'success'}}();
	} elsif( exists $self->{'trans_cb'}->{$request->{'id'}}->{'error'}) {
		&{$self->{'trans_cb'}->{$request->{'id'}}->{'error'}}();
	}
}

sub handle_receipt {
	my($self, $request) = @_;
	print STDERR "SignalCLI::handle_receipt senderNumber='".$request->{'envelope'}->{'source'}."', timestamp='".$request->{'envelope'}->{'timestampISO'}."'\n" if( $self->{'debug'});
	## TODO: since we don't have a message ID for the message sent, we can not map receipts received to an actual sent message which would be highly conveniant
	##	underlying shortcoming of signal-cli and I haven't had the time to figure out how that works (yet) //Kalle
}

sub handle_groupInfo {
	my( $self, $r) = @_;
	if( $self->{'debug'}) {
		my $gi = $r->{'envelope'}->{'dataMessage'}->{'groupInfo'};
		print STDERR "SignalCLI::handle_groupInfo groupId='".$gi->{'groupId'}."', groupName='".$gi->{'name'}."', members: [".join(",", @{$gi->{'members'}})."]\n";
	}
}

sub reply {
	my( $self, $request, $attachments_aref, $message_body, $on_success, $on_error) = @_;
	if( $request->{'type'} eq "message") {
		$self->send_message( $request->{'envelope'}->{'source'}, undef, $attachments_aref, $message_body, $on_success, $on_error);
	} elsif( $request->{'type'} eq "groupMessage") {
		$self->send_message( undef, $request->{'envelope'}->{'dataMessage'}->{'groupInfo'}->{'groupId'}, $attachments_aref, $message_body, $on_success, $on_error);
	}
}

##
##	Send signal message to recipient_number or recipient_groupID (can not be combined)
##
sub send_message {
	my( $self, $recipient_number, $recipient_groupID, $attachments_aref, $message_body, $on_success, $on_error) = @_;
	my $trans_id = $self->generate_transaction_id();
	my $r = { 'type' => 'send', id => $trans_id, 'messageBody' => $message_body };
	if( defined $recipient_number) {
		$r->{'recipientNumber'} = $recipient_number;
	} elsif( defined $recipient_groupID) {
		$r->{'recipientGroupId'} = $recipient_groupID;
	} else {
		my $msg = "SignalCLI::send_message: Neither receipient_number or recipient_groupID is defined, cannot send!";
		if( $on_error) {
			&{$on_error}($msg);
		} else {
			print STDERR $msg."\n";
		}
	}
	if( defined $attachments_aref && ref($attachments_aref) eq "ARRAY") {
		$r->{'attachmentFilenames'} = $attachments_aref;
	}
	if( $on_success) {
		$self->{'trans_cb'}->{$trans_id}->{'success'} = $on_success;
	}
	if( $on_error) {
		$self->{'trans_cb'}->{$trans_id}->{'error'} = $on_error;
	}
	$self->submit_request($r);
}

sub generate_transaction_id {
	my($self) = @_;
	return ++$self->{'_transaction_id_counter'};
}

sub exit {
	my($self, $request) = @_;
	$self->submit_request( { 'type' => 'exit' } );
}

##
##	Register event handlers
##		Raw event handlers called upon json message reception
##			error 			Default handler prints error to stderr and continues operation
##			jsonevtloop_start	Called when signal-cli is loaded and ready for action (it's java so startup time needs to be considered! ;-)
##			jsonevtloop_exit	Called when signal-cli is exiting
##			result
##	
##		Event handlers for SignalCLI refined events
##			cleanup			Called when signal-cli has been terminated and perl program is about to be exited
##			message 		Called on direct message reception
##			groupMessage 	Called on group message reception
##			groupInfo		Called on group info update
##			receipt 		Called when a message receipt is received
##			
##
sub on {
	my( $self, $event_type, $cb) = @_;

	if( !grep( $event_type, qw/error jsonevtloop_alive result message receipt groupMessage groupInfo cleanup jsonevtloop_start jsonevtloop_exit/) ) {
		die "SignalCLI.pm::on ERROR: Unknown event type '".$event_type."', exiting\n";
	}
	$self->{'cblist'}->{$event_type} = $cb;
}

## Add timer callback to event loop
sub on_timer {
	my( $self, $interval_s, $repeat, $callback) = @_;
	my $timer_watcher = $self->{'ev_loop'}->timer( $interval_s, $repeat, $callback);
	return $timer_watcher;
}


## start event loop
sub run {
	my( $self) = @_;
	$self->{'ev_loop'}->run();
}



1;


