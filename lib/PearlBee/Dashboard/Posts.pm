package PearlBee::Dashboard::Posts;
use Dancer2 appname => 'PearlBee';
use Dancer2::Plugin::DBIC;
use Dancer2::Plugin::Auth::PearlBee;
use PearlBee::Model::Posts;

my $model = PearlBee::Model::Posts->new(
    user_rs     => resultset('User'),
    post_rs     => resultset('Post'),
    post_tag_rs => resultset('PostTag'),
    uri_for     => \&uri_for,
);

get '/dashboard/edit/:id' => needs_permission update_post => sub {
    my $post_id = route_parameters->{id};

    my ($post) = $model->search_posts({
        id             => $post_id,
        only_published => 0,
    });

    my $tmpl_data = {
        post         => $post,
        current_page => 'edit-post',
    };

    if (query_parameters->{'error'}) {
        my $form_data = session 'form_data';
        $tmpl_data->{post} = $form_data
          if $form_data;
        session( form_data => undef );
        $tmpl_data->{error} = query_parameters->{'error'};
    }
    elsif (query_parameters->{'updated'}) {
        $tmpl_data->{success} = 'Successfully updated';
    }
    elsif (query_parameters->{'created'}) {
        $tmpl_data->{success} = 'Successfully created';
    }

    template 'dashboard/edit' => $tmpl_data => { layout => 'dashboard' };
};

post '/dashboard/edit/:id' => needs_permission update_post => sub {
    my $user_id = session 'user_id';
    my $post_id = route_parameters->{id};

    # TODO: deal with meta
    my %params = %{ body_parameters() };
    $params{tags} = [
        map s/^\s+|\s+$//g, split ',', body_parameters->{'tags'}
    ];

    my ($post, $error) = $model->update_post($user_id, $post_id, \%params);

    if ($error) {
        session( form_data => body_parameters );
        redirect "/dashboard/edit/$post_id?error=$error";
    }
    else {
        redirect "/dashboard/edit/$post_id?updated=1";
    }
};

get '/dashboard/compose' => needs_permission create_post => sub {
    my $tmpl_data = { current_page => 'new', };
    if (query_parameters->{'error'}) {
        $tmpl_data->{post} = session 'form_data';
        session( form_data => undef );
        $tmpl_data->{error} = query_parameters->{'error'};
    }
    template 'dashboard/compose' => $tmpl_data => { layout => 'dashboard' };
};

post '/dashboard/compose' => needs_permission create_post => sub {
    my $user_id = session 'user_id';

    # TODO: deal with meta
    my %params = %{ body_parameters() };
    $params{tags} = [
        map s/^\s+|\s+$//g, split ',', body_parameters->{'tags'}
    ];

    my ($post, $error) = $model->create_post($user_id, \%params);

    if ($error) {
        session( form_data => body_parameters );
        redirect '/dashboard/compose?error=' . $error;
    }
    else {
        redirect '/dashboard/edit/' . $post->id . '?created=1';
    }
};

get '/dashboard/posts' => needs_permission view_post => sub {
    my %sort = map +($_, $_), qw( id created_at updated_at );
    my %dir  = map +($_, "-$_"), qw( asc desc );

    my $per_page  = int(query_parameters->{'per_page'} // 0) || 10;
    my $page      = int(query_parameters->{'page'}     // 0) || 1;
    my $sort      = $sort{ query_parameters->{'sort'}      || 'created_at' } || 'created_at';
    my $direction = $dir{  query_parameters->{'direction'} || 'desc' }       || '-desc';

    if ($per_page > 50) {
        $per_page = 50;
    }

    my @posts = $model->search_posts({
        author         => session('user_id'),
        per_page       => $per_page,
        page           => $page,
        sort           => $sort,
        direction      => $direction,
        tags           => query_parameters->{'tags'},
        filter         => query_parameters->{'filter'},
        only_published => 0,
    });

    template 'dashboard/posts' => {
        posts        => \@posts,
        current_page => 'posts',
    } => { layout => 'dashboard' };
};

1;
