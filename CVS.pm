# $Id: CVS.pm,v 1.15 2001/03/11 17:16:14 barbee Exp $
package Apache::CVS;

use strict;

$Apache::CVS::VERSION = '0.01';

use Apache::URI();
use Rcs();

$Apache::CVS::content_type = q(text/html);
%Apache::CVS::cvsroots;

$Apache::CVS::rcs_ext;
$Apache::CVS::def_rcs_ext = q(,v);
$Apache::CVS::_workdir;
$Apache::CVS::def_workdir = q(/var/tmp);
$Apache::CVS::bindir;
$Apache::CVS::def_bindir = q(/usr/bin);

$Apache::CVS::seconds_in_minute = 60;
$Apache::CVS::seconds_in_hour = 3600;
$Apache::CVS::seconds_in_day = 86400;

$| = 1;

my @time_units = ('days', 'hours', 'minutes', 'seconds');

sub print_text {

    my $request = shift;

    $request->print('<pre>');

    my $line;
    while ( $line = shift @_ ) {

        $line =~ s/</&lt;/g;
        $line =~ s/>/&gt;/g;
        $request->print($line);
    }

    $request->print('</pre>');
}

sub setup_rcs {

    my ($directory, $file) = @_;

    my $rcs = Rcs->new;
    Rcs->bindir($Apache::CVS::bindir);
    Rcs->arcext($Apache::CVS::rcs_ext);
    $rcs->rcsdir($directory);
    $rcs->file($file);
    $rcs->workdir($Apache::CVS::workdir);

    return $rcs;
}

sub directory_contents {

    my $directory = shift;

    opendir DIR, $directory;
    my @contents = readdir DIR;
    closedir DIR;

    # get rid of . and ..
    @contents = grep { /^[^\.]/ } @contents;

    my @directories =
        grep { -d "$directory/$_" && -X "$directory/$_" && $_ } @contents;

    my @files;

    # get all the files from @content
    # and put each into a file hash setting their name and full path
    # create the rcs object
    foreach (
        grep { -f "$directory/$_" && -r "$directory/$_" && $_ } @contents
    ) {

        s/$Apache::CVS::rcs_ext$//;

        push @files, {
            'name'      => $_,
            'full path' => "$directory/$_",
            'rcs'       => setup_rcs($directory, $_)
        };
    }
    
    return \@directories, \@files;
}

sub print_directory {

    my ($request, $uri_base, $directory) = @_;

    my $uri = $uri_base . $directory;

    $request->print( qq|
        <td><a href=$uri>$directory</a></td>
        <td>&nbsp;</td>
        <td>&nbsp;</td>
        <td>&nbsp;</td>
        <td>&nbsp;</td>
        <td>&nbsp;</td>
    |);
}

sub time_diff {

    my ($later, $earlier) = @_;

    return undef unless $later >= $earlier;

    my %time;

    my $diff = $later - $earlier;

    my $remainder = $diff % $Apache::CVS::seconds_in_day;
    $time{'days'} = ($diff - $remainder) / $Apache::CVS::seconds_in_day;
    $diff = $remainder;

    my $remainder = $diff % $Apache::CVS::seconds_in_hour;
    $time{'hours'} = ($diff - $remainder) / $Apache::CVS::seconds_in_hour;
    $diff = $remainder;

    my $remainder = $diff % $Apache::CVS::seconds_in_minute;
    $time{'minutes'} = ($diff - $remainder) / $Apache::CVS::seconds_in_minute;
    $time{'seconds'} = $remainder;

    return \%time;
}

sub print_file {

    my ($request, $uri_base, $file) = @_;

    my $uri = $uri_base . $file->{'name'};

    my ($author, @revisions, $number_of_revisions, $latest_revision, $last_revision_time, $revision_age);
    eval {
        $author = $file->{'rcs'}->author;
        @revisions = $file->{'rcs'}->revisions;
        $last_revision_time = $file->{'rcs'}->revdate;
    };

    my $html_row;
    unless ( $@ ) {

        $number_of_revisions = scalar @revisions;
        $revision_age = time_diff(time, $last_revision_time);

        my $age = join(', ', map { qq($revision_age->{$_} $_) } @time_units);

        $last_revision_time = localtime($last_revision_time);

        $html_row = qq(
            <td><a href=$uri>$file->{'name'}</a></td>
            <td>$author</td>
            <td>$number_of_revisions</td>
            <td>$revisions[0]</td>
            <td>$last_revision_time</td>
            <td>$age</td>
        );
    } else {
        $html_row = qq(
            <td>$file->{'name'}</td>
            <td>&nbsp;</td>
            <td>&nbsp;</td>
            <td>&nbsp;</td>
            <td>&nbsp;</td>
            <td>&nbsp;</td>
        );
    }

    $request->print($html_row);
}

