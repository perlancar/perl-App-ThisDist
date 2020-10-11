package App::ThisDist;

# AUTHORITY
# DATE
# DIST
# VERSION

use strict;
use warnings;
use Log::ger;

use File::chdir;

use Exporter qw(import);
our @EXPORT_OK = qw(this_dist);

sub this_dist {
    require File::Slurper;

    my ($dir) = @_;

    if (!$dir) {
        require Cwd;
        $dir = Cwd::getcwd();
    }
    (my $dir_basename = $dir) =~ s!.+[/\\]!!;

    local $CWD = $dir;

    my $dist;
  GUESS: {
      FROM_DISTMETA_2: {
            for my $file ("MYMETA.json", "META.json") {
                next unless -f $file;
                log_debug "Found distribution metadata $file in current directory";
                require JSON::PP;
                my $content = File::Slurper::read_text($file);
                my $meta = JSON::PP::decode_json($content);
                if ($meta && ref $meta eq 'HASH' && defined $meta->{name}) {
                    $dist = $meta->{name};
                    log_debug "Got dist=$dist from distribution metadata $file";
                    last GUESS;
                } else {
                    last;
                }
            }
        }

      FROM_DISTMETA_1_1: {
            for my $file ("MYMETA.yml", "META.yml") {
                next unless -f $file;
                log_debug "Found distribution metadata $file in current directory";
                require YAML::XS;
                my $meta = YAML::XS::LoadFile($file);
                if ($meta && ref $meta eq 'HASH' && defined $meta->{name}) {
                    $dist = $meta->{name};
                    log_debug "Got dist=$dist from distribution metadata $file";
                    last GUESS;
                } else {
                    last;
                }
            }
        }

      FROM_DIST_INI: {
            last unless -f "dist.ini";
            log_debug "Found dist.ini in current directory";
            my $content = File::Slurper::read_text("dist.ini");
            while ($content =~ /^\s*name\s*=\s*(.+)/mg) {
                $dist = $1;
                log_debug "Got dist=$dist from dist.ini";
                last GUESS;
            }
        }

      FROM_MAKEFILE_PL: {
            last unless -f "Makefile.PL";
            log_debug "Found Makefile.PL in current directory";
            my $content = File::Slurper::read_text("Makefile.PL");
            unless ($content =~ /use ExtUtils::MakeMaker/) {
                log_debug "Makefile.PL doesn't seem to use ExtUtils::MakeMaker, skipped";
                last;
            }
            unless ($content =~ /["']DISTNAME["']\s*=>\s*["'](.+?)["']/) {
                log_debug "Couldn't extract value of DISTNAME from Makefile.PL, skipped";
                last;
            }
            $dist = $1;
            log_debug "Got dist=$dist from Makefile.PL";
            last GUESS;
        }

      FROM_MAKEFILE: {
            last unless -f "Makefile";
            log_debug "Found Makefile in current directory";
            my $content = File::Slurper::read_text("Makefile");
            unless ($content =~ /by MakeMaker/) {
                log_debug "Makefile doesn't seem to be generated from MakeMaker.PL, skipped";
                last;
            }
            unless ($content =~ /^DISTNAME\s*=\s*(.+)/m) {
                log_debug "Couldn't extract value of DISTNAME from Makefile, skipped";
                last;
            }
            $dist = $1;
            log_debug "Got dist=$dist from Makefile.PL";
            last GUESS;
        }

      FROM_BUILD_PL: {
            last unless -f "Build.PL";
            log_debug "Found Build.PL in current directory";
            my $content = File::Slurper::read_text("Build.PL");
            unless ($content =~ /use Module::Build/) {
                log_debug "Build.PL doesn't seem to use Module::Build, skipped";
                last;
            }
            unless ($content =~ /module_name\s*=>\s*["'](.+?)["']/s) {
                log_debug "Couldn't extract value of module_name from Build.PL, skipped";
                last;
            }
            $dist = $1; $dist =~ s/::/-/g;
            log_debug "Got dist=$dist from Build.PL";
            last GUESS;
        }

        # Build script does not contain dist name

      FROM_GIT_CONFIG: {
            last unless -f ".git/config";
            log_debug "Found .git/config";
            my $content = File::Slurper::read_text(".git/config");
            while ($content =~ /^\s*url\s*=\s*(.+)/mg) {
                my $url = $1;
                log_debug "Found URL '$url' in git config";
                require CPAN::Dist::FromURL;
                my $res = CPAN::Dist::FromURL::extract_cpan_dist_from_url($url);
                if (defined $dist) {
                    log_debug "Guessed dist=$dist from .git/config URL '$url'";
                    last GUESS;
                }
            }
        }

      FROM_REPO_NAME: {
            log_debug "Using CPAN::Dist::FromRepoName to guess from dir name ...";
            require CPAN::Dist::FromRepoName;
            my $res = CPAN::Dist::FromRepoName::extract_cpan_dist_from_repo_name($dir_basename);
            if (defined $res) {
                $dist = $res;
                log_debug "Guessed dist=$dist from repo name '$dir_basename'";
                last GUESS;
            }
        }

        log_debug "Can't guess this distribution, giving up";
    }
    $dist;
}

1;
# ABSTRACT: Print Perl {distribution,module,author,...} associated with current directory

=head1 DESCRIPTION

See included scripts:

# INSERT_EXECS_LIST


=head1 FUNCTIONS

=head2 this_dist


=head1 SEE ALSO

L<App::DistUtils>
