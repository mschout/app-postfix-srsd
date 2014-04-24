package App::Postfix::Daemon::Socket;

use Modern::Perl '2013';
use MooseX::App::Role;
use IO::Socket;
use Method::Signatures;

with qw(App::Postfix::Daemon);

option socket => (
    is            => 'ro',
    isa           => 'Str',
    documentation => q[The path to the socket file (unix:/path/to/sock.sock)]);

has listen => (is => 'rw', isa => 'IO::Socket', lazy_build => 1);

after check_running => sub {
    my $self = shift;

    # create the socket.
    my $sock = $self->listen or die "failed to create socket: $!";
};

before drop_privileges => sub {
    my $self = shift;

    return unless $< == 0
        and ($self->has_user or $self->has_group);

    chown $self->socket, $self->uid, $self->gid;
};

method handle_request {
    $0 = sprintf '%s: accepting on %s',
        $self->process_name, $self->socket;

    my $sock = $self->listen->accept or last;

    $0 = sprintf '%s: processing', $self->process_name;

    $self->handle_connection($sock);
}

method _build_listen {
    given ($self->socket) {
        when (qr[^unix:]) {
            $self->_build_listen_unix;
        }
        default {
            $self->_build_listen_inet;
        }
    }
}

method _build_listen_unix {
    (my $path = $self->socket) =~ s/^unix://;

    if (-e $path) {
        unlink $path;
    }

    my $old_umask = umask 0111;

    my $sock = IO::Socket::UNIX->new(
        Type   => SOCK_STREAM,
        Local  => $path,
        Listen => 32) or die "Failed to create socket: $!";

    umask $old_umask;

    return $sock;
}

method _build_listen_inet {
    (my $spec = $self->socket) =~ s/^inet://;

    unless ($spec =~ /^[0-9a-z-]+:\d+$/) {
        die "Invalid socket specification: ", $self->socket;
    }

    my ($host, $port) = split ':', $spec;

    return IO::Socket::INET->new(
        Listen    => 32,
        LocalAddr => $host,
        LocalPort => $port,
        Proto     => 'tcp') or die "Failed to create socket: $!";
}

1;
