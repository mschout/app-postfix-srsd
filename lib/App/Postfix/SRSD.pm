package App::Postfix::SRSD;
# ABSTRACT: Sender Rewriting Scheme Daemon for Postfix

use Modern::Perl '2013';
use Mail::SRS;
use Method::Signatures;
use MooseX::App::Simple;
use Text::Netstring qw(netstring_read netstring_verify netstring_decode netstring_encode);
use TryCatch;
use Log::Log4perl;
use autodie ':all';

my $LogConf = <<EOT;
log4perl.rootLogger=DEBUG, Root, Screen

# filter only warn and above
log4perl.filter.MatchWarn               = Log::Log4perl::Filter::LevelRange
log4perl.filter.MatchWarn.LevelMin      = WARN
log4perl.filter.MatchWarn.AcceptOnMatch = true

# log to syslog
log4perl.appender.Root           = Log::Dispatch::Syslog
log4perl.appender.Root.min_level = debug
log4perl.appender.Root.ident     = postfix-srsd
log4perl.appender.Root.facility  = mail
log4perl.appender.Root.layout    = Log::Log4perl::Layout::SimpleLayout

# also send warn and above to the screen
log4perl.appender.Screen        = Log::Log4perl::Appender::Screen
log4perl.appender.Screen.Filter = MatchWarn
log4perl.appender.Screen.layout = Log::Log4perl::Layout::SimpleLayout
EOT

Log::Log4perl::init(\$LogConf);

use constant SOCKETMAP_MAX_QUERY => 1000;

with qw(App::Postfix::Daemon::Socket
        App::Postfix::Daemon::Prefork
        MooseX::Log::Log4perl);

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

option 'read_timeout' => (
    is            => 'ro',
    isa           => 'Str',
    default       => sub { 2 },
    cmd_flag      => 'read-timeout',
    documentation => q[Socket read/write timeout timeout (default: 2)]);

has srs => (is => 'ro', isa => 'Mail::SRS', lazy_build => 1);

after drop_privileges => sub {
    my $self = shift;

    $self->log->debug("checking secret access");

    $self->check_secrets_access;
};

method check_secrets_access {
    unless (-r $self->secrets) {
        $self->log->logdie("Can't read secrets file", $self->secrets);
    }
}

method handle_request {
    my $sock = $self->accept or return;

    while (1) {
        my $query = $self->read_query($sock) or last;

        my ($type, $address) = split ' ', $query;

        unless (defined $address and length $address) {
            $self->send_reply($sock, 'NOTFOUND ');
        }

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

    $sock->shutdown(2);
    $sock->close;
}

method read_query($sock) {
    my $ns;

    local $SIG{ALRM} = sub { $self->log->logdie("read timeout") };

    my $prev_alarm = alarm $self->read_timeout;

    try {
        $ns = netstring_read($sock);
    }

    alarm $prev_alarm;

    return unless defined $ns and length $ns > 0;

    if (netstring_verify($ns)) {
        return netstring_decode($ns);
    }

    return;
}

method send_reply ($sock, $string) {
    $string = netstring_encode($string);

    local $SIG{ALRM} = sub { $self->log->logdie("write timeout") };

    my $prev_alarm = alarm $self->read_timeout;

    try {
        if (length $string > SOCKETMAP_MAX_QUERY) {
            $sock->print(netstring_encode("PERM response string too long"));
        }
        else {
            $sock->print($string);
        }
    }

    alarm $prev_alarm;

    return;
}

method srs_forward ($sock, $address) {
    try {
        my $domain = $self->domain;

        if (index($address, '@') == -1) {
            return $self->send_reply($sock, 'NOTFOUND address does not contain domain');
        }
        elsif (my $forward = $self->srs->forward($address, $self->domain)) {
            $self->log->info("rewrite $address -> $forward")
                unless ($address eq $forward);
            $self->send_reply($sock, "OK $forward");
        }
        else {
            $self->send_reply($sock, "PERM srs forwarding failed");
        }
    }
    catch ($e) {
        $self->send_reply($sock, "PERM $e");
    }
}

method srs_reverse ($sock, $address) {
    try {
        my $domain = $self->domain;

        unless ($address =~ /^SRS0[-+=]/) {
            return $self->send_reply($sock, 'NOTFOUND address is not SRS encoded');

        }
        elsif (index($address, '@') == -1) {
            return $self->send_reply($sock, 'NOTFOUND address does not contain domain');
        }
        elsif ($address !~ /\@$domain$/) {
            return $self->send_reply($sock, "NOTFOUND External domains are ignored");
        }
        elsif (my $rev = $self->srs->reverse($address)) {
            $self->log->info("rewrite $address -> $rev");
            $self->send_reply($sock, "OK $rev");
        }
        else {
            $self->send_reply($sock, "NOTFOUND invalid srs email");
        }
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

    $self->log->logdie("secrets file is empty!") unless @secrets;

    return \@secrets;
}

1;
