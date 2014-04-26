#!/usr/bin/env perl
#

my $verbose = 1;

use Modern::Perl '2013';
use IO::Socket;
use Text::Netstring qw(netstring_read netstring_encode netstring_decode);;

my ($socket, $time) = @ARGV or die "usage: $0 socket iterations\n";

my $sock = IO::Socket::UNIX->new(Type => SOCK_STREAM, Peer => $socket) or die "socket: $!";

my $email = "nobody$$\@domain.com";
print $sock netstring_encode("srsencoder $email");
my $reply = netstring_decode(netstring_read($sock));

say "$email -> $reply";

# hold the socket open
sleep $time;

