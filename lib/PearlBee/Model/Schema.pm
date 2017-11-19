use utf8;

package PearlBee::Model::Schema;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Schema::Config';

__PACKAGE__->load_namespaces;

# Created by DBIx::Class::Schema::Loader v0.07039 @ 2015-02-23 16:54:04
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:JjSNFVtFx/myDsjjQHMaZQ

use URI;

sub filter_loaded_credentials {
    my $class = shift;

    my $res = $class->next::method( @_ );

    if ( exists $ENV{DATABASE_URL} ) {
        my $var = $ENV{DATABASE_URL};
        $var =~ s/^postgres/db:pg/;

        my $uri = URI->new( $var );

        $res->{dsn}      = $uri->dbi_dsn;
        $res->{user}     = $uri->user;
        $res->{password} = $uri->password;
    }

    return $res;
}

1;
