package App::ConvertOperaBookmarksToOrg;

our $DATE = '2014-10-12'; # DATE
our $VERSION = '0.02'; # VERSION

use 5.010001;
use strict;
use warnings;

use Sort::ByExample;

my $sorter = Sort::ByExample->sorter([
    "ID",
    "NAME",
    "URL",
    "CREATED",
    "TARGET",
    "MOVE_IS_COPY",
    "SEPARATOR_ALLOWED",
    "EXPANDED",
    "ACTIVE",
    "VISITED",
    "DESCRIPTION",
    "TRASH FOLDER",
    "DELETABLE",
    "PARTNERID",
    "UNIQUEID",
], sub { $a cmp $b });

our %SPEC;

$SPEC{convert_opera_bookmarks_to_org} = {
    v => 1.1,
    summary => 'Convert Opera bookmarks (bookmarks.adr) to Org document',
    description => <<'_',

I want to keep my Opera browser bookmarks file (`~/.opera/bookmarks.adr`) under
git repository, so I can synchronize them between computers. There are a few
annoyances though: 1) When Opera saves bookmarks file, it remove symlinks, so
after I have to re-symlink the file to my git repo; 2) The ID field changes
sporadically, creating unnecessarily large diff and merge conflicts.

This program (and its counterpart `convert-org-to-opera-bookmarks`) is an
alternative to keeping Opera bookmarks file under git. You convert to .org file,
put the .org file under git, and convert back to .adr. The advantage is that the
ID field is removed so the diff is smaller and conflict reduced. Also, you can
more conveniently edit using Emacs/other Org editor.

Another alternative to this program is to use the Opera Link service from Opera
to synchronize your bookmarks (and a few other stuffs) between devices. But note
that Opera has closed some of its services in the past.

_
    args => {
        input => {
            summary => 'Opera addressbook file',
            schema => 'str*',
            cmdline_src => 'stdin_or_files',
            pos => 0,
            req => 1,
        },
    },
};
sub convert_opera_bookmarks_to_org {
    my %args = @_;

    my $cur_level = 1;
    my @sections;
    my @ct;
    for (split /(\r?\n){2,}/, $args{input}) {
        if (/^#(\w+)\r?\n(.+)/s) {
            push @sections, [$1, $2, $_];
        } elsif ($_ eq '-') {
            push @sections, ["endfolder"];
        } else {
            # ignore, including preamble text
        }
    }
    for my $section (@sections) {
        my $sname = $section->[0];
        next if $sname eq 'DELETED';
        if ($sname eq 'endfolder') {
            $cur_level--;
            die "BUG: trying to decrease level to 0" if $cur_level <= 0;
            next;
        }
        my %sfields = $section->[1] =~ /\s*([^=]+)=(.*)/g;
        if ($sname eq 'FOLDER') {
            my $name = $sfields{NAME} // '';
            push @ct, ("*" x $cur_level), " FOLDER: $name\n";
            for (grep {!/^(ID|NAME)$/} $sorter->(keys %sfields)) {
                push @ct, "- $_ :: $sfields{$_}\n";
            }
            $cur_level++;
        } elsif ($sname eq 'URL') {
            my $name = $sfields{NAME} // '';
            push @ct, ("*" x $cur_level), " URL: $name\n";
            for (grep {!/^(ID|NAME)$/} $sorter->(keys %sfields)) {
                push @ct, "- $_ :: $sfields{$_}\n";
            }
        } else {
            warn "Unknown section '$sname', skipped";
            next;
        }
    }
    [200, "OK", join("", @ct)];
}

$SPEC{convert_org_to_opera_bookmarks} = {
    v => 1.1,
    summary => 'Convert back Org to Opera bookmarks (bookmarks.adr)',
    description => <<'_',

This program is the counterpart for `convert-opera-bookmarks-to-org`) to turn
back the Org document generated by that program back to Opera bookmarks .adr
format. See that program for more information.

