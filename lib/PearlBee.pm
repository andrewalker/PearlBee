package PearlBee;

# ABSTRACT: PearlBee Blog platform
use Dancer2;
use Dancer2::Plugin::DBIC;

BEGIN {
    our $is_static = config->{static} || '';
}

# has to be *after* the configuration is set above
use Dancer2::Plugin::Auth::PearlBee;

# load all components
use PearlBee::Posts;
use PearlBee::Users;
use PearlBee::Authors;
use PearlBee::Categories;
use PearlBee::Tags;
use if !$PearlBee::is_static, 'PearlBee::Dashboard';
use PearlBee::Comments;

hook before => sub {
    if ( my $id = session->read('user_id') ) {
        var user => resultset('User')->from_session($id);
    }

    if ( request->path =~ /^(.*)\.html$/ ) { forward $1; }
};

# main page
get '/' => sub {
    forward '/posts';
};

1;
