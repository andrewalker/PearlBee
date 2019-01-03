package PearlBee::Helpers::SendAs;
use strict;
use warnings;
use Dancer2 appname => 'PearlBee';
use Exporter 'import';

our @EXPORT = qw/send_as_bad_request send_as_forbidden send_as_unauthorized send_as_not_found/;

sub send_as_bad_request {
    status 'bad_request';
    send_as JSON => $_[0];
}

sub send_as_forbidden {
    status 'forbidden';
    send_as JSON => $_[0];
}

sub send_as_unauthorized {
    status 'unauthorized';
    send_as JSON => $_[0];
}

sub send_as_not_found {
    status 'not_found';
    send_as JSON => $_[0];
}

1;
