#!/usr/bin/env plackup
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";
use PearlBee;

PearlBee->to_app;
