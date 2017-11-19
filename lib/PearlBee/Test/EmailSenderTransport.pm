package PearlBee::Test::EmailSenderTransport;
use strict;
use warnings;
use parent 'Email::Sender::Transport::Test';
use Email::Sender::Failure;

# delivery fails if email is failme@*
sub recipient_failure {
    my ($self, $to) = @_;

    return Email::Sender::Failure->new( message => 'Oh no!' )
        if $to =~ /^failme\@/;
}

1;
