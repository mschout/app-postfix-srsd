package App::Postfix::Daemon::Prefork;

use MooseX::App::Role;
use Method::Signatures;
use Parallel::Prefork;

with qw(MooseX::Log::Log4perl
        App::Postfix::Daemon
        App::Postfix::Daemon::Role::Workers);

around main_loop => sub {
    my ($orig, $self) = splice @_, 0, 2;

    my $pm = Parallel::Prefork->new(
        max_workers  => $self->workers,
        trap_signals => {
            TERM => 'TERM',
            HUP  => 'TERM'
        }
    ) or $self->log->logdie("Error creating PreFork Manager");

    while ($pm->signal_received ne 'TERM') {
        $pm->start and next;

        $self->log->debug("worker $$ launched");

        $self->$orig(@_);

        $self->log->debug("worker $$ exiting");

        $pm->finish;
    }

    $pm->wait_all_children;
};

1;
