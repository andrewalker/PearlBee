use utf8;
package PearlBee::Model::Schema;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Schema::Config';

__PACKAGE__->load_namespaces;


# Created by DBIx::Class::Schema::Loader v0.07047 @ 2017-11-20 10:43:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:+Cag3+jI+2hc8ixM4SNPUQ

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
