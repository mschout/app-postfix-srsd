package App::Postfix::Daemon::Prefork;

use MooseX::App::Role;
use Method::Signatures;
use Parallel::Prefork;

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

method main_loop {
    my $pm = Parallel::Prefork->new(
        max_workers  => $self->workers,
        trap_signals => {
            TERM => 'TERM',
            HUP  => 'TERM'
        }
    );

    while ($pm->signal_received ne 'TERM') {
        $pm->start and next;

        my $reqs_remaining = $self->requests_per_child;

        $SIG{TERM} = sub { $reqs_remaining = 0 };

        while ($reqs_remaining-- > 0) {
            $self->handle_request;
        }

        $pm->finish;
    }

    $pm->wait_all_children;
}

1;
