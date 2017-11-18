package Dancer2::Plugin::Auth::PearlBee;

use strict;
use warnings;
use Dancer2::Plugin;
use URI::Escape;

has 'rbac' => (
    'is'          => 'ro',
    'from_config' => 1,
    'default'     => sub { +{} },
);

sub needs_permission :PluginKeyword {
    my ( $self, $permission, $sub ) = @_;
    my $rbac          = $self->rbac;
    my $error_message = uri_escape( $rbac->{'error_message'} )
        || "You do not have permission ($permission) to access the page";

    return sub {
        my $user = $self->dsl->vars->{'user'}
            or $self->dsl->redirect('/login?failure="Unauthorized user"');

        $rbac->can_role( $user->role, $permission )
            or $self->dsl->redirect("/login?failure=\"$error_message\"");

        goto &$sub;
    };
}

sub needs_role :PluginKeyword {
    my ( $self, $role, $sub ) = @_;
    return sub {
        my $user = $self->dsl->vars->{'user'}
            or $self->dsl->redirect('/login');

        $user->role eq $role
            or $self->dsl->redirect('/login');

        goto &$sub;
    };
}

1;
