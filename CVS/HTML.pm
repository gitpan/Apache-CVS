# $Id: HTML.pm,v 1.3 2002/04/23 04:18:28 barbee Exp $

=head1 NAME

Apache::CVS::HTML - subclass of Apache::CVS that prints HTML

=head1 SYNOPSIS

    <Location /cvs>
        SetHandler perl-script
        PerlHandler Apache::CVS::HTML
        PerlSetVar CVSRoots cvs1=>/usr/local/CVS
    </Location>

=head1 DESCRIPTION

This is a subclass of C<Apache::CVS>. Please see its pod page for
definitive documentation. C<Apache::CVS::HTML> override all of the print_*
methods to display directories, files and revisions in HTML tables. Diffs
are displayed as plain text. There is also a little directory indicator at the
top of every page.

=cut

package Apache::CVS::HTML;

use strict;

use Apache::CVS();
@Apache::CVS::HTML::ISA = ('Apache::CVS');

$Apache::CVS::HTML::VERSION = $Apache::CVS::VERSION;;

my @time_units = ('days', 'hours', 'minutes', 'seconds');

sub print_error {
    my $self = shift;
    my $error = shift;
    $self->print_http_header();
    $self->print_page_header();
    $error =~ s/\n/<br>/g;
    $self->print_error($error);
    $self->print_html_footer();
}

