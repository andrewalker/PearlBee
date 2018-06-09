#!/usr/bin/env plackup
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";
use PearlBee;
use Plack::Builder;
use Plack::App::File;

my $static_app = Plack::App::File->new(root => './dashboard-ng');

builder {
    mount '/dashboard-ng' => builder {
        enable sub {
            my ($app) = @_;
            sub {
                my ($env) = @_;
                if ($env->{PATH_INFO} !~ /\./) {
                    return $static_app->serve_path($env, "$FindBin::Bin/dashboard-ng/index.html");
                }
                else {
                    return $app->($env);
                }
            }
        };
        $static_app->to_app;
    };
    mount '/' => PearlBee->to_app;
}