sub handle_directory {

    my ($request, $uri_base, $directory) = @_;

    my ($directories, $files) = directory_contents($directory);

    $request->print( q|
        <table border=1 cellpadding=2 cellspacing=0>
        <tr>
            <th>filename</th>
            <th>author</th>
            <th>number of revisions</th>
            <th>latest revision</th>
            <th>most recent revision date</th>
            <th>revision age</th>
        </tr>
    |);

    foreach ( @{ $directories } ) {

        $request->print('<tr>');
        print_directory($request, $uri_base, $_);
        $request->print('</tr>');
    }

    foreach ( @{ $files } ) {

        $request->print('<tr>');
        print_file($request, $uri_base, $_);
        $request->print('</tr>');
    }

    $request->print("</table>");
}

sub handle_file {

    my ($request, $uri_base, $directory, $file, $diff_revision) = @_;

    my $rcs = setup_rcs($directory, $file);

    my %comments;
    eval {
        %comments = $rcs->comments;
    };

    if ( $@ ) {

        $request->print("This doesn't look like a valid rcs file.");
        $request->log_error("Invalid rcs file: $directory/$file.");
        return;
    }

    $request->print($comments{'0'});

    $request->print( q|
        <table border=1 cellpadding=0 cellspacing=0>
        <tr>
            <th>revision number</th>
            <th>author</th>
            <th>state</th>
            <th>symbol</th>
            <th>date</th>
            <th>age</th>
            <th>comment</th>
            <th>action</th>
    |);

    my $rev_num;
    foreach $rev_num ( $rcs->revisions ) {
        my ($author, $state, $symbol, $date, $comment);
        eval {

            $author = $rcs->author($rev_num);
            $state = $rcs->state($rev_num);
            $symbol = $rcs->symbol($rev_num);
            $date = $rcs->revdate($rev_num);
        };

        $request->log_error("Unexpected error: $@") if $@;

        my $revision_age = time_diff(time, $date);

        my $age = join(', ', map { qq($revision_age->{$_} $_) } @time_units);

        $date = localtime $date;

        my $revision_uri = $uri_base . $file . qq(?r=$rev_num);
        my $html_row = qq(
            <tr>
                <td><a href=$revision_uri>$rev_num</td>
                <td>$author</td>
                <td>$state</td>
                <td>$symbol</td>
                <td>$date</td>
                <td>$age</td>
                <td>$comments{$rev_num}</td>
                <td>
        );

        if ( $rev_num eq $diff_revision ) {

            $html_row .= q(selected for diff);
        } else {

            if ( $diff_revision ) {
                $html_row .= qq(<a href=) . $uri_base . $file . qq(?ds=$diff_revision&dt=$rev_num>select for diff with $diff_revision</a>);
            } else {
                $html_row .= qq(<a href=) . $uri_base . $file . qq(?ds=$rev_num>select for diff</a>);
            }
        }
                
        $html_row .= qq(
                </td>
            </tr>
        );

        $request->print($html_row);
    }

    $request->print('</table>');
}

sub handle_revision {

    my ($request, $uri_base, $rpath, $current_root, $directory, $file, $revision) = @_;

    my $rcs = setup_rcs($directory, $file);

    eval {
        $rcs->co("-r$revision");
    };

    if ( $@ ) {

        $request->print("Invalid rcs file.");
        $request->log_error("Invalid rcs file.  $@");
        return;
    }

    my $co_file = $rcs->workdir . q(/) .  $rcs->file;

    open FILE, "$co_file";

    my $content_type;
    if ( -B $co_file ) {

        my $subrequest = $request->lookup_file($co_file);
        $content_type = $subrequest->content_type;
        header($request, $co_file, $rpath, $current_root, $content_type);

        my $fh = *FILE;
        $request->send_fd($fh);
    } else {

        header($request, "$directory/$file", $rpath, $current_root);
        print_text($request, <FILE>);
    }
    close FILE;

    eval {
        unlink $co_file;
    };

    $request->log_error("Unable to delete file: $@") if $@;
}

sub parent_link {

    my ($request, $filename, $rpath, $current_root, $is_revision) = @_;

    # strip out unnecessary stuff
    $filename =~ s/$Apache::CVS::cvsroots{$current_root}//;
#    $filename =~ s#[^/]*/?$## unless $is_revision;

    # top / root / file
    my $path = qq($rpath/$current_root$filename);

    my $link = qq(<a href=$rpath>top</a>);
    $link .= qq(:: <a href=$rpath/$current_root>$current_root</a>);

    my $parents;
    foreach ( split m#/#, $filename ) {

        next unless $_;
        $link .= qq(:: <a href="$rpath/$current_root$parents/$_">$_</a>);
        $parents .= qq(/$_) if $_;
    }

    $request->print($link);
}

