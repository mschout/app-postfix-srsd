package App::Postfix::Daemon::Role::Workers;

use MooseX::App::Role;

option workers => (
    is            => 'ro',
    isa           => 'Int',
    lazy_build    => 1,
    documentation => q[Number of worker processes]);

# build workers arg. default = number of cpus.
sub _build_workers {
    require Sys::Info;
    require Sys::Info::Constants;

    Sys::Info::Constants->import(':device_cpu');

    my $info = Sys::Info->new // return 2;

    return $info->device('CPU')->count || 2;
}

1;
