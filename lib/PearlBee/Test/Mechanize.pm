package PearlBee::Test::Mechanize;
use strict;
use warnings;
use HTTP::Request::Common;
use URI;
use parent 'Test::WWW::Mechanize::PSGI';

=head2 $mech->patch( $uri, content => $content )

PATCHes I<$content> to $uri.  Returns an L<HTTP::Response> object.
I<$uri> can be a well-formed URI string, a L<URI> object, or a
L<WWW::Mechanize::Link> object.

=cut

# Added until WWW::Mechanize has it
sub patch {
    my ($self, $uri) = @_;

    $uri = $uri->url if ref($uri) eq 'WWW::Mechanize::Link';

    $uri
        = $self->base
        ? URI->new_abs( $uri, $self->base )
        : URI->new($uri);

    # It appears we are returning a super-class method,
    # but it in turn calls the request() method here in Mechanize
    return $self->_SUPER_patch( $uri->as_string, @_ );
}

# Added until LWP::UserAgent has it.
sub _SUPER_patch {
    my ( $self, @parameters ) = @_;
    my @suff = $self->_process_colonic_headers( \@parameters, 1 );
    return $self->request( HTTP::Request::Common::PATCH(@parameters), @suff );
}

sub patch_ok {
    my $self = shift;

    my ( $url, $desc, %opts ) = $self->_unpack_args( 'PATCH', @_ );

    $self->patch( $url, %opts );
    my $ok = $self->success;

    $ok = $self->_maybe_lint( $ok, $desc );

    return $ok;
}

1;
