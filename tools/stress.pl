#!/usr/bin/env perl
#

my $verbose = 1;

use Modern::Perl '2013';
use Parallel::ForkManager;
use IO::Socket;
use Scope::OnExit;
use List::MoreUtils qw(part);
use Text::Netstring qw(netstring_read netstring_encode netstring_decode);;

my $WORKERS = 16;

my ($socket, $cycles) = @ARGV or die "usage: $0 socket iterations\n";

my $i = 0;
my @forward = part { $i++ % $WORKERS }
    (map { "mschout$_\@gkg.net" } (1 .. $cycles));

my $pm = Parallel::ForkManager->new($WORKERS);

for my $part (@forward) {
    $pm->start and next;

    on_scope_exit {
        $pm->finish;
    };

    my $sock //= IO::Socket::UNIX->new(Type => SOCK_STREAM, Peer => $socket) or die "socket: $!";

    for my $req (@$part) {
        process($req, $sock);
    }

    $sock->shutdown(2);
    $sock->close;
}

$pm->wait_all_children;

sub process {
    my ($email, $sock) = @_;

    my $reply = do_command(srsencoder => $email, $sock);

    say "srsencoder: $reply";

    if (defined $reply and length $reply) {
        $reply = do_command(srsdecoder => $reply, $sock);
        say "srsdecoder $reply" if $verbose;
    }
}

sub do_command {
    my ($command, $email, $sock) = @_;

    print $sock netstring_encode("$command $email");

    my $reply = netstring_decode(netstring_read($sock));

    $reply =~ s/^.* //;

    return $reply;
}



