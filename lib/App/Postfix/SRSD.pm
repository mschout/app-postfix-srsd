package App::Postfix::SRSD;
# ABSTRACT: Sender Rewriting Scheme Daemon for Postfix

use Modern::Perl '2013';
use Mail::SRS;
use Method::Signatures;
use MooseX::App::Simple;
use Text::Netstring qw(netstring_read netstring_verify netstring_decode netstring_encode);
use TryCatch;
use autodie ':all';

use constant SOCKETMAP_MAX_QUERY => 1000;

with qw(App::Postfix::Daemon::Socket
        App::Postfix::Daemon::Prefork);

option secrets => (
    is           => 'ro',
    isa          => 'Str',
    required     => 1,
    documentation => q[Path to the secrets file]);

option domain => (
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    documentation => q[The domain to rewrite SRS addresses into]);

has srs => (is => 'ro', isa => 'Mail::SRS', lazy_build => 1);

after drop_privileges => sub {
    my $self = shift;

    warn "checking secret access...\n";
    $self->check_secrets_access;
};

method check_secrets_access {
    unless (-r $self->secrets) {
        die "Can't read secrets file ", $self->secrets, "\n";
    }
}

method handle_connection ($sock) {
    my $query = $self->read_query($sock);

    my ($type, $address) = split ' ', $query;

    given ($type) {
        when ('srsencoder') {
            $self->srs_forward($sock, $address);
        }
        when ('srsdecoder') {
            $self->srs_reverse($sock, $address);
        }
        default {
            $self->send_reply($sock, "PERM invalid query type $type");
        }
    }
}

method read_query($sock) {
    my $ns = netstring_read($sock);

    if (netstring_verify($ns)) {
        return netstring_decode($ns);
    }

    return;
}

method send_reply ($sock, $string) {
    $string = netstring_encode($string);

    if (length $string > SOCKETMAP_MAX_QUERY) {
        $sock->print(netstring_encode("PERM response string too long"));
    }
    else {
        $sock->print($string);
    }
}

method srs_forward ($sock, $address) {
    try {
        my $forward = $self->srs->forward($address, $self->domain);
        $self->send_reply($sock, "OK $forward");
    }
    catch ($e) {
        $self->send_reply($sock, "PERM $e");
    }
}

method srs_reverse ($sock, $address) {
    try {
        my $rev = $self->srs->reverse($address) // $address;
        $self->send_reply($sock, "OK $rev");
    }
    catch ($e) {
        $self->send_reply($sock, "PERM $e");
    }
}

method _build_srs {
    Mail::SRS->new(
        Secret     => $self->_load_secrets,
        MaxAge     => 30,
        HashLength => 4,
        HashMin    => 4);
}

method _load_secrets {
    open my $fh, '<', $self->secrets;

    my @secrets;
    while (my $line = <$fh>) {
        chomp $line;

        next if $line =~ /^\s*$/; # skip blank lines
        next if $line =~ /^\s*#/; # skip comment lines

        # trim.
        $line =~ s/(?:^\s+)|(?:\s+$)//g;

        push @secrets, $line;
    }

    die "secrets file is empty!" unless @secrets;

    return \@secrets;
}

1;