# reads in config file variables
sub read_config {

    my $request = shift;

    %Apache::CVS::cvsroots = split /\s*(?:=>|,)\s*/, $request->dir_config('CVSRoots');

    $Apache::CVS::rcs_ext = $request->dir_config('RCSExtension') || $Apache::CVS::def_rcs_ext;

    $Apache::CVS::workdir = $request->dir_config('WorkingDirectory') || $Apache::CVS::def_workdir;
    $Apache::CVS::bindir = $request->dir_config('BinaryDirectory') || $Apache::CVS::def_bindir;
}

sub handle_root {

    my ($request, $rpath) = @_;

    # display all cvs roots
    $request->print('available cvs roots<p>');

    foreach ( keys %Apache::CVS::cvsroots ) {

        $request->print(qq|<a href="$rpath/$_">$_</a><br>|);
    }

    # bail
}

sub handle_diff {

    my ($request, $directory, $file, $diff_source, $diff_target) = @_;

    my $rcs = setup_rcs($directory, $file);

    # make sure revision numbers are numbers
    $diff_source =~ m#^(\d+(\.\d+)+)$#;
    $diff_source = $1;
    $diff_target =~ m#^(\d+(\.\d+)+)$#;
    $diff_target = $1;

    my @diff;
    eval {
        @diff = $rcs->rcsdiff("-r$diff_source", "-r$diff_target");
    };

    unless ( $@ ) {

        print_text($request, @diff);
    } else {

        $request->print(qq|<p>Invalid rcs file.|);
        $request->log_error(qq|<p>Invalid rcs file.  $@|);
    }
}

sub header {
    
    my ($request, $filename, $rpath, $current_root, $content_type) = @_;

    my $type = $content_type || $Apache::CVS::content_type;

    $request->content_type($type);
    $request->send_http_header;

    # print a parent directory link
    parent_link($request, $filename, $rpath, $current_root) unless $content_type;
}

sub handler {

    my $request = shift;

    delete $ENV{'PATH'};

    read_config($request);

    my $path_info = $request->path_info;
    my $uri = $request->parsed_uri;
    my $rpath = $uri->rpath;

    my $is_real_root = 1 unless ( $path_info and $path_info ne '/' );

    # strip off the cvs root id from the front
    $path_info =~ s#/([^/]+)/?##;
    my $current_root = $1;

    # determine current filename
    my $filename;
    my $is_cvsroot;
    unless ( $path_info and $path_info ne '/' ) {

        $filename = $Apache::CVS::cvsroots{$current_root};
        $is_cvsroot = 1;
    } else {

        $filename = $Apache::CVS::cvsroots{$current_root} . q(/) . $path_info;
    }

    my %query = $request->args;
    my $is_revision = exists $query{'r'};

    if ( $is_real_root ) {

        header($request, $filename, $rpath, $current_root);
        handle_root($request, $rpath);
        return;
    }

    my $uri_base = $rpath . q(/) . $current_root . q(/) . $path_info;

    if ( -d $filename ) {

        header($request, $filename, $rpath, $current_root);
        $uri_base .= q(/) unless $uri_base =~ /\/$/;
        handle_directory($request, $uri_base, $filename);
    } else {

        $uri_base =~ s/[^\/]*$//;

        $filename =~ /(\/([^\/]+\/)*)([^\/]*)/;

        my $file_base = $1;
        my $file_tail = $3;
        $file_base =~ s/\/$//;

        my %query = $request->args;
        if ( $query{'ds'} && $query{'dt'} ) {

            header($request, $filename, $rpath, $current_root);
            handle_diff($request, $file_base, $file_tail, $query{'ds'}, $query{'dt'});
        } elsif ( $is_revision ) {

            handle_revision($request, $uri_base, $rpath, $current_root, $file_base, $file_tail, $query{'r'});
        } else {

            header($request, $filename, $rpath, $current_root);
            handle_file($request, $uri_base, $file_base, $file_tail, $query{'ds'});
        }
    }
}

1;
__END__

=head1 NAME

Apache::CVS - mod_perl content handler for CVS

=head1 SYNOPSIS

    <Location /cvs>
        SetHandler perl-script
        PerlHandler Apache::CVS
        PerlSetVar CVSRoots cvs1=>/usr/local/CVS
    </Location>

=head1 DESCRIPTION

Provides a web interface to CVS through a mod_perl content handler.

=head1 DEPENDENCIES

Rcs 0.09

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

=head1 AUTHOR

John Barbee, jbarbee@pomona.edu

=head1 SEE ALSO

perl(1), Rcs(3).

=cut
