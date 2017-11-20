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

    post '' => needs login => sub {
        my $user = resultset('User')->search(
            {
                id => session('user_id'),
            }
        );

        $user->status eq 'deactivated'
            or template 'admin/index' => { user => $user } =>
            { layout => 'admin' };

        my $password1 = body_parameters->{'password1'};
        my $password2 = body_parameters->{'password2'};

        $password1 eq $password2
            or return template 'admin/index' => {
            user    => $user,
            warning => 'The passwords don\'t match!'
            } => { layout => 'admin' };

        $user->update(
            {
                password => $password1,
                status   => 'activated',
            }
        );

        template 'admin/index' => { user => $user } => { layout => 'admin' };
    };

    get '/profile' => needs login => sub {
        my $user = resultset('User')->from_session( session('user_id') )
            or redirect '/';

        template 'admin/profile' => { user => $user } =>
            { layout => 'admin' };
    };

    post '/edit' => needs login => sub {
        my $user   = resultset('User')->from_session( session('user_id') );
        my $params = body_parameters;
        my $first_name    = $params->{'first_name'};
        my $last_name     = $params->{'last_name'};
        my $email         = $params->{'email'};
        my $old_password  = delete $params->{'old_password'};
        my $new_password  = delete $params->{'new_password'};
        my $new_password2 = delete $params->{'new_password2'};

        my %update_parameters = map +( $_ => $params->{$_} ),
            qw<first_name last_name email>;

        if ( $old_password && $new_password && $new_password2 ) {
            $user->check_password($old_password)
                or return template 'admin/profile' => {
                user    => $user,
                warning => 'Incorrect old password!',
                } => { layout => 'admin' };

            $new_password eq $new_password2
                or return template 'admin/profile' => {
                user    => $user,
                warning => 'The new passwords don\'t match!',
                } => { layout => 'admin' };

            $update_parameters{'password'} = $new_password;
        } elsif ( $old_password || $new_password || $new_password2 ) {
            return template 'admin/profile' => {
                user    => $user,
                warning => 'Must fill all password fields to update password',
            } => { layout => 'admin' };
        }

        $user->update( \%update_parameters );

        return template 'admin/profile' => {
            user    => $user,
            success => 'Your data was updated succesfully!',
        } => { layout => 'admin' };

        redirect '/dashboard/edit';
    };
};

1;
