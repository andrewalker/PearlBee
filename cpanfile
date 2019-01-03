requires 'Moo';
requires 'Type::Tiny';
requires 'Dancer2' => 0.206000;
requires 'Dancer2::Plugin::DBIC';
requires 'Dancer2::Plugin::REST';
requires 'Dancer2::Plugin::Feed';
requires 'Dancer2::Plugin::Auth::Tiny';
requires 'Dancer2::Template::Xslate';
requires 'Text::Handlebars';
requires 'RBAC::Tiny' => 0.003;
requires 'DBIx::Class';
requires 'DBIx::Class::Schema::Config';
requires 'DBD::Pg';
requires 'Module::Runtime';

requires 'DateTime';
requires 'DateTime::Format::Pg';
requires 'Time::Ago';

requires 'Data::GUID';
requires 'Data::Pageset';
requires 'DBIx::Class::EncodedColumn';
requires 'Crypt::Eksblowfish::Bcrypt';

requires 'String::Dirify';
requires 'String::Random';
requires 'String::Util';
requires 'String::Truncate';
requires 'Text::Unidecode';

requires 'Authen::SASL';
requires 'MIME::Base64';
requires 'Email::Sender::Simple';
requires 'Email::MIME';
requires 'XML::Simple';
requires 'Gravatar::URL';
requires 'URI::db';
requires 'URI::Encode';
requires 'Text::Markdown::Hoedown';

# speed up Dancer2
requires 'Scope::Guard';
requires 'URL::Encode::XS';
requires 'CGI::Deurl::XS';
requires 'HTTP::Parser::XS';
requires 'Math::Random::ISAAC::XS';

# for the captcha
requires 'Authen::Captcha';
requires 'GD';

on 'develop' => sub {
    requires 'Code::TidyAll';
    requires 'Text::Diff' => 1.44;
    requires 'DBIx::Class::Schema::Loader';
    requires 'App::Sqitch';
};

on 'test' => sub {
    requires 'Test::WWW::Mechanize::PSGI';
};
