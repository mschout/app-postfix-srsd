package App::Postfix::Daemon::Prefork;

use MooseX::App::Role;
use Method::Signatures;
use Parallel::Prefork;

option 'requests_per_child' => (
    is            => 'ro',
    isa           => 'Int',
    default       => sub { 100 },
    cmd_flag      => 'requests-per-child',
    documentation => q[Max number or requests per child]);

with qw(MooseX::Log::Log4perl
        App::Postfix::Daemon
        App::Postfix::Daemon::Role::Workers);

requires qw(handle_request);

method main_loop {
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

        my $reqs_remaining = $self->requests_per_child;

        $SIG{TERM} = sub { $reqs_remaining = 0 };

        while ($reqs_remaining-- > 0) {
            $self->handle_request;
        }

        $self->log->debug("worker $$ exiting");

        $pm->finish;
    }

    $pm->wait_all_children;
}

1;
