package App::ThisDist;

use strict;
use warnings;
use Log::ger;

use Exporter qw(import);
use File::chdir;

# AUTHORITY
# DATE
# DIST
# VERSION

our @EXPORT_OK = qw(this_dist this_mod);

sub this_dist {
    require File::Slurper;

    my ($dir, $extract_version, $detail) = @_;

    if (defined $dir) {
        log_debug "chdir to $dir ...";
    }

    local $CWD = $dir if defined $dir;

    unless (defined $dir) {
        require Cwd;
        $dir = Cwd::getcwd();
    }

    (my $dir_basename = $dir) =~ s!.+[/\\]!!;

    my ($distname, $distver, $detailinfo);
    $detailinfo = {};

  GUESS: {
      FROM_DISTMETA_2: {
            for my $file ("MYMETA.json", "META.json") {
                next unless -f $file;
                log_debug "Found distribution metadata $file";
                require JSON::PP;
                my $content = File::Slurper::read_text($file);
                my $meta = JSON::PP::decode_json($content);
                if ($meta && ref $meta eq 'HASH' && defined $meta->{name}) {
                    $distname = $meta->{name};
                    log_debug "Got distname=$distname from distribution metadata $file";
                    $detailinfo->{source} = 'dist meta v2';
                    $detailinfo->{dist_meta_file} = $file;
                    if (defined $meta->{version}) {
                        $distver = $meta->{version};
                        log_debug "Got distver=$distver from distribution metadata $file";
                    }
                    last GUESS;
                } else {
                    last;
                }
            }
        }

      FROM_DISTMETA_1_1: {
            for my $file ("MYMETA.yml", "META.yml") {
                next unless -f $file;
                log_debug "Found distribution metadata $file";
                require YAML::XS;
                my $meta = YAML::XS::LoadFile($file);
                if ($meta && ref $meta eq 'HASH' && defined $meta->{name}) {
                    $distname = $meta->{name};
                    log_debug "Got distname=$distname from distribution metadata $file";
                    $detailinfo->{source} = 'dist meta v1.1';
                    $detailinfo->{dist_meta_file} = $file;
                    if (defined $meta->{version}) {
                        $distver = $meta->{version};
                        log_debug "Got distver=$distver from distribution metadata $file";
                    }
                    last GUESS;
                } else {
                    last;
                }
            }
        }

      FROM_DIST_INI: {
            last unless -f "dist.ini";
            log_debug "Found dist.ini";
            my $content = File::Slurper::read_text("dist.ini");
            while ($content =~ /^\s*name\s*=\s*(.+)/mg) {
                $distname = $1;
                log_debug "Got distname=$distname from dist.ini";
                $detailinfo->{source} = "dist.ini";
                if ($content =~ /^version\s*=\s*(.+)/m) {
                    $distver = $1;
                    log_debug "Got distver=$distver from dist.ini";
                }
                last GUESS;
            }
        }

      FROM_MAKEFILE_PL: {
            last unless -f "Makefile.PL";
            log_debug "Found Makefile.PL";
            my $content = File::Slurper::read_text("Makefile.PL");
            unless ($content =~ /use ExtUtils::MakeMaker/) {
                log_debug "Makefile.PL doesn't seem to use ExtUtils::MakeMaker, skipped";
                last;
            }
            unless ($content =~ /["']DISTNAME["']\s*=>\s*["'](.+?)["']/) {
                log_debug "Couldn't extract value of DISTNAME from Makefile.PL, skipped";
                last;
            }
            $distname = $1;
            log_debug "Got distname=$distname from Makefile.PL";
            $detailinfo->{source} = "Makefile.PL";
            if ($content =~ /["']VERSION["']\s*=>\s*["'](.+?)["']/) {
                $distver = $1;
                log_debug "Got distver=$distver from Makefile.PL";
            }
            last GUESS;
        }

      FROM_MAKEFILE: {
            last unless -f "Makefile";
            log_debug "Found Makefile";
            my $content = File::Slurper::read_text("Makefile");
            unless ($content =~ /by MakeMaker/) {
                log_debug "Makefile doesn't seem to be generated from MakeMaker.PL, skipped";
                last;
            }
            unless ($content =~ /^DISTNAME\s*=\s*(.+)/m) {
                log_debug "Couldn't extract value of DISTNAME from Makefile, skipped";
                last;
            }
            $distname = $1;
            log_debug "Got distname=$distname from Makefile";
            $detailinfo->{source} = "Makefile";
            if ($content =~ /^VERSION\s*=\s*(.+)/m) {
                $distver = $1;
                log_debug "Got distver=$distver from Makefile";
            }
            last GUESS;
        }

      FROM_BUILD_PL: {
            last unless -f "Build.PL";
            log_debug "Found Build.PL";
            my $content = File::Slurper::read_text("Build.PL");
            unless ($content =~ /use Module::Build/) {
                log_debug "Build.PL doesn't seem to use Module::Build, skipped";
                last;
            }
            unless ($content =~ /module_name\s*=>\s*["'](.+?)["']/s) {
                log_debug "Couldn't extract value of module_name from Build.PL, skipped";
                last;
            }
            $distname = $1; $distname =~ s/::/-/g;
            log_debug "Got distname=$distname from Build.PL";
            $detailinfo->{source} = "Build.PL";
            # XXX extract version?
            last GUESS;
        }

        # note: Build script does not contain dist name

      FROM_GIT_CONFIG: {
            last; # currently disabled
            last unless -f ".git/config";
            log_debug "Found .git/config";
            my $content = File::Slurper::read_text(".git/config");
            while ($content =~ /^\s*url\s*=\s*(.+)/mg) {
                my $url = $1;
                log_debug "Found URL '$url' in git config";
                require CPAN::Dist::FromURL;
                my $res = CPAN::Dist::FromURL::extract_cpan_dist_from_url($url);
                if (defined $distname) {
                    log_debug "Guessed distname=$distname from .git/config URL '$url'";
                    $detailinfo->{source} = "git config";
                    # XXX extract version?
                    last GUESS;
                }
            }
        }

      __DISABLED__FROM_REPO_NAME: {
            last; # currently disabled
            log_debug "Using CPAN::Dist::FromRepoName to guess from dir name ...";
            require CPAN::Dist::FromRepoName;
            my $res = CPAN::Dist::FromRepoName::extract_cpan_dist_from_repo_name($dir_basename);
            if (defined $res) {
                $distname = $res;
                log_debug "Guessed distname=$distname from repo name '$dir_basename'";
                $detailinfo->{source} = "repo name";
                # XXX extract version?
                last GUESS;
            }
        }

      FROM_ARCHIVE: {
            require Filename::Type::Perl::Release;
            # if there is a single archive in the directory which looks like a
            # perl release, use that.
            my @files = grep { -f } glob "*";
            my ($distfile, $dist, $ver);
            for my $file (@files) {
                my $res = Filename::Type::Perl::Release::check_perl_release_filename(filename=>$file);
                next unless $res;
                last FROM_ARCHIVE if defined $dist;
                $dist = $res->{distribution};
                $ver  = $res->{version};
                $distfile = $file;
            }
            last unless defined $dist;
            $distname = $dist;
            $distver  = $ver;
            log_debug "Guessed distname=$distname from a single perl archive file in the directory ($distfile)";
            $detailinfo->{source} = "archive";
            $detailinfo->{archive_file} = $distfile;
            last GUESS;
        }

        log_debug "Can't guess distribution, giving up";
    } # GUESS

    if ($detail) {
        $detailinfo->{dist} = $distname;
        $detailinfo->{dist_version} = $distver;
        $detailinfo;
    } else {
        return unless defined $distname;
        $extract_version ? "$distname ".(defined $distver ? $distver : "?") : $distname;
    }
}

sub this_mod {
    my $res = this_dist(@_);
    return $res unless defined $res;
    if (ref $res) {
        return $res unless $res->{dist} && $res->{dist} =~ /\S/;
        ($res->{module} = $res->{dist}) =~ s/-/::/g;
    } else {
        return $res unless $res =~ /\S/;
        $res =~ s/-/::/g;
    }
    $res;
}

1;
# ABSTRACT: Print Perl {distribution,module,author,...} associated with current directory

=head1 DESCRIPTION

See included scripts:

# INSERT_EXECS_LIST


=head1 FUNCTIONS

=head2 this_dist

Usage:

 my $dist = this_dist([ $dir ] [ , $extract_version? ] [ , $detail? ]); => e.g. "App-Foo" or "App-Foo 1.23" or {dist=>"App-Foo", dist_version=>1.23, ...}

If C<$dir> is not specified, will default to current directory. If
C<$extract_version> is set to true, will also try to extract distribution
version and will return "?" for version when version cannot be found. If
C<$detail> is set to true, then instead of just a string, will return a hash of
more detailed information.

Debugging statement are logged using L<Log::ger>.

=head2 this_mod

A thin wrapper for L</this_dist>. It just converts "-" in the result to "::", so
"Foo-Bar" becomes "Foo::Bar".

Debugging statement are logged using L<Log::ger>.


=head1 SEE ALSO

L<App::DistUtils>

C<my_dist()> from L<Dist::Util::Current> tries to guess distribution name
associated with source code file. It uses us when guessing via C<$DIST> or
F<.packlist> files fail.
