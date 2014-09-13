# Postfix SRSD

This is a Sender Rewriting Scheme (SRS) daemon for postfix.  SRS handles
address rewriting as part of the SPF/SRS protocol pair.

## What is SRS?

SPF (and related systems) present a challenge to forwarders, since the envelope
sender address might be seen by the destination as a forgery by the forwarding
host. Forwarding services must rewrite the envelope sender address, while
encapsulating the original sender and preventing relay attacks by spammers. The
Sender Rewriting Scheme, or SRS, provides a standard for this rewriting which
makes forwarding compatible with these address verification schemes, preserves
bounce functionality and is not vulnerable to attacks by spammers.

## Dependencies

In order to install postfix srsd, the following dependencies are required:

  - a C++11 compliant compiler
  - Boost headers and libraries, available at http://boost.org/
  - libsrs2xx available at https://github.com/mschout/libsrs2xx/releases

## Installation

Installation involves the usual

  ./configure
  make
  make install

Note that you may need to pass LDFLAGS and CPPFLAGS to configure if it cannot
find libsrs2xx, e.g.:

  ./configure LDFLAGS="-L/usr/local/lib" CPPFLAGS="-I/usr/local/include"

## Configuration

For FreeBSD, an rc startup script is included in
`contrib/freebsd/postfix_srsd.rc`  Copy this file to `/usr/local/etc/rc.d' and
make it executable, and set `postfix_srsd_enable="YES"' in `/etc/rc.conf'.

You need to generate at least one secret and save it in a file (default is
`/usr/local/etc/postfix/postfix-srsd.secrets').  The format is one secret per
line, with the last one being the current secret used for encoding addresses,
and all lines valid for decoding.

## Configure Postfix

Add to main.cf:

```
recipient_canonical_maps = hash:$config_directory/nosrs, socketmap:unix:/var/run/postfix-srsd.sock:srsdecoder
recipient_canonical_classes = envelope_recipient, header_recipient
sender_canonical_maps = hash:$config_directory/nosrs, socketmap:unix:/var/run/postfix-srsd.sock:srsencoder
sender_canonical_classes = envelope_sender
```

the "nosrs" file can be used to sepecify recipients/senders that should not be
rewritten.

## Running

Run with --help to get usage information:

```
Usage: postfix-srsd [options]

Allowed options:
  -d [ --debug ]                        run in debug mode
  -h [ --help ]                         Print this help message
  --socket arg                          path to the unix socket file
  --secrets arg                         path to the secrets file
  --user arg (=nobody)                  username to run as
  --group arg (=nobody)                 group to run as
  --domain arg                          SRS rewrite domain
  --pidfile arg (=/var/run/postfix-srsd.pid)
                                        path to the pid file
```
