#!/usr/bin/env perl
use strict;
use warnings;
use v5.22;
use Scalar::Util qw/looks_like_number/;
use List::Util qw/any/;

local $::INDENT = 2;

my $confdir = $ENV{PROSODY_CONFIGDIR} // '/etc/prosody';

my @configs = (
    "$confdir/prosody.cfg.lua",
    my $moduleconf = "$confdir/conf.d/modules.cfg.lua",
    "$confdir/conf.d/logging.cfg.lua",
    "$confdir/conf.d/bootstrap.cfg.lua",
);

sub comment_out (_) {
    return if /^\s*--/;

    s/^(\s*)/$1--/;
}

sub uncomment (_) {
    s/^(\s*)--/$1/;
}

sub spaces_to_quoted {
    my $t = "\t" x ($::INDENT // 0);

    join "\n$t", map { qq/"$_";/ } map { split ' ' } grep defined, @_;
}

my %STORAGE = map {
        /^PROSODY_STORAGE_(.+)/ ? (lc $1 => $ENV{$_}) : ()
    }
    keys %ENV
;

$ENV{PROSODY_STORAGE_KVP} =
    join "\n",
    map {
        qq{$_ = "$STORAGE{$_}";}
    }
    keys %STORAGE
;

if (
    any {; defined $_ && $_ eq 'sql' } 
    values %STORAGE, $ENV{PROSODY_DEFAULT_STORAGE}
) {
    my $sqlconf = {
        driver      => $ENV{PROSODY_DB_DRIVER} // 'PostgreSQL',
        database    => $ENV{PROSODY_DB_NAME} // 'prosody',
        host        => $ENV{PROSODY_DB_HOST} // 'postgresql',
        port        => $ENV{PROSODY_DB_PORT} // 5432,
        username    => $ENV{PROSODY_DB_USERNAME} // 'prosody',
        password    => $ENV{PROSODY_DB_PASSWORD} // die "Must specify database password",
    };

    my $maybe_quote = sub {
        return qq/"$_[0]"/ unless looks_like_number $_[0];
        return $_[0];
    };

    my $sqlstr = "{ " . (join ", ", map { join ' = ', $_, $maybe_quote->($sqlconf->{$_}) } keys %$sqlconf) . " }";

    $ENV{PROSODY_SQL_CONNECTION} = $sqlstr;
}

# Set up the bootstrap vars before we fiddle with the configs
if ($ENV{PROSODY_BOOTSTRAP}) {
    my @admin_xids = split ' ', $ENV{PROSODY_BOOTSTRAP_ADMIN_XIDS};
    $ENV{PROSODY_BOOTSTRAP_ADMIN_XIDS_QUOTED} = join ',', map { qq/"$_"/ } @admin_xids;

}

$ENV{$_} = spaces_to_quoted($ENV{$_}) for qw/
    PROSODY_S2S_SECURE_DOMAINS
    PROSODY_S2S_INSECURE_DOMAINS
/;

# Go through all of the config files and interpolate environment variables into
# them. ${ENV_VAR_NAME:-default}
for my $conf (@configs) {
    open my $inconffh, "<", $conf;

    my @outlines;
    for (readline $inconffh) {
        push @outlines,
        s#\$\{
            ([^}]+?)
            (?::-([^}]*?))?
        \}
        #$ENV{$1} // $2 // ''#xger
        ;
    }

    close $inconffh;
    open my $outconffh, ">", $conf;
    print $outconffh $_ for @outlines;
}

exec @ARGV;
