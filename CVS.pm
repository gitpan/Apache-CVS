# $Id: CVS.pm,v 1.19 2002/02/10 18:08:46 barbee Exp $

=head1 NAME

Apache::CVS - method handler provide a web interface to CVS repositories

=head1 SYNOPSIS

    <Location /cvs>
        SetHandler perl-script
        PerlHandler Apache::CVS::HTML
        PerlSetVar CVSRoots cvs1=>/usr/local/CVS
    </Location>

=head1 DESCRIPTION

C<Apache::CVS> is a method handler that provide a web interface to CVS
repositories. Please see L<"CONFIGURATION"> to see what configuration options
are available. To get started you'll at least need to set CVSRoots to your
local CVS Root directory.

C<Apache::CVS> is does not output the contents of your CVS repository on its
own. Rather, it is meant to be subclassed. A subclass that yields HTML output
is provided with C<Apache::CVS::HTML>. Please see L<"SUBCLASSING"> for details
on creating your own subclass.

=head1 CONFIGURATION

=item CVSRoots

    Location of the CVS Roots.  Set this like you would hash.  This
    variable is required.

    PerlSetVar CVSRoots cvs1=>/path/to/cvsroot1,cvs2=>/path/to/cvsroot2

=item RCSExtension

    File extension of RCS files.  Defaults to ',v'.

    PerlSetVar RCSExtension ,yourextension

=item WorkingDirectory

    A directory to keep temporary files.  Defaults to /var/tmp.
    Apache::CVS will try to clean up after itself and message to the
    error log if it couldn't.

    PerlSetVar WorkingDirectory /usr/tmp

=item BinaryDirectory

    The directory of the rcs binaries.  Defaults to /usr/bin.

    PerlSetVar BinaryDirectory /usr/local/bin

=cut

package Apache::CVS;

use strict;

use Apache::URI();
use Apache::CVS::RcsConfig();
use Apache::CVS::PlainFile();
use Apache::CVS::Directory();
use Apache::CVS::File();
use Apache::CVS::Revision();
use Apache::CVS::Diff();

$Apache::CVS::VERSION = '0.02';

=head1 SUBCLASSING

Override any or all of the following to customize the display.
Some of these method will take a $uri_base as an argument. It is the URI for
the current item that is being displayed. For example, if a directory is
being displayed, the base URI is the URI to that directory. If a revision is
being displayed, the base URI is the URI to that file.

=over 4

=item $self->print_http_header()

Prints the HTTP headers. If you override this you should set the
http_headers_sent flag with $self->http_headers_sent(1).

=cut

sub print_http_header {
    my $self = shift;
    return if $self->http_headers_sent();
    $self->request()->content_type($self->content_type());
    $self->request()->send_http_header;
    $self->http_headers_sent(1);
}

=item print_error

This method takes a string that contains the error.

=cut

sub print_error {
    return;
}

=item print_page_header

No arguments. If you override this you should set the page_headers_sent flag
with $self->page_headers_sent().

=cut

sub print_page_header {
    return;
}

=item print_page_footer

No arguments.

=cut

sub print_page_footer {
    return;
}

=item print_root_list_header

No arguments.

=cut

sub print_root_list_header {
    return;
}

=item print_root

A root as a string, defined by your CVSRoots configuration.

=cut

sub print_root {
    return;
}

=item print_root_list_footer

No arguments.

=cut

sub print_root_list_footer {
    return;
}

=item print_directory_list_header

No arguments.

=cut

sub print_directory_list_header {
    return;
}

=item print_directory

Takes a base uri and an Apache::CVS::Directory object.

=cut

sub print_directory {
    return;
}

=item print_file

Takes a base uri and an Apache::CVS::File object.

=cut

sub print_file {
    return;
}

=item print_plain_file

Takes a base uri and an Apache::CVS::PlainFile object.

=cut

sub print_plain_file {
    return;
}

=item print_directory_list_footer

No arguments.

=cut

sub print_directory_list_footer {
    return;
}

