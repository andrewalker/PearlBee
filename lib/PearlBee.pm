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
use PearlBee::Users;
use PearlBee::Authors;
use if !$PearlBee::is_static, 'PearlBee::Dashboard';
use PearlBee::Comments;
use PearlBee::API::Posts;
use PearlBee::API::Users;
use PearlBee::API::Comments;
use PearlBee::Posts;

hook before => sub {
    if ( my $id = session->read('user_id') ) {
        var user => resultset('User')->find($id);
    }

    if ( request->path =~ /^(.*)\.html$/ ) { forward $1; }
};

hook before_template_render => sub {
    my $tokens = shift;
    $tokens->{uri_for} = \&uri_for;
};

# main page
get '/' => sub {
    forward '/posts';
};

1;
