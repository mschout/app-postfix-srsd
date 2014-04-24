#!/usr/bin/env perl
#

my $verbose = 1;

use Modern::Perl '2013';
use Parallel::ForkManager;
use IO::Socket;
use Text::Netstring qw(netstring_read netstring_encode netstring_decode);;

my ($socket, $cycles) = @ARGV or die "usage: $0 socket iterations\n";

my @forward = (map { "mschout$_\@gkg.net" } (1 .. $cycles));

my $pm = Parallel::ForkManager->new(16);

for my $req (@forward) {
    $pm->start and next;

    process(srsencoder => $req);

    $pm->finish;
}

$pm->wait_all_children;

sub process {
    my ($type, $email, $sock) = @_;

    $sock //= IO::Socket::UNIX->new(Type => SOCK_STREAM, Peer => $socket) or die "socket: $!";

    print $sock netstring_encode("$type $email");
    my $reply = netstring_decode(netstring_read($sock));
    $reply =~ s/^.* //;

    say "$email -> $reply" if $verbose;

    if (defined $reply and length $reply > 0) {
        if ($type eq 'srsencoder') {
            process(srsdecoder => $reply, $sock);
        }
    }

    $sock->shutdown(2);
    $sock->close;
}