=item print_file_list_header

No arguments.

=cut

sub print_file_list_header {
    return;
}

=item print_revision

Takes a base uri, an Apache::CVS::Revision object and the revision number of
a revision that has been selected for diffing, if such exists.

=cut

sub print_revision {
    return;
}

=item print_file_list_footer

No arguments.

=cut

sub print_file_list_footer {
    return;
}

=item print_text_revision

Takes the content of the revision as a string.

=cut

sub print_text_revision {
    return;
}

=item print_diff

Takes an Apache::CVS::Diff object.

=cut

sub print_diff {
    return;
}

=back

=head1 OBJECT METHODS

Here are some other methods that might be useful.

=over 4

=cut

sub _get_roots {
    my $request = shift;
    my %cvsroots = split /\s*(?:=>|,)\s*/, $request->dir_config('CVSRoots');
    return \%cvsroots;
}

sub _get_rcs_config {
    my $request = shift;
    return Apache::CVS::RcsConfig->new($request->dir_config('RCSExtension'),
                                       $request->dir_config('WorkingDirectory'),
                                       $request->dir_config('BinaryDirectory'));
}

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $request = shift;
    my $self;

    $self->{request} = $request;
    $self->{rcs_config} = _get_rcs_config($self->{request});
    $self->{roots} = _get_roots($self->{request});
    $self->{content_type} = 'text/html';
    $self->{http_headers_sent} = 0;
    $self->{page_headers_sent} = 0;
    $self->{current_root} = undef;
    $self->{path} = undef;
    bless ($self, $class);
    return $self;
}

=item $self->request()

Returns the Apache request object.

=cut

sub request {
    my $self = shift;
    $self->{request} = shift if scalar @_;
    return $self->{request};
}

=item $self->rcs_config()

Returns the C<Apache::CVS:RcsConfig> object that holds the Rcs configuration.

=cut

sub rcs_config {
    my $self = shift;
    return $self->{rcs_config};
}

=item $self->content_type()

Set or get the content_type.

=cut

sub content_type {
    my $self = shift;
    $self->{content_type} = shift if scalar @_;
    return $self->{content_type};
}

=item $self->http_headers_sent()

Set or get this flag which indicates if the HTTP have been sent or not.

=cut

sub http_headers_sent {
    my $self = shift;
    $self->{http_headers_sent} = shift if scalar @_;
    return $self->{http_headers_sent};
}

=item $self->page_headers_sent()

Set or get this flag which indicates if the page headers have been sent or not.

=cut

sub page_headers_sent {
    my $self = shift;
    $self->{page_headers_sent} = shift if scalar @_;
    return $self->{page_headers_sent};
}

=item $self->path()

Set or get the path of to the file or directory requested.

=cut

sub path {
    my $self = shift;
    $self->{path} = shift if scalar @_;
    return $self->{path};
}

=item $self->current_root()

Set or get the CVS Root of the files being requested.

=cut

sub current_root {
    my $self = shift;
    $self->{current_root} = shift if scalar @_;
    return $self->{current_root};
}

=item $self->roots()

Returns the configured CVS Roots as a hash references.

=cut

sub roots {
    my $self = shift;
    return $self->{roots};
}

=item $self->current_root_path()

Returns the path of the CVS Root of the files being requested.
This is equivalent to $self->roots()->{$self->current_root()}.

=cut

sub current_root_path {
    my $self = shift;
    return $self->roots()->{$self->current_root()};
}

=back

=cut

sub handle_root {
     my $self = shift;
     $self->print_root($_) foreach ( keys %{ $self->roots()} );
 }

sub handle_directory {
    my $self = shift;
    my ($uri_base) = @_;
    $self->print_directory_list_header();
    my $directory = Apache::CVS::Directory->new($self->path(),
                                                $self->rcs_config());
    $directory->load();
    my @blah = @{ $directory->directories() };
    foreach ( @{ $directory->directories() } ) {
        $self->print_directory($uri_base, $_);
    }
    foreach ( @{ $directory->files() } ) {
        $self->print_file($uri_base, $_);
    }
    foreach ( @{ $directory->plain_files() } ) {
        $self->print_plain_file($_);
    }
    $self->print_directory_list_footer();
}

