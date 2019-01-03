package Dancer2::Template::Handlebars;
use strict;
use warnings;
use Moo;
use Text::Handlebars;
use Dancer2::FileUtils 'path';
use URI::Encode ();
use DateTime;
use DateTime::Format::Strptime;
use Time::Ago;

extends 'Dancer2::Template::Xslate';

has '+default_tmpl_ext' => ( default => 'hbs' );
has '+views'            => ( default => '' );

{
    my %conversion = (
        'YYYY' => 'yyyy',
        'DDDD' => 'DDD',
        'dddd' => 'eeee',
        'DDD'  => 'D',
        'ddd'  => 'eee',
        'YY'   => 'yy',
        'DD'   => 'dd',
        'D'    => 'd',
        'd'    => 'e',
        'A'    => 'a',
    );
    my $re = join '|', sort { length($b) <=> length($a) } keys %conversion;

    sub momentjs2cldr {
        my $format = shift;
        my $result = $format;

        $result =~ s/\G($re)/$conversion{$1}/gm;

        return $result;
    }
}

sub _build_engine {
    my ($self) = @_;

    my %config = (
        %{ $self->config },
        suffix => ".hbs",
        helpers => {
            is => sub {
                my ( $context, $requested_context, $options ) = @_;
                my @req_ctxs = map s/^\s+|\s+$//rg, (split /,/, $requested_context);
                my $root = $context;
                while (exists $root->{'..'}) {
                    $root = $root->{'..'};
                }
                my $result;

                if (!$root->{context}) {
                    $result = 0;
                }
                else {
                    my $root_ctx = $root->{context};
                    ($result) = grep /^$root_ctx$/, @req_ctxs;
                }

                return $result
                    ? $options->{fn}->($context)
                    : $options->{inverse}->($context)
                    ;
            },
            has => sub {
                my ( $context, $options ) = @_;

                sub evaluate_author_list {
                    die 'TODO: https://github.com/TryGhost/Ghost/blob/master/core/server/helpers/has.js';
                }

                sub handle_count {
                    my ($ctx_attr, $data) = @_;

                    if ( $ctx_attr =~ /count:(\d+)$/ ) {
                        return $1 == @$data;
                    }
                    elsif ( $ctx_attr =~ /count:>(\d+)$/ ) {
                        return $1 < @$data;
                    }
                    elsif ( $ctx_attr =~ /count:<(\d+)$/ ) {
                        return $1 > @$data;
                    }
                    else {
                        warn "Could not parse $ctx_attr";
                        return 0;
                    }
                }

                sub handle_author {
                    my ( $attrs, $data ) = @_;
                    if ( !$attrs->{author} ) {
                        return 0;
                    }

                    if ( $attrs->{author} =~ /count\:/ ) {
                        return handle_count( $attrs->{author}, $data->{authors} );
                    }

                    return evaluate_author_list( $attrs->{author}, $data->{authors} );
                }

                my @valid_attrs = ('tag', 'author', 'slug', 'id', 'number', 'index', 'any', 'all');
                my %attrs = map +($_, $options->{hash}{$_}), grep exists $options->{hash}{$_}, @valid_attrs;
                my %checks = (
                    author => sub { handle_author(\%attrs, $context) },
                    # TODO: all the rest
                );

                return (grep $checks{$_}->(), keys %attrs)
                    ? $options->{fn}->($context)
                    : $options->{inverse}->($context);
            },
            get            => sub { warn 'TODO! get'; return '' },
            plural         => sub { warn 'TODO! plural'; return '' },
            contentFor     => sub {
                my ( $context, $name, $options ) = @_;
                push @{ $context->{_blocks}{$name} }, $options->{fn}->($context);
                return "";
            },
            block          => sub {
                my ( $context, $name, $options ) = @_;
                join "\n", @{ $context->{_blocks}{$name} // [''] };
            },
            encode         => sub {
                my ( $context, $text, $options ) = @_;
                return URI::Encode::uri_encode($text);
            },
            excerpt        => sub { shift->{abstract} },
            self_avatar    => sub { pop; shift->{vars}{user}->avatar(@_) },
            user_is        => sub {
                my ( $context, $user, $options ) = @_;
                my $root = $context;
                while (exists $root->{'..'}) {
                    $root = $root->{'..'};
                }
                if ($root->{vars}{user}->id == $user) {
                    $options->{fn}->($context);
                }
                else {
                    $options->{inverse}->($context);
                }
            },
            time_ago => sub {
                my ( $context, $time, $options ) = @_;
                # FIXME: we force English here because otherwise Time::Ago will use the
                # system locale. That would be fine, except the rest of the content is not
                # localized, so this could mean only the time is translated, while the rest
                # is English. Better to keep it in English only until we implement i18n in
                # the whole application.
                local $ENV{LANGUAGE} = 'en';
                my $dt = DateTime::Format::Strptime->new( pattern => '%F %T%z' )->parse_datetime($time);
                my $diff = DateTime->now->set_time_zone('UTC')->epoch - $dt->set_time_zone('UTC')->epoch;

                return Time::Ago->in_words($diff) . ' ago';
            },
            facebook_url   => sub {
                my ( $context, $username, $options ) = @_;
                my $root = $context;
                while (exists $root->{'..'}) {
                    $root = $root->{'..'};
                }
                my $handle = $root->{'@blog'}{'facebook'} || $username;
                my $uri = URI->new("https://www.facebook.com");
                $uri->path($handle);
                return "$uri";
            },
            twitter_url   => sub {
                my ( $context, $username, $options ) = @_;
                my $root = $context;
                while (exists $root->{'..'}) {
                    $root = $root->{'..'};
                }
                my $handle = $root->{'@blog'}{'twitter'} || $username;
                my $uri = URI->new("https://www.twitter.com");
                $uri->path($handle);
                return "$uri";
            },
            join => sub {
                my ( $context, $separator, $array, $options ) = @_;
                join $separator, @$array;
            },
            uri_for => sub {
                my $options = pop;
                my ( $context, $uri, @replacements ) = @_;
                return sprintf $uri, @replacements;
            },
            url2           => sub {
                my ( $context, $ref, $options ) = @_;
                return $context->{url};
            },
            date           => sub {
                my ( $context, $ref, $options ) = @_;
                my $format = momentjs2cldr($ref->{format});
                my $dt;
                if ($context->{created_at}) {
                    $dt = DateTime::Format::Strptime->new( pattern => '%F %T%z' )->parse_datetime($context->{created_at});
                }
                else {
                    $dt = DateTime->now;
                }

                return $dt->format_cldr($format);
            },
            asset          => sub {
                my ( $context, $ref, $options ) = @_;
                return "/assets/$ref";
            },
            subscribe_form => sub { warn 'TODO! subscribe_form'; return '' },
            each           => sub {
                my ( $context, $ref, $options ) = @_;
                if ( ref $ref eq 'HASH' ) {
                    return join '', map {
                        $options->{fn}->( { '@key' => $_, '.' => $ref->{$_} } )
                    } sort keys %$ref;
                } else {
                    return join '', map { $options->{fn}->($_) } @$ref;
                }
            },
            foreach => sub {
                my ( $context, $ref, $options ) = @_;
                if ( ref $ref eq 'HASH' ) {
                    return join '', map {
                        $options->{fn}->( { '@key' => $_, '.' => $ref->{$_} } )
                    } sort keys %$ref;
                } else {
                    return join '', map { $options->{fn}->($_) } @$ref;
                }
            }
        }
    );

    # Dancer2 injects a couple options without asking; Text::Xslate protests:
    delete $config{environment};

    return Text::Handlebars->new(%config);
}

# XXX: don't repeat views directory here
sub view_pathname {
    my ( $self, $view ) = @_;

    return $self->_template_name($view);
}
sub layout_pathname {
    my ( $self, $layout ) = @_;

    return path( $self->layout_dir, $self->_template_name($layout) );
}

sub render_layout {
    my ( $self, $layout, $tokens, $content ) = @_;
    $layout = $self->layout_pathname($layout);
    $self->render( $layout, { %$tokens, body => $content } );
}

before render => sub {
    my ($self, $tmpl, $vars) = @_;
    $vars->{'@blog'} = {
        title       => $self->settings->{site}{name},
        cover_image => "https://demo.ghost.io/content/images/2017/07/blog-cover.jpg",
        logo        => $self->settings->{site}{logo},
        description => $self->settings->{site}{tagline},
        url         => "http://localhost:5000/",
        twitter     => "blogs_perl_org",
        facebook    => "BlogsPerlOrg",
    };
};

1;
