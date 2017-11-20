package PearlBee::Test;
use strict;
use warnings;
use feature 'state';
use parent 'Exporter';
use Import::Into;

BEGIN { $ENV{DANCER_ENVIRONMENT} ||= 'testing' }

use Test::More ();
use Test::WWW::Mechanize::PSGI;
use HTTP::Cookies;

use PearlBee::Test::EmailSenderTransport;
$ENV{EMAIL_SENDER_TRANSPORT} = 'PearlBee::Test::EmailSenderTransport';

use PearlBee;
use PearlBee::Model::Schema;

our @EXPORT = qw/ app mech schema logs ensure_admin_in_db /;

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
    state $conn = PearlBee::Model::Schema->connect(
        PearlBee::config()->{plugins}{DBIC}{default}{dsn}
    );
    return $conn;
}

sub ensure_admin_in_db {
    my $urs = schema->resultset('User');
    my $count = $urs->count({ role => 'admin', status => 'activated' });

    return if $count;

    $urs->create({
        name           => 'Default Admin',
        username       => 'admin',
        password       => 'password',
        email          => 'admin@admin.com',
        role           => 'admin',
        status         => 'activated',
    });

    return;
}

1;
