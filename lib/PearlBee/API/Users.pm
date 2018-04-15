package PearlBee::API::Users;

# ABSTRCT: Posts-related paths
use Dancer2 appname => 'PearlBee';
use Dancer2::Plugin::DBIC;

get '/api/user' => sub {
    my $user_id = session 'user_id';

    my $user = resultset('User')->find($user_id);

    if (!$user) {
        status 'not_found';
        send_as JSON => { error => "not found" };
    }

    send_as JSON => {
        user => {
            name          => $user->name,
            username      => $user->username,
            email         => $user->email,
            role          => $user->role,
            status        => $user->status,
            post_count    => $user->posts->search({status => 'published'})->count,
            registered_at => $user->registered_at->iso8601(),
            $user->last_login
                ? ( last_login => $user->last_login->iso8601 )
                : (),
        },
    };
};

get '/api/user/:user' => sub {
    my $username = route_parameters->{'user'};

    my $user = resultset('User')->search({
        username => $username
    })->first;

    if (!$user) {
        status 'not_found';
        send_as JSON => { error => "not found" };
    }

    send_as JSON => {
        user => {
            name       => $user->name,
            username   => $user->username,
            role       => $user->role,
            status     => $user->status,
            post_count => $user->posts->search({status => 'published'})->count,
        },
    };
};


1;
