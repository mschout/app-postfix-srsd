package App::Postfix::Daemon::Role::Workers;

use Moose::Role;

# build workers arg. default = number of cpus.
sub _build_workers {
    require Sys::Info;
    require Sys::Info::Constants;

    Sys::Info::Constants->import(':device_cpu');

    my $info = Sys::Info->new // return 2;

    return $info->device('CPU')->count || 2;
}

1;
