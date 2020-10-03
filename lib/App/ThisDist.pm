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
      FROM_DIST_INI: {
            if (-f "dist.ini") {
                my $ct = File::Slurper::read_text("dist.ini");
                while ($ct =~ /^\s*name\s*=\s*(.+)/mg) {
                    $dist = $1;
                    log_debug "this-dist: Guessed dist=$dist from dist.ini\n";
                    last GUESS;
                }
            }
        }

      FROM_GIT_CONFIG: {
            if (-f ".git/config") {
                my $ct = File::Slurper::read_text(".git/config");
                while ($ct =~ /^\s*url\s*=\s*(.+)/mg) {
                    my $url = $1;
                    log_debug "this-dist: Found URL '$url'\n";
                    require CPAN::Dist::FromURL;
                    my $res = CPAN::Dist::FromURL::extract_cpan_dist_from_url($url);
                    if (defined $dist) {
                        log_debug "this-dist: Guessed dist=$dist from .git/config URL '$url'\n";
                        last GUESS;
                    }
                }
            }
        }

      FROM_REPO_NAME: {
            require CPAN::Dist::FromRepoName;
            my $res = CPAN::Dist::FromRepoName::extract_cpan_dist_from_repo_name($dir_basename);
            if (defined $res) {
                $dist = $res;
                log_debug "this-dist: Guessed dist=$dist from repo name '$dir_basename'\n";
                last GUESS;
            }
        }
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
