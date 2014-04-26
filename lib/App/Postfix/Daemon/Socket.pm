package App::Postfix::Daemon::Socket;

use Modern::Perl '2013';
use MooseX::App::Role;
use IO::Socket;
use Method::Signatures;

option socket => (
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    documentation => q[The path to the socket file (unix:/path/to/sock.sock)]);

option 'timeout' => (
    is            => 'ro',
    isa           => 'Str',
    default       => sub { 5 },
    documentation => q[Socket connect timeout (default: 5)]);

has listen => (is => 'rw', isa => 'IO::Socket', lazy_build => 1);

with qw(MooseX::Log::Log4perl);

after check_running => sub {
    my $self = shift;

    # create the socket.
    my $sock = $self->listen
        or $self->log->logdie("failed to create socket: $!");
};

before drop_privileges => sub {
    my $self = shift;

    return unless $< == 0
        and ($self->has_user or $self->has_group);

    if ($self->is_unix_socket) {
        chown $self->uid, $self->gid, $self->socket_path;
    }
};

method accept {
    $0 = sprintf '%s: accepting on %s',
        $self->process_name, $self->socket;

    my $sock = $self->listen->accept or return;

    $0 = sprintf '%s: processing', $self->process_name;

    return $sock;
}

method is_unix_socket {
    $self->socket =~ /^unix:/ ? 1 : 0
}

method socket_path {
    return unless $self->is_unix_socket;

    (my $path = $self->socket) =~ s/^unix://;

    return $path;
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
    my $path = $self->socket_path;

    if (-e $path) {
        unlink $path;
    }

    my $old_umask = umask 0111;

    my $sock = IO::Socket::UNIX->new(
        Type             => SOCK_STREAM,
        Local            => $path,
        Listen           => SOMAXCONN,
        Blocking         => 0)
            or $self->log->logdie("Failed to create socket: $!");

    umask $old_umask;

    return $sock;
}

method _build_listen_inet {
    (my $spec = $self->socket) =~ s/^inet://;

    unless ($spec =~ /^[0-9a-z-]+:\d+$/) {
        $self->log->logdie("Invalid socket specification: ", $self->socket);
    }

    my ($host, $port) = split ':', $spec;

    return IO::Socket::INET->new(
        Listen           => SOMAXCONN,
        LocalAddr        => $host,
        LocalPort        => $port,
        Proto            => 'tcp',
        Blocking         => 0)
            or $self->log->logdie("Failed to create socket: $!");
}

1;
