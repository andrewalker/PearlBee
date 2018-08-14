package PearlBee::Dashboard;
use Dancer2 appname => 'PearlBee';
use Dancer2::Plugin::DBIC;
use Dancer2::Plugin::Auth::Tiny;

use PearlBee::Dashboard::Posts;
use PearlBee::Dashboard::Users;

# it is how we're using Auth::Tiny in the code
# so we configure it in the code as well
# (maybe we should add "user" key as a boolean
#  or maybe add a user to the session every time
#  a user logs in)
config->{'plugins'}{'Auth::Tiny'}{'logged_in_key'} = 'user_id';

prefix '/dashboard' => sub {
    get '/?' => needs login => sub {
        redirect '/dashboard/posts';
    };
};

1;
