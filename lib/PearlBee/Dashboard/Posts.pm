package PearlBee::Dashboard::Posts;
use Dancer2 appname => 'PearlBee';
use Dancer2::Plugin::DBIC;
use Dancer2::Plugin::Auth::PearlBee;

use PearlBee::Helpers::Pagination qw<
    get_total_pages
    get_previous_next_link
    generate_pagination_numbering
>;

use DateTime;
use URI::Escape;

sub change_post_state {
    my ( $id, $state ) = @_;
    my $post = resultset('Post')->find($id);
    my $user = var('user');

    # FIXME: these methods check if the user is authorized
    #        we should put this action elsewhere
    eval {
        $post->$state($user);
        1;
    } or do {

        # FIXME: don't just report the error, show the user as well
        #        GH#9
        my $error = $@ || 'Zombie error';
        error $error;
    };

    return config->{'app_url'} . '/dashboard/posts';
}

prefix '/dashboard/posts' => sub {
    get '/?' => needs_permission view_post => sub {
        my $page   = query_parameters->{'page'}   || 1;
        my $status = query_parameters->{'status'} || '';
        my $nr_of_rows = 5;
        my $search_parameters = $status ? { status => $status } : {};

        my @posts = resultset('Post')->search(
            $search_parameters,
            {
                order_by => { -desc => 'created_date' },
                rows     => $nr_of_rows,
                page     => $page
            }
        );
        my $count = resultset('View::Count::StatusPost')->first;

        my ( $all, $publish, $draft, $trash ) = $count->get_all_status_counts;

        # FIXME: temporary override of $all because "ugh"
        #        Uses the View::Count::StatusPost
        #        which doesn't allow specifying an optional post status
        #        why have two methods instead of a method with a parameter?
        $status and $all = $count->get_status_count($status);

        my $action_url = "/dashboard/posts?status=" . uri_escape($status);

        # Calculate the next and previous page link
        my $total_pages = get_total_pages( $all, $nr_of_rows );
        my ( $previous_link, $next_link )
            = get_previous_next_link( $page, $total_pages, $action_url );

        # Generating the pagination navigation
        my $total_posts    = $all;
        my $posts_per_page = $nr_of_rows;
        my $current_page   = $page;
        my $pages_per_set  = 7;
        my $pagination
            = generate_pagination_numbering( $total_posts, $posts_per_page,
            $current_page, $pages_per_set );

        template 'admin/posts/list' => {
            posts         => \@posts,
            trash         => $trash,
            draft         => $draft,
            publish       => $publish,
            all           => $all,
            page          => $page,
            next_link     => $next_link,
            status        => $status,
            previous_link => $previous_link,
            action_url    => $action_url,
            pages         => $pagination->pages_in_set
        } => { layout => 'admin' };
    };

    get '/new' => needs_permission create_post => sub {
        template 'admin/posts/add' => {} => { layout => 'admin' };
    };

    post '/new' => needs_permission create_post => sub {
        my $post;

        eval {
            # Set the proper timezone
            my $dt       = DateTime->now;
            $dt->set_time_zone( config->{timezone} );

            my $parameters = body_parameters;
            my $user       = var('user');
            my ( $slug, $changed )
                = resultset('Post')->check_slug( $parameters->{'slug'} );
            session warning =>
                'The slug was already taken but we generated a similar slug for you! Feel free to change it as you wish.'
                if ($changed);

            # Upload the cover image first so we'll have the generated filename ( if exists )
            my $cover_filename;
            if ( upload('cover') ) {
                my $cover = upload('cover');
                $cover_filename = generate_crypted_filename();
                my ($ext)
                    = $cover->filename =~ /(\.[^.]+)$/; #extract the extension
                $ext = lc($ext);
                $cover_filename .= $ext;

                $cover->copy_to(
                    config->{'covers_folder'} . $cover_filename );
            }

            # Next we can store the post into the database safely
            my $dtf    = schema->storage->datetime_parser;
            my $params = {
                title        => $parameters->{'title'},
                slug         => $slug,
                content      => $parameters->{'post'},
                user_id      => $user->id,
                status       => $parameters->{'status'},
                cover        => ($cover_filename) ? $cover_filename : '',
                created_date => $dtf->format_datetime($dt),
            };

            # XXX: this *does* create, not just *try* to create
            $post = resultset('Post')->can_create($params);

            # Insert the categories selected with the new post
            resultset('PostCategory')
                ->connect_categories( $parameters->{'category'}, $post->id );

            # Connect and update the tags table
            resultset('PostTag')
                ->connect_tags( $parameters->{'tags'}, $post->id );

            1;
        } or do {
            my $error = $@ || 'Zombie error';
            error $error;

            # FIXME: report error too (Deferred?)
            redirect config->{'app_url'} . '/dashboard/posts/new';
        };

        # If the post was added successfully, store a success message to show on the view
        session success => 'The post was added successfully';

        # If the user created a new post redirect him to the post created
        redirect config->{'app_url'} . '/dashboard/posts/edit/' . $post->slug;
    };

    foreach my $state (qw<publish draft trash>) {
        get "/$state/:id" => needs_permission update_post => sub {
            my $new_url
                = change_post_state( route_parameters->{'id'}, $state, );

            redirect $new_url;
        };
    }

    # FIXME: edit using the ID, not the slug (required editing edit links in the template)
    get '/edit/:slug' => needs_permission update_post => sub {
        my $post_slug = route_parameters->{'slug'};
        my $post = resultset('Post')->find( { slug => $post_slug } );

        # Prepare tags for the UI
        my $joined_tags = join ', ', map $_->tag->name, $post->post_tags;

        my $params = {
            post           => $post,
            tags           => $joined_tags,
        };

        # Check if there are any messages to show
        # Delete them after stored on the stash
        if ( session('warning') ) {
            $params->{'warning'} = session('warning');
            session warning => undef;
        } elsif ( session('success') ) {
            $params->{'success'} = session('success');
            session success => undef;
        }

        template 'admin/posts/edit' => $params => { layout => 'admin' };
    };

    post '/update/:id' => needs_permission update_post => sub {
        my $params  = body_parameters;
        my $post_id = route_parameters->{'id'};
        my $post    = resultset('Post')->find( { id => $post_id } );
        my $title   = $params->{'title'};
        my $content = $params->{'post'};
        my $tags    = $params->{'tags'};

        my ( $slug, $changed )
            = resultset('Post')->check_slug( $params->{'slug'}, $post->id );
        session warning =>
            'The slug was already taken but we generated a similar slug for you! Feel free to change it as you wish.'
            if ($changed);

        eval {
            # Upload the cover image
            my $cover;
            my $ext;
            my $crypted_filename;

            if ( upload('cover') ) {

                # If the user uploaded a cover image, generate a crypted name for uploading
                $crypted_filename = generate_crypted_filename();
                $cover            = upload('cover');
                ($ext)
                    = $cover->filename =~ /(\.[^.]+)$/; #extract the extension
                $ext = lc($ext);
                $cover->copy_to(
                    config->{'covers_folder'} . $crypted_filename . $ext );
            }

            my $status = $params->{'status'} || '';
            $post->update(
                {
                    title => $title,
                    slug  => $slug,
                    cover => ($crypted_filename)
                    ? $crypted_filename . $ext
                    : $post->cover,
                    status  => $status,
                    content => $content,
                }
            );

            $post->post_tags->delete;
            $post->add_to_post_tags({ tag => $_ })
                for split /,/, params->{'tags'};

            session success => 'The post was updated successfully!';

            1;
        } or do {
            my $error = $@ || 'Zombie error';
            error $error;
        };

        redirect config->{'app_url'} . '/dashboard/posts/edit/' . $post->slug;
    };
};

1;
