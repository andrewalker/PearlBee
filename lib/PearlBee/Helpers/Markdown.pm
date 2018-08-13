package PearlBee::Helpers::Markdown;
use strict;
use warnings;
use Text::Markdown::Hoedown ();
use Text::Xslate ();
use Exporter 'import';

our @EXPORT_OK = 'markdown';

sub markdown {
    my $md = shift;
    return Text::Xslate::mark_raw(
        Text::Markdown::Hoedown::markdown( $md,
            extensions => Text::Markdown::Hoedown::HOEDOWN_EXT_TABLES
                        | Text::Markdown::Hoedown::HOEDOWN_EXT_FENCED_CODE
                        | Text::Markdown::Hoedown::HOEDOWN_HTML_SKIP_HTML
        )
    );
}

1;