sub print_page_header {
    my $self = shift;
    return if $self->page_headers_sent();
    $self->request()->print('<html>
                             <head>
                                <title>Apache::CVS</title>
                             </head>
                             <body bgcolor=white>');
    $self->print_path_links();
    $self->page_headers_sent(1);
}

sub print_page_footer {
    shift->{request}->print('</body></html>');
}

sub print_path_links {
    my $self = shift;
    my ($is_revision) = @_;

    my $rpath = $self->request()->parsed_uri->rpath();
    my $cvsroot = $self->current_root();
    my $filename = $self->path();
    my $cvsroot_path = $self->current_root_path();
    # strip out unnecessary stuff
    $filename =~ s/$cvsroot_path//;
#    $filename =~ s#[^/]*/?$## unless $is_revision;

    # top / root / file
    my $path = qq($rpath/$cvsroot$filename);

    my $link = qq(<a href=$rpath>top</a>);
    $link .= qq(:: <a href=$rpath/$cvsroot>$cvsroot</a>);

    my $parents;
    foreach ( split m#/#, $filename ) {

        next unless $_;
        $link .= qq(:: <a href="$rpath/$cvsroot$parents/$_">$_</a>);
        $parents .= qq(/$_) if $_;
    }

    $link .= q(<p>);

    $self->request()->print($link);
}

sub print_root {
    my $self = shift;
    my $root = shift;
    $self->request()->print('<a href="' .
                            $self->request()->parsed_uri->rpath() .
                            qq(/$root">$_</a><br>));
}

sub print_root_list_header {
    my $self = shift;
    $self->request()->print('available cvs roots<p>');
}

sub print_root_list_footer {
    return;
}

sub print_directory_list_header {
    my $self = shift;
    $self->request()->print('<table border=1 cellpadding=2 cellspacing=0>
                                <tr>
                                <th>filename</th>
                                <th>author</th>
                                <th>number of revisions</th>
                                <th>latest revision</th>
                                <th>most recent revision date</th>
                                <th>revision age</th>
                                </tr>');
}

sub print_directory {
    my $self = shift;
    my ($uri_base, $directory) = @_;
    my $uri = $uri_base. $directory->name();
    $self->request()->print("<tr>
                             <td><a href=$uri>" .
                                  $directory->name() .
                                  '</a></td>
                             <td>&nbsp;</td>
                             <td>&nbsp;</td>
                             <td>&nbsp;</td>
                             <td>&nbsp;</td>
                             <td>&nbsp;</td>
                             </tr>');
}

sub print_file {
    my $self = shift;
    my ($uri_base, $file) = @_;
    my $uri = $uri_base . $file->name();
    my $revision = $file->revision('last');
    $self->request()->print('<tr>');
    $self->request()->print("<td><a href=$uri>" . $file->name() . '</a></td>');
    $self->request()->print('<td>' . $revision->author() . '</td>');
    $self->request()->print('<td>' . $file->revision_count() . '</td>');
    $self->request()->print('<td>' . $revision->number() . '</td>');
    $self->request()->print('<td>' . localtime($revision->date()) . '</td>');

    my $age = join(', ',
                   map { $revision->age()->{$_} . ' ' . $_ } @time_units);
    $self->request()->print("<td>$age</td>");
    $self->request()->print('</tr>');
}

sub print_plain_file() {
    my $self = shift;
    my $file = shift;
    $self->request()->print('<tr><td>' . $file->name() . '</td>');
    $self->request()->print('<td>&nbsp;</td> <td>&nbsp;</td>');
    $self->request()->print('<td>&nbsp;</td> <td>&nbsp;</td>');
    $self->request()->print('<td>&nbsp;</td> </tr>');
}

sub print_directory_list_footer {
    my $self = shift;
    $self->request()->print('</table>');
}

sub print_file_list_header {
    my $self = shift;
    $self->request()->print('<table border=1 cellpadding=0 cellspacing=0>
                             <tr>
                                <th>revision number</th>
                                <th>author</th>
                                <th>state</th>
                                <th>symbol</th>
                                <th>date</th>
                                <th>age</th>
                                <th>comment</th>
                                <th>action</th>');
}

sub print_file_list_footer {
    my $self = shift;
    $self->request()->print('</table>');
}

sub print_revision {
    my $self = shift;
    my ($uri_base, $revision, $diff_revision) = @_;
    my $revision_uri = "$uri_base?r=" . $revision->number();
    my $date = localtime($revision->date());
    my $age = join(', ',
                   map { $revision->age()->{$_} . ' ' . $_ } @time_units);
    my $symbol = $revision->symbol() || '&nbsp;';
    $self->request()->print("<tr>
                             <td><a href=$revision_uri>" .
                             $revision->number() . '</td>' .
                             '<td>' . $revision->author() . '</td>' .
                             '<td>' . $revision->state() . '</td>' .
                             "<td>$symbol</td><td>$date</td><td>$age</td>" .
                             '<td>' . $revision->comment() . '</td>');
    if ($diff_revision eq $revision->number()) {
        $self->request()->print('<td>selected for diff</td>');
    } else {
        if ($diff_revision) {
            $self->request()->print(qq|<td><a href="$uri_base?ds=| .
                                    $revision->number()  .
                                    qq|&dt=$diff_revision">select for diff | .
                                    "with $diff_revision</a>");
        } else {
            $self->request()->print(qq|<td><a href="$uri_base?ds=| .
                                    $revision->number()  .
                                    '">select for diff</a>');
        }
    }
    $self->request()->print('</tr>');
}

sub print_text_revision {
    my $self = shift;
    my $content = shift;
    $self->request()->print('<pre>');
    $content =~ s/</&lt;/g;
    $content =~ s/>/&gt;/g;
    $self->request()->print($content);
    $self->request()->print('</pre>');
}

sub print_diff {
    my ($self, $diff, $uri_base) = @_;
    my @content;

    eval {
        @content = @{ $diff->content() };
    };
    if ($@) {
        $self->request()->log_error($@);
        $self->print_http_header();
        $self->print_page_header();
        $self->request()->print("<p>Unable to get diff.<br>$@");
        $self->print_page_footer();
        return;
    }

    unless (scalar @content) {
        $self->request()->print('There is no difference between the versions.');
        return;
    }
    if (scalar keys %{ $self->diff_styles()} > 1) {
        # print a bunch of links for the different diff styles
        my ($source_revision, $target_revision);
        eval {
            $source_revision = $diff->source()->number();
            $target_revision = $diff->target()->number();
        };
        if ($@) {
            $self->request()->log_error($@);
            $self->print_http_header();
            $self->print_page_header();
            $self->request()->print("<p>Unable to get diff.<br>$@");
            $self->print_page_footer();
            return;
        }
        $self->request()->print(qq|<td><a href="$uri_base?ds=$source_revision&dt=$target_revision&dy=$_">$_</a>&nbsp;|) foreach keys %{ $self->diff_styles()};
        $self->request()->print(qq|<br>|);
    }
    $self->request()->print('<pre>');
    while (my $line = shift @content) {
        $line =~ s/</&lt;/g;
        $line =~ s/>/&gt;/g;
        $self->request()->print($line);
    }
    $self->request()->print('</pre>');
}

=head1 SEE ALSO

L<Apache::CVS>

=head1 AUTHOR

John Barbee, F<barbee@veribox.net>

=head1 COPYRIGHT

Copyright 2001-2002 John Barbee

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

1;
