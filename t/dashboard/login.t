use PearlBee::Test;

subtest 'successful login author' => sub {
    my $mech = mech;

    schema->resultset('User')->search({ email => 'johndoe@gmail.com' })->delete;
    schema->resultset('User')->create({
        username   => 'johndoe',
        email      => 'johndoe@gmail.com',
        first_name => 'John',
        last_name  => 'Doe',
        role       => 'author',
        status     => 'active',
    });

    $mech->get_ok('/sign-up', 'Sign-up returns a page');
    $mech->submit_form_ok({
        with_fields => $user_details,
    }, 'Was able to submit form');

    # If we weren't able to test the successful case, then the tests ensuring we
    # couldn't insert will be useless, so we bail out.
    ok(my $row = schema->resultset('User')->search({ email => 'johndoe@gmail.com' })->first, 'found row in the database')
      or BAIL_OUT 'Insert is not working, the rest of the tests are irrelevant';

    is( $row->$_, $expected{$_}, "New user's $_ has the expected value" ) for keys %expected;

    $mech->content_like(qr/The user was created and it is waiting for admin approval/, 'the user is presented with the expected message');

    schema->resultset('User')->search({ email => 'johndoe@gmail.com' })->delete;
};

done_testing;
