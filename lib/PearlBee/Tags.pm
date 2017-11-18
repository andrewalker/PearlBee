package PearlBee::Tags;

# ABSTRACT: Tags-related paths
use Dancer2 appname => 'PearlBee';

prefix '/tags' => sub {
    get '' => sub {

    };

    post '/new' => sub {

    };

    post '/update/:id' => sub {

    };

    post '/delete/:id' => sub {

    };
};

get '/tag/:name' => sub {

};

1;
