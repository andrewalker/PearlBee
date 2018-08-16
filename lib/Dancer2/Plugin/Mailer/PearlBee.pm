package Dancer2::Plugin::Mailer::PearlBee;
use strict;
use warnings;
use feature 'state';
use Dancer2::Plugin;
use Email::Sender::Simple;
use Email::MIME;
use Text::Handlebars;
use HTML::Entities 'encode_entities';

has 'renderer_args' => (
    'lazy'    => 1,
    'is'      => 'ro',
    'default' => sub {
        my $self = shift;
        return {
            path    => $self->path,
            helpers => {
                uri_for => sub {
                    my ($context, $uri, $args) = @_;
                    encode_entities $self->dsl->uri_for($uri, $args // {});
                },
            },
        };
    },
);

has 'path' => (
    'is'          => 'ro',
    'from_config' => 1,
    'default'     => sub { 'views/emails' },
);

has 'from' => (
    'is'          => 'ro',
    'from_config' => 1,
    'default'     => sub { 'noreply@example.com' },
);

has 'renderer' => (
    'is'      => 'ro',
    'lazy'    => 1,
    'default' => sub {
        my ($self) = @_;
        Text::Handlebars->new( %{ $self->renderer_args } );
    },
);

sub sendmail :PluginKeyword {
    my ($self, $email_data) = @_;

    my $to = $email_data->{name}
        ? "\"$email_data->{name}\" <$email_data->{email_address}>"
        : $email_data->{email_address}
        ;

    $email_data->{variables}{settings} = $self->dsl->config;
    my $body = $self->renderer->render($email_data->{template_file}, $email_data->{variables});

    my $email = Email::MIME->create(
        header_str => [
            To      => $to,
            From    => $self->from,
            Subject => $email_data->{subject},
        ],
        attributes => {
            content_type => 'text/html',
            charset      => 'UTF-8',
            encoding     => 'quoted-printable',
        },
        body_str => $body,
    );

    if (exists $ENV{EMAIL_SENDER_TRANSPORT}) {
        Email::Sender::Simple->send($email);
    }
    else {
        warn "Please set EMAIL_SENDER_TRANSPORT. No e-mails will be sent if it is not set.";
    }
}

1;
