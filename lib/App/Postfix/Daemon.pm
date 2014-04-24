package App::Postfix::Daemon;

use Modern::Perl '2013';
use MooseX::App::Role;
use Proc::Daemon;
use Proc::PID::File;
use File::Basename qw(dirname basename);
use POSIX ();
use Method::Signatures;

option foreground => (
    is           => 'ro',
    isa          => 'Bool',
    default      => sub { 1 },
    documentation => q[Run in the foreground (dont deamonize)]);

option pidfile => (
    is           => 'ro',
    isa          => 'Str',
    predicate    => 'has_pidfile',
    documentation => q[PID file name.  Default: /var/run/].basename($0).q[.pid]);

option user => (
    is            => 'ro',
    isa           => 'Str',
    predicate     => 'has_user',
    documentation => q[The user to run as]);

option group => (
    is            => 'ro',
    isa           => 'Str',
    predicate     => 'has_group',
    documentation => q[The group to run as]);

has [qw(uid gid)] => (is => 'ro', isa => 'Int', lazy_build => 1);

has process_name => (is => 'ro', isa => 'Str', lazy_build => 1);

has pid => (is => 'ro', isa => 'Proc::PID::File', lazy_build => 1);

requires qw(main_loop handle_request);

with qw(MooseX::Log::Log4perl);

method run {
    $self->check_running;

    $self->drop_privileges;

    $self->daemonize;

    $self->main_loop;
}

method check_running {
    $self->log->logdie("already running!") if $self->pid->alive;

    $self->pid->touch;
}

method drop_privileges {
    return unless $< == 0 # pointless without superuser privs.
        and ($self->has_user or $self->has_group);

    $self->log->debug('dropping privileges, user=',
        $self->user, ' group=', $self->group);

    chown $self->pidfile, $self->uid, $self->gid;

    $( = $self->gid;
    unless (POSIX::setgid($self->gid)) {
        $self->log->logdie("failed to set gid: $!");
    }

    $< = $> = $self->uid;

    if ($< != $self->uid) {
        $self->log->logdie("failed to become uid ", $self->uid);
    }

    unless (POSIX::setuid($self->uid)) {
        $self->log->logdie("couldn't become uid ", $self->uid, ": $!");
    }
}

method daemonize {
    return if $self->foreground;

    Proc::Daemon::Init();

    $self->pid->touch;
}

method _build_pid {
    my %args;

    if ($self->has_pidfile) {
        ($args{name} = basename($self->pidfile)) =~ s/\.pid$//;;
        $args{dir} = dirname($self->pidfile);
    }

    return Proc::PID::File->new(%args);
}

method _build_uid {
    return $< unless $self->has_user;

    return (getpwnam($self->user))[2];
}

method _build_gid {
    if ($self->has_group) {
        return scalar getgrnam($self->group);

    }
    elsif ($self->has_user) {
        # get users GID
        return (getpwnam($self->user))[3];
    }
    else {
        return $(;
    }
}

sub _build_process_name {
    basename($0);
}

1;