sub handle_file {
    my $self = shift;
    my ($uri_base, $diff_revision) = @_;
    $self->print_file_list_header();
    my $file = Apache::CVS::File->new($self->path(), $self->rcs_config());
    while ( my $revision = $file->revision('prev') ) {
        $self->print_revision("$uri_base" . $file->name(), $revision,
                              $diff_revision);
    }
    $self->print_file_list_footer();
}

sub handle_revision {
    my $self = shift;
    my ($uri_base, $revision) = @_;
    
    my $file = Apache::CVS::File->new($self->path(), $self->rcs_config());
    my $revision = $file->revision($revision);

    eval {
        if ($revision->is_binary()) {
            my $subrequest =
                $self->request()->lookup_file($revision->co_file());
            $self->content_type($subrequest->content_type);
            $self->print_http_header();
            $self->request()->send_fd($revision->filehandle());
            close $self->filehandle();
        } else {
            $self->print_http_header();
            $self->print_page_header();
            $self->print_text_revision($revision->content());
        }
    };
    if ($@) {
        $self->request()->log_error($@);
        $self->print_error("Unable to get revision.\n$@");
        return;
    }
}

sub handle_diff {
    my $self = shift;
    my ($source_version, $target_version) = @_;

    my $file = Apache::CVS::File->new($self->path(), $self->rcs_config());
    my $source = $file->revision($source_version);
    my $target = $file->revision($target_version);
    my $diff = Apache::CVS::Diff->new($source, $target);
    $self->print_diff($diff);
}

sub handler_internal {
    my $self = shift;

    my $path_info = $self->request()->path_info;

    my $is_real_root = 1 unless ( $path_info and $path_info ne '/' );

    # strip off the cvs root id from the front
    $path_info =~ s#/([^/]+)/?##;
    $self->current_root($1);

    # determine current path
    my $is_cvsroot;
    unless ( $path_info and $path_info ne '/' ) {

        $self->path($self->current_root_path());
        $is_cvsroot = 1;
    } else {

        $self->path($self->current_root_path() . q(/) .  $path_info);
    }

    my %query = $self->request()->args;
    my $is_revision = exists $query{'r'};

    if ( $is_real_root ) {

        $self->print_http_header();
        $self->print_page_header();
        $self->handle_root();
        return;
    }

    my $uri_base = $self->request()->parsed_uri->rpath() . q(/) .
                   $self->current_root() . q(/) .  $path_info;

    if ( -d $self->path() ) {

        $self->print_http_header();
        $self->print_page_header();
        $uri_base .= q(/) unless $uri_base =~ /\/$/;
        $self->handle_directory($uri_base);
    } else {

        $uri_base =~ s/[^\/]*$//;

        my %query = $self->request()->args;
        if ( $query{'ds'} && $query{'dt'} ) {
            $self->print_http_header();
            $self->print_page_header();
            $self->handle_diff($query{'ds'}, $query{'dt'});
        } elsif ( $is_revision ) {
            $self->handle_revision($uri_base, $query{'r'});
        } else {
            $self->print_http_header();
            $self->print_page_header();
            $self->handle_file($uri_base, $query{'ds'});
        }
    }
}

sub handler($$) {

    my ($self, $request) = @_;

    delete $ENV{'PATH'};

    $self = $self->new($request) unless ref $self;

    eval {
        $self->handler_internal();
    };

    if ($@) {
        $self->request()->log_error($@);
        $self->print_error($@);
    }
}

=head1 SEE ALSO

L<Apache::CVS::HTML>, L<Rcs>

=head1 AUTHOR

John Barbee <F<barbee@veribox.net>>

=head1 COPYRIGHT

Copyright 2001-2002 John Barbee

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

1;
