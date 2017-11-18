requires 'Moo';
requires 'Type::Tiny';
requires 'Dancer2' => 0.163000;
requires 'Dancer2::Plugin::DBIC';
requires 'Dancer2::Plugin::REST';
requires 'Dancer2::Plugin::Auth::Tiny';
requires 'RBAC::Tiny' => 0.003;
requires 'DBIx::Class';
requires 'DBIx::Class::Schema::Config';
requires 'DBD::Pg';
requires 'HTML::Strip';
requires 'Template::Plugin::HTML::Strip';
requires 'Module::Runtime';

requires 'DateTime';
requires 'DateTime::TimeZone';

requires 'Data::GUID';
requires 'Data::Pageset';
requires 'DBIx::Class::EncodedColumn';
requires 'Crypt::Eksblowfish::Bcrypt';

requires 'String::Dirify';
requires 'String::Random';
requires 'String::Util';

requires 'MIME::Base64';
requires 'Email::Template';
requires 'XML::Simple';
requires 'Gravatar::URL';

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
};

on 'test' => sub {
    requires 'Test::WWW::Mechanize::PSGI';
};
