package App::Postfix::Daemon::Prefork;

use MooseX::App::Role;
use Method::Signatures;

with qw(App::Postfix::Daemon App::Postfix::Daemon::Role::Workers);

option workers => (
    is            => 'ro',
    isa           => 'Int',
    lazy_build    => 1,
    documentation => q[Number of worker processes]);

option 'requests-per-child' => (
    is            => 'ro',
    isa           => 'Int',
    default       => sub { 100 },
    reader        => 'requests_per_child',
    documentation => q[Max number or requests per child]);

requires qw(handle_request);

my %Workers;

method install_signal_handlers {
    warn "Installing signal handlers..\n";
    $SIG{CHLD} = \&sig_chld_handler;
    $SIG{INT}  = \&sig_int_handler;
    $SIG{TERM} = \&sig_int_handler;
};

method restore_signal_handlers {
    $SIG{$_} = 'DEFAULT' foreach qw(CHLD INT TERM);
}

method prefork_children {
    $self->spawn_worker foreach 1 .. $self->workers;
}

method spawn_worker {
    (my $pid = fork) // die "fork: $!";

    if ($pid) {
        $Workers{$pid} = 1;

        return;
    }
    else {
        $self->restore_signal_handlers;

        $self->child_loop;

        exit;
    }
}

method main_loop {
    $self->install_signal_handlers;

    $self->prefork_children;

    while (1) {
        sleep; # wait for a signal
        #$log->info("woke up, children=", $self->num_children);

        for (my $i = $self->num_children; $i < $self->workers; $i++) {
            $self->spawn_worker;
        }
    }
}

# XXX move socket crap to Socket module
method child_loop {
    # XXX configurable max requests per child
    for (my $i = 0; $i < $self->requests_per_child; $i++) {
        $self->handle_request($i);
    }
}

method num_children {
    return scalar keys %Workers;
}

# XXX perhaps POSIX::sigaction() is better here?
# Or use Event... ?
sub sig_int_handler {
    local($SIG{CHLD}) = 'IGNORE';

    kill INT => keys %Workers;

    exit;
}

# XXX perhaps POSIX::sigaction() is better here?
# Or use Event... ?
sub sig_chld_handler {
    my $sig = shift;

    while ((my $pid = waitpid(-1, &POSIX::WNOHANG)) > 0) {
        delete $Workers{$pid};

        my $sig = $? & 127;
        #$log->info("reaped $pid status=$? signal=$sig");
    }

    # reinstall the handler
    $SIG{CHLD} = \&sig_chld_handler;
}

1;
