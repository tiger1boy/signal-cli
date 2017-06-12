#!/usr/bin/perl

## PERL event loop driven interface for signal-cli

#  Copyright (C) 2017 Carl Bingel
# 
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
# 
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
# 
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.

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
##		signal_cli_executable (Optional) Path to signal-cli executable, default to current build path (build/install/signal-cli/bin/signal-cli)
##		ev_loop				(Optional) EV loop object, defaulting to "default event loop"
##		debug 				(Optional) Turn on debug logging (to stderr)
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

	my @cmdline = (
		(defined $opts{'signal_cli_executable'}) ? $opts{'signal_cli_executable'} : '../build/install/signal-cli/bin/signal-cli',
		'-u',
		$opts{'telephone_number'},
		'jsonevtloop'
	);

	## Start child signal-cli process
	#$self->{'signal_pid'} = open3( $self->{'signal_cli_stdin'}, $self->{'signal_cli_stdout'}, $self->{'signal_cli_stderr'}, @cmdline) || die "SignalCLI.pm: ERROR: Could not execute signal-cli: ".$!."\n";
	$self->{'signal_pid'} = open2( $self->{'signal_cli_stdout'}, $self->{'signal_cli_stdin'}, @cmdline) || die "SignalCLI.pm: ERROR: Could not execute signal-cli: ".$!."\n";

	$self->{'ev_loop'} = (defined $opts{'ev_loop'}) ? $opts{'ev_loop'} : EV::default_loop;

	## Add STDOUT watcher to child process
	$self->{'signal_stdout_watcher'} = $self->{'ev_loop'}->io( $self->{'signal_cli_stdout'}, EV::READ, sub {
		my( $w, $revents) = @_;
		#my $line = <$self->{'signal_cli_stdout'}>;
		my $line = readline( $self->{'signal_cli_stdout'});
		#my $line;
		chomp($line);
		print STDERR "DEBUG(JSON-IN): ".$line."\n" if( $self->{'debug'});
		if( $line ne "") {
			my $msg = decode_json($line);
			if( $msg) { 
				print STDERR "DEBUG(JSON-Dump): ".Dumper($msg)."\n" if( $self->{'debug'});
				if( exists $self->{'cblist'}->{$msg->{'type'}}) {
					## call on callback handler for this message type
					print STDERR "DEBUG: Calling callback for message type '".$msg->{'type'}."'\n" if( $self->{'debug'});
					&{$self->{'cblist'}->{$msg->{'type'}}}($msg);
				} else {
					print STDERR "DEBUG: No callback defined for message type '".$msg->{'type'}."'\n" if( $self->{'debug'});					
				}
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
		print STDERR "Child died, exiting\n";
		waitpid( $self->{'signal_pid'}, 0);
		exit(0);
	});

	## Dummy test
	$self->{'timer1'} = $self->{'ev_loop'}->timer( 10, 0, sub {
		my( $w, $revents) = @_;
		#print { $self->{'signal_cli_stdin'} } "{\"type\":\"exit\"}\n";
		print STDERR "timer1\n";
		$self->submit_request( { 'type' => 'exit' } );
	});

	return $self;
}

sub submit_request {
	my( $self, $request) = @_;
	my $json = to_json($request);
	print STDERR "DEBUG(JSON-OUT): ".$json."\n" if( $self->{'debug'});
	print {$self->{'signal_cli_stdin'}} $json."\n";
}

sub on {
	my( $self, $event_type, $cb) = @_;
	if( !grep( $event_type, qw/error result message receipt groupMessage groupInfo/) ) {
		die "SignalCLI.pm::on ERROR: Unknown event type '".$event_type."', exiting\n";
	}
	$self->{'cblist'}->{$event_type} = $cb;
}

sub run {
	my( $self) = @_;
	$self->{'ev_loop'}->run();
}



1;


