package PearlBee::Test;
use strict;
use warnings;
use parent 'Exporter';
use Import::Into;

use Test::More ();
use Test::WWW::Mechanize::PSGI;
use HTTP::Cookies;

use PearlBee;
use PearlBee::Model::Schema;

our @EXPORT = qw/ app mech schema logs /;

PearlBee::set( logger => 'capture' );

sub import {
    my ($caller) = @_;

    shift->export_to_level(1);
    $_->import::into(1) for qw(strict warnings Test::More);
}

sub mech {
    my $mech = Test::WWW::Mechanize::PSGI->new( app => PearlBee->to_app );
    $mech->cookie_jar( HTTP::Cookies->new );
    return $mech;
}

sub app { PearlBee::app() }

sub logs { app->logger_engine->trapper->read }

sub schema {
    PearlBee::Model::Schema->connect(
        PearlBee::config()->{plugins}{DBIC}{default}{dsn}
    );
}

1;