_
    args => {
        input => {
            summary => 'Org document file',
            schema => 'str*',
            cmdline_src => 'stdin_or_files',
            pos => 0,
            req => 1,
        },
    },
};
sub convert_org_to_opera_bookmarks {
    my %args = @_;

    my $cur_level;
    my @sections;
    my @ct;

    no strict 'refs';
    push @ct, "Opera Hotlist version 2.0 (generated by ".__PACKAGE__.
        " version ".(${__PACKAGE__.'::VERSION'} // "dev").")\n";
    push @ct, "Options: encoding = utf8, version=3\n\n";

    for (split /^(?=\*+ )/m, $args{input}) {
        push @sections, $_;
    }
    my $prev_level;
    my $id = 0;
    for my $section (@sections) {
        $section =~ /^(\*+) (\w+): ?(.*)/ or do {
            warn "Unknown section, skipped: $section";
            next;
        };
        my ($level, $type, $sname) = ($1, $2, $3);
        if ($type ne 'FOLDER' && $type ne 'URL') {
            warn "Unknown section type '$type', skipped";
            next;
        }
        if ($type eq 'FOLDER') {
            $level = length($level);
            if (defined($prev_level) && $level <= $prev_level) {
                for ($level .. $prev_level) {
                    push @ct, "-\n\n";
                }
            }
            $prev_level = $level;
        }
        push @ct, "#$type\n";
        push @ct, "\tID=", ++$id, "\n";
        push @ct, "\tNAME=$sname\n";
        my %sfields = $section =~ /^- (\w+) :: (.*)/mg;
        for ($sorter->(keys %sfields)) {
            push @ct, "\t$_=$sfields{$_}\n";
        }
        push @ct, "\n";
    }
    push @ct, "-\n\n" for 1..$prev_level;
    [200, "OK", join("", @ct)];
}


1;
# ABSTRACT: Convert Opera bookmarks to Org

__END__

=pod

=encoding UTF-8

=head1 NAME

App::ConvertOperaBookmarksToOrg - Convert Opera bookmarks to Org

=head1 VERSION

This document describes version 0.02 of App::ConvertOperaBookmarksToOrg (from Perl distribution App-ConvertOperaBookmarksToOrg), released on 2014-10-12.

=head1 DESCRIPTION

This distribution provides the following utilities:

 convert-opera-bookmarks-to-org
 convert-org-to-opera-bookmarks

Shorter-named scripts are also provided as aliases, respectively:

 adr2org
 org2adr

=head1 FUNCTIONS


=head2 convert_opera_bookmarks_to_org(%args) -> [status, msg, result, meta]

Convert Opera bookmarks (bookmarks.adr) to Org document.

I want to keep my Opera browser bookmarks file (C<~/.opera/bookmarks.adr>) under
git repository, so I can synchronize them between computers. There are a few
annoyances though: 1) When Opera saves bookmarks file, it remove symlinks, so
after I have to re-symlink the file to my git repo; 2) The ID field changes
sporadically, creating unnecessarily large diff and merge conflicts.

This program (and its counterpart C<convert-org-to-opera-bookmarks>) is an
alternative to keeping Opera bookmarks file under git. You convert to .org file,
put the .org file under git, and convert back to .adr. The advantage is that the
ID field is removed so the diff is smaller and conflict reduced. Also, you can
more conveniently edit using Emacs/other Org editor.

Another alternative to this program is to use the Opera Link service from Opera
to synchronize your bookmarks (and a few other stuffs) between devices. But note
that Opera has closed some of its services in the past.

Arguments ('*' denotes required arguments):

=over 4

=item * B<input>* => I<str>

Opera addressbook file.

=back

Return value:

Returns an enveloped result (an array).

First element (status) is an integer containing HTTP status code
(200 means OK, 4xx caller error, 5xx function error). Second element
(msg) is a string containing error message, or 'OK' if status is
200. Third element (result) is optional, the actual result. Fourth
element (meta) is called result metadata and is optional, a hash
that contains extra information.

 (any)


=head2 convert_org_to_opera_bookmarks(%args) -> [status, msg, result, meta]

Convert back Org to Opera bookmarks (bookmarks.adr).

This program is the counterpart for C<convert-opera-bookmarks-to-org>) to turn
back the Org document generated by that program back to Opera bookmarks .adr
format. See that program for more information.

Arguments ('*' denotes required arguments):

=over 4

=item * B<input>* => I<str>

Org document file.

=back

Return value:

Returns an enveloped result (an array).

First element (status) is an integer containing HTTP status code
(200 means OK, 4xx caller error, 5xx function error). Second element
(msg) is a string containing error message, or 'OK' if status is
200. Third element (result) is optional, the actual result. Fourth
element (meta) is called result metadata and is optional, a hash
that contains extra information.

 (any)

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/App-ConvertOperaBookmarksToOrg>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-App-ConvertOperaBookmarksToOrg>.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=App-ConvertOperaBookmarksToOrg>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 AUTHOR

perlancar <perlancar@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by perlancar@cpan.org.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut