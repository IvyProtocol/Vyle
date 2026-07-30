#!/usr/bin/env bash

help_function() {
    cat <<EOF
$(basename "$0") [Flags] [Directory/Files]

Available Flags:
    --allow-pre         | PRE hooks only run if \$HYDE_TMQ_ALLOW_PRE is set to 1/true/yes
    --allow-warn        | Strict-Warnings: Exit if variables are malformed or don't exist in the ENV.
    --allow-debug       | Debug spit: set \$HYDE_TMQ_DEBUG=1 to enable verbose prints
    --allow-dry-run     | Dry-run: do not write files or execute RUN; just print actions

    --env          P    | Enables sourcing of path file that contains exported variables.
                          Requires additional delimiter '--' or else it will fallback.

    --proc         N    | Amount of CPU cores to be utilized for template generation. Default: 1
    --lock-timeout N    | Seconds to wait for/make stale locks (sets \$HYDE_TMQ_LOCK_TIMEOUT). Default: 10

    --help              | Show this help
    --file              | Target path: path/to/template | path/to/dir..
    --dont-run          | Disable RUN execution (sets \$HYDE_TMQ_ALLOW_RUN=0)

    --pre-scan          | Pre-scan template file to avoid per-worker duplicate PRE invocation.
                          Runs unique PRE hooks once in parent and exports results to children

    --no-atomic         | Disable atomic writing (fsync/temp files) for faster direct writes while keeping locks.

    --ignore-unbound    | Treat all <...> as literal markup, not placeholders: unbound plain
                          <VAR> is left as-is with no warning. Useful for large hand-authored
                          SVGs whose own tags (<g>, <defs>, ...) collide with the placeholder syntax.
                          Overridden by --allow-warn.

    --ignore-templates  | Space-separated list of filenames to skip when scanning directories.
    --disable-fallback  | Disable :- bash-style fallback-syntax in templates.

EOF
}
while [[ $# -gt 0 ]]; do
    case "$1" in
    --allow-pre) export HYDE_TMQ_ALLOW_PRE=1 ;;
    --allow-warn) export HYDE_TMQ_STRICT=1 ;;
    --allow-debug) export HYDE_TMQ_DEBUG=1 ;;
    --allow-dry-run) export HYDE_TMQ_DRY_RUN=1 ;;

    --env)
        shift
        set -a
        while [[ "$#" -gt 0 && "$1" != "--" ]]; do
            if [[ -z "${1:-}" || ! -e "${1}" ]]; then
                printf '@[diagnostic:error(true)]: --env requires a valid path! \n' >&2
                exit 2
            fi
            source "$1"
            shift
        done
        set +a
        [[ "${1:-}" == "--" ]] && shift
        continue
        ;;
    --proc)
        shift
        if [[ -z "${1:-}" || ! "${1}" =~ ^[0-9]+$ ]]; then
            printf '@[diagnostic:error(true)]: --nproc requires a positive integer argument \n' >&2
            exit 2
        fi
        export HYDE_TMQ_PROC=$1
        ;;
    --lock-timeout)
        shift
        if [[ -z "${1:-}" || ! "$1" =~ ^[0-9]+$ ]]; then
            printf '@[diagnostic:error(true)]: --lock-timeout requires a positive integer argument\n' >&2
            exit 2
        fi
        export HYDE_TMQ_LOCK_TIMEOUT="$1"
        ;;

    --help)
        help_function
        exit 0
        ;;
    --file)
        shift
        while [[ $# -gt 0 && "$1" != "--" && "$1" != -* ]]; do
            HYDE_TMQ_TEMPLATE_FILE="${HYDE_TMQ_TEMPLATE_FILE:+$HYDE_TMQ_TEMPLATE_FILE:}$1"
            shift
        done
        export HYDE_TMQ_TEMPLATE_FILE
        continue
        ;;
    --pre-scan) export HYDE_TMQ_PRE_SCAN=1 ;;
    --dont-run) export HYDE_TMQ_ALLOW_RUN=0 ;;
    --no-atomic) export HYDE_TMQ_NO_ATOMIC=1 ;;
    --ignore-templates)
        shift
        if [[ -z "${1:-}" ]]; then
            printf '@[diagnostic:error(true)]: --ignore-templates argument requires file-paths'
            exit 2
        fi
        export HYDE_TMQ_IGNORE_TEMPLATES="$1"
        ;;
    --ignore-unbound) export HYDE_TMQ_IGNORE_UNBOUND=1 ;;
    --disable-fallback) export HYDE_TMQ_DISABLE_FALLBACK=1 ;;
    *) break ;;
    esac
    shift
done

set -eo pipefail
scrDir="$(dirname "$(realpath "$0")")"

# Initialize hyde-shell if available
# if [[ -z "${HYDE_SHELL_INIT:-}" ]]; then
#if command -v hyde-shell >/dev/null 2>&1; then
# eval "$(hyde-shell init)"
# else
# printf '@[diagnostic:warn(true)]: hyde-shell not found; continuing without it\n' >&2
# fi
# fi

export LIB_DIR="$scrDir"
# Only export XDG* if already set in the environment (don't override with empty)
[[ -n "${XDG_CACHE_HOME:-}" ]] && export XDG_CACHE_HOME
[[ -n "${XDG_CONFIG_HOME:-}" ]] && export XDG_CONFIG_HOME

export SCRIPT_NAME="$0"
export HYDE_TMQ_LOCK_DIR="${HYDE_RUNTIME_DIR:-${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hyde}/${0##*/}"
export HYDE_TMQ_LOCK_TIMEOUT="${HYDE_TMQ_LOCK_TIMEOUT:-10}"

perl - "$@" <<'EOF'
use strict;
use warnings;
use File::Find     qw(find);
use File::Path     qw(make_path);
use File::Basename qw(basename dirname);
use File::Spec;
use Time::HiRes qw(gettimeofday tv_interval);
use Fcntl       qw(:DEFAULT);
use IO::Handle;

my ( $LIB_DIR, $NPROC, $SCRIPT_NAME, $HOME_DIR, $PLACEHOLDER_RE );
my ( %REPLACE, %RGBA_BASE, %SKIP_SET, %made_dirs, @template_source,
    @INPUT_PATH, @files, %pids );
my ($raw,        $nl,         $header,      $body,
    $target,     $pre_script, $post_script, $post_is_run,
    $target_dir, $existing,   $found,       $n,
    $workers,    $chunk,      $res
);

$LIB_DIR     = $ENV{LIB_DIR} // '';
$NPROC       = $ENV{HYDE_TMQ_PROC} || 1;
$SCRIPT_NAME = $ENV{SCRIPT_NAME} // '';
$SCRIPT_NAME = basename($SCRIPT_NAME) if length $SCRIPT_NAME;

@INPUT_PATH = split /:/, ( $ENV{HYDE_TMQ_TEMPLATE_FILE} // '' );
$HOME_DIR   = $ENV{HOME} // '';

# Control flags:

# PRE hooks only run if HYDE_TMQ_ALLOW_PRE is set to 1/true/yes
my $ALLOW_PRE = $ENV{HYDE_TMQ_ALLOW_PRE}
    && $ENV{HYDE_TMQ_ALLOW_PRE} =~ /^(1|true|yes)$/i ? 1 : 0;

# RUN is allowed unconditionally (per request). If you want to gate it later, set HYDE_TMQ_ALLOW_RUN similarly.
my $ALLOW_RUN = defined $ENV{HYDE_TMQ_ALLOW_RUN}
    && $ENV{HYDE_TMQ_ALLOW_RUN} =~ /^(0|false|no)$/i ? 0 : 1;

# Strict-Warnings: Exit if variables are malformed or doesn't exist in the ENV.
my $ALLOW_STRICT_WARNINGS = $ENV{HYDE_TMQ_STRICT}
    && $ENV{HYDE_TMQ_STRICT} =~ /^(1|true|yes)$/i ? 1 : 0;

# Dry-run: do not write files or execute RUN; just print actions
my $DRY_RUN = $ENV{HYDE_TMQ_DRY_RUN}
    && $ENV{HYDE_TMQ_DRY_RUN} =~ /^(1|true|yes)$/i ? 1 : 0;

# Debug spit: set HYDE_TMQ_DEBUG=1 to enable verbose prints
my $SPIT_DEBUG = $ENV{HYDE_TMQ_DEBUG}
    && $ENV{HYDE_TMQ_DEBUG} =~ /^(1|true|yes)$/i ? 1 : 0;

# Disable atomic file generation for faster direct writes
my $NO_ATOMIC = $ENV{HYDE_TMQ_NO_ATOMIC}
    && $ENV{HYDE_TMQ_NO_ATOMIC} =~ /^(1|true|yes)$/i ? 1 : 0;

# Pre-scan template file to avoid per-worker duplicate PRE invocation.
my $ALLOW_PRE_SCAN = $ENV{HYDE_TMQ_PRE_SCAN}
    && $ENV{HYDE_TMQ_PRE_SCAN} =~ /^(1|true|yes)$/i ? 1 : 0;

# Ignore-unbound: treat <...> as literal markup rather than placeholders.
# Unbound plain <VAR> is left as-is with no warning; any :- fallback syntax
# found in a template is a hard error (fallback parsing is disabled outright).
# --allow-warn (strict) takes precedence if both are set.
my $IGNORE_UNBOUND
    = $ENV{HYDE_TMQ_IGNORE_UNBOUND}
    && $ENV{HYDE_TMQ_IGNORE_UNBOUND} =~ /^(1|true|yes)$/i
    && !$ALLOW_STRICT_WARNINGS ? 1 : 0;

# Disable bash-style fallback
my $DISABLE_FALLBACK =
    $ENV{HYDE_TMQ_DISABLE_FALLBACK}
    && $ENV{HYDE_TMQ_DISABLE_FALLBACK} =~ /^(1|true|yes)$/i ? 1 : 0;



for my $path (@INPUT_PATH) {
    if ( -f $path ) {
        push @files, $path;
        $found = 1;
    }
    elsif ( -d $path ) {
        push @template_source, $path;
    }
}

unless ( @files || @template_source ) {
    print
        "@[arg:no_arg]: No valid file or directory paths given. $SCRIPT_NAME --help for more information\n";
    exit(1);
}

if ( $> == 0 ) {
    printf( "@[root]: %s must not be run as root.\n", $SCRIPT_NAME );
    exit 1;
}

my $locks_base = $ENV{HYDE_TMQ_LOCK_DIR}
    || (
    $ENV{XDG_CACHE_HOME}
    ? "$ENV{XDG_CACHE_HOME}/.tmq/locks"
    : "$ENV{HOME}/.cache/tmq/locks"
    );

my $LOCK_TIMEOUT
    = $ENV{HYDE_TMQ_LOCK_TIMEOUT}
    ? int( $ENV{HYDE_TMQ_LOCK_TIMEOUT} )
    : 10;

# sanity: ensure locks base exists or can be created
unless ( -d $locks_base ) {
    eval { make_path($locks_base); 1 }
        or die
        "@[diagnostic:error:populate:write(false)]: Cannot create locks dir $locks_base: $!";
}

# more permissive placeholder regex; captures color functions or simple names
# Allows a nested placeholder inside the fallback (e.g., <VAR:-<DEFAULT>>)
$PLACEHOLDER_RE
    = qr{<\s*(?:(\w+_rgba)\(\s*([^)]+)\s*\)|([\w-]+))\s*(?::-((?:<[^>]*>|[^>])+))?\s*>}x;

# sanitize environment: trim whitespace and escape quotes, but do not delete variables like PATH/HOME
sub sanitize_env {
    foreach my $key ( keys %ENV ) {
        my $value = $ENV{$key};
        $value =~ s/^\s+|\s+$//g;    # trim
        $ENV{$key} = $value;
    }
}

# Global cache to track pre-hooks that have already executed in this process
my %executed_pre_hooks;

# Track which (var, template_file) unbound-warnings have already been emitted
# in this process, so a placeholder repeated N times in one file doesn't
# produce N identical warn lines.
my %warned_unbound;

sub import_shell_env {
    my ($cmd) = @_;
    return unless $cmd;

    # Only import shell env if PRE hooks are explicitly allowed
    unless ($ALLOW_PRE) {
        warn
            "@[arg:allow_pre(false)]: Skipping pre-hook (HYDE_TMQ_ALLOW_PRE not enabled): $cmd\n";
        return;
    }

    # If this command ran already in this process, skip re-running it
    return if $executed_pre_hooks{$cmd}++;

    open my $fh, '-|', 'bash', '-c', "$cmd && env -0"
        or do {
        warn
            "@[diagnostic:error:arg:allow_pre(false)]: Failed pre-hook '$cmd': $!";
        return;
        };

    local $/ = "\0";
    my $env_changed = 0;

    while ( my $entry = <$fh> ) {
        chomp $entry;
        if ( $entry =~ /^([^=]+)=(.*)$/s ) {
            my ( $key, $val ) = ( $1, $2 );
            if ( !exists $ENV{$key} || $ENV{$key} ne $val ) {
                $ENV{$key} = $val;
                $env_changed = 1;
            }
        }
    }
    close $fh;

    if ($env_changed) {
        sanitize_env();
        build_env_cache();
    }
}

sub build_env_cache {
    %REPLACE = %RGBA_BASE = ();
    while ( my ( $k, $v ) = each %ENV ) {

        # permissive match for explicit rgba(R, G, B, A) strings
        if (   $k =~ /_rgba$/
            && $v
            =~ /rgba\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*,/ )
        {
            $RGBA_BASE{$k} = "rgba($1,$2,$3,";
            $REPLACE{$k}   = $v;
            next;
        }

        if ( defined $v && $v =~ /^#?([0-9A-Fa-f]{6})$/ ) {
            my $hex = $1;
            my ( $r, $g, $b ) = (
                hex substr( $hex, 0, 2 ),
                hex substr( $hex, 2, 2 ),
                hex substr( $hex, 4, 2 )
            );
            my $rgba_key = $k . "_rgba";
            $RGBA_BASE{$rgba_key}
                = sprintf( "rgba(%d,%d,%d,", $r, $g, $b );
            $REPLACE{$rgba_key}
                = sprintf( "rgba(%d,%d,%d,1)", $r, $g, $b );
        }

        # default store the original variable
        $REPLACE{$k} = $v;
    }
}

build_env_cache();

my $current_lock;
$SIG{INT} = $SIG{TERM} = $SIG{HUP} = sub {
    release_lock($current_lock) if defined $current_lock;
    exit 1;
};

sub fnv1a_hex {
    my ($str) = @_;
    my $hash = 0x811c9dc5;
    for my $byte ( unpack( 'C*', $str ) ) {
        $hash ^= $byte;
        $hash = ( $hash * 0x01000193 ) & 0xFFFFFFFF;
    }
    return sprintf( '%08x', $hash );
}

# Acquire a per-target mkdir-based lock. Returns lockdir path on success or dies on timeout.
sub acquire_lock {
    my ($target_path) = @_;
    my $hash          = fnv1a_hex($target_path);
    my $lockdir = File::Spec->catfile( $locks_base, "$hash.lock" );
    my $start   = time();

    while (1) {

        # Try to create directory atomically

        if ( mkdir $lockdir ) {

            # created lock successfully
            return $lockdir;
        }

        # If exists, check age and remove stale locks
        if ( -d $lockdir ) {
            my $age = time() - ( ( stat($lockdir) )[9] || 0 );
            if ( $age > $LOCK_TIMEOUT ) {
                warn
                    "@[atomic:remove:stale_lock(true)]: Removing stale lock $lockdir (age ${age}s)\n";
                rmdir $lockdir
                    ;    # attempt removal; next loop will try mkdir
                next;
            }
        }

        # check timeout
        if ( time() - $start > $LOCK_TIMEOUT ) {
            die
                "@[atomic:timeout(?)]: Timeout acquiring lock for $target_path (waited ${LOCK_TIMEOUT}s)\n";
        }
        select( undef, undef, undef, 0.05 );    # sleep 50ms
    }
}

sub release_lock {
    my ($lockdir) = @_;
    return unless $lockdir;
    if ( -d $lockdir ) {
        rmdir $lockdir
            or warn
            "@[atomic:release_lock(false)] Could not remove lock $lockdir: $!";
    }
}

sub fsync_or_warn {
    my ($fh) = @_;
    return unless defined $fh;

    # If the handle supports sync(), prefer it.
    if ( ref($fh) && $fh->can('sync') ) {
        eval { $fh->sync(); 1 } or do {
            warn "@[atomic:scan_status(failed)]: sync failed: $!\n"
                if $SPIT_DEBUG;
        };
        return;
    }

    # Otherwise try flush() (IO::Handle provides it)
    if ( ref($fh) && $fh->can('flush') ) {
        eval { $fh->flush(); 1 } or do {
            warn "@[atomic:fsync(failed)]: flush failed: $!\n"
                if $SPIT_DEBUG;
        };
        return;
    }

    warn
        "@[atomic:fsync_compatibility(unavailable)]: fsync/flush not available on this Perl build; durability not guaranteed\n"
        if $SPIT_DEBUG;
}

sub write_temp_file {
    my ( $t_dir, $content ) = @_;
    make_path($t_dir) unless -d $t_dir;

    my ( $fh, $tmp_path );
    my $attempts = 0;
    while (1) {
        $attempts++;
        my $candidate = File::Spec->catfile(
            $t_dir,
            sprintf(
                '.tmq_tmp.%d.%d.%d',
                $$, time(), int( rand(1e9) )
            )
        );
        if (sysopen(
                $fh, $candidate, O_CREAT | O_EXCL | O_RDWR, 0600
            )
            )
        {
            $tmp_path = $candidate;
            last;
        }
        die
            "Could not create a temp file in $t_dir after $attempts attempts: $!"
            if $attempts >= 100;
    }

    binmode $fh;
    print $fh $content;
    $fh->flush;
    fsync_or_warn($fh) unless $NO_ATOMIC;
    close $fh or die "Failed closing tmp file $tmp_path: $!";
    return $tmp_path;
}

# Atomic rename helper (rename tmp -> target)
sub rename_tmp_to_target {
    my ( $tmp_path, $target ) = @_;

    if ( -f $target ) {
        my $mode = ( stat($target) )[2] & 07777;
        chmod $mode, $tmp_path;
    }

    rename $tmp_path, $target or do {
        unlink $tmp_path if -f $tmp_path;
        die
            "@[atomic:rename_status(failure)]: Atomic rename failed: $!";
    };
}

sub direct_write_to_target {
    my ( $target, $content ) = @_;
    my $t_dir = dirname($target);
    make_path($t_dir) unless -d $t_dir;

    my $tmp = write_temp_file( $t_dir, $content );
    rename_tmp_to_target( $tmp, $target );
}

%SKIP_SET = map { $_ => 1 } (
    $ENV{HYDE_TMQ_IGNORE_TEMPLATES}
    ? split /\s+/,
        $ENV{HYDE_TMQ_IGNORE_TEMPLATES}
    : ()
);

sub process_template {
    my ($template_file) = @_;
    return unless -f $template_file;

    $raw = do {
        local $/;
        open my $fh, '<', $template_file
            or die
            "@[populate:open(true)]: Cannot open $template_file: $!";
        <$fh>;
    };

    if ($DISABLE_FALLBACK) {
        while ( $raw =~ /$PLACEHOLDER_RE/g ) {
            if ( defined $4 ) {
                die
                    "@[diagnostic:arg:ignore_unbound(true)]: $template_file uses :- fallback syntax, which is disabled under --disable-fallback\n";
            }
        }
    }

    $nl     = index( $raw, "\n" );
    $header = $nl >= 0 ? substr( $raw, 0, $nl ) : $raw;

    my $has_hooks = ( index( $header, '|' ) >= 0 );

    $body = $nl >= 0 ? substr( $raw, $nl + 1 ) : '';
    $header =~ s/^\s+|\s+$//g;

    my $replacer;
    $replacer = sub {
        my ( $rgba_base, $rgba_args, $var_name, $fallback ) = @_;

        my $resolve_fallback = sub {
            my ($fb) = @_;
            return undef unless defined $fb;
            $fb =~ s/^\s+|\s+$//g;

            $fb =~ s{$PLACEHOLDER_RE}{$replacer->($1, $2, $3, $4)}ge;
            return length($fb) ? $fb : undef;
        };

        if ( defined $var_name ) {
            return $REPLACE{$var_name} if exists $REPLACE{$var_name};

            my $fb_val = $resolve_fallback->($fallback);
            return $fb_val if defined $fb_val;

            return "<$var_name>" if $IGNORE_UNBOUND;

            if ($ALLOW_STRICT_WARNINGS) {
                die
                    "@[diagnostic:arg:strict_warn(true)]: Unbound variables <$var_name> in $template_file\n"
                    if $ALLOW_STRICT_WARNINGS;
            }
            else {
                warn
                    "@[diagnostic:warn(true)]: Unbound variables <$var_name> in $template_file; leaving as placeholder\n"
                    unless $warned_unbound{
                    "$var_name\0$template_file"}++;
                return "<$var_name>";
            }
        }
        else {
            return "$RGBA_BASE{$rgba_base}$rgba_args)"
                if exists $RGBA_BASE{$rgba_base};

            my $fb_val = $resolve_fallback->($fallback);
            return $fb_val if defined $fb_val;

            return "<$rgba_base>" if $IGNORE_UNBOUND;

            if ($ALLOW_STRICT_WARNINGS) {
                die
                    "@[diagnostic:arg:strict_warn(true)]: Unbound rgba variable <$rgba_base> in $template_file\n"
                    if $ALLOW_STRICT_WARNINGS;

                return "<$rgba_base>";
            }
            else {
                warn
                    "@[diagnostic:warn(true)]: Unbound rgba variable <$rgba_base> in $template_file; leaving as placeholder\n"
                    unless $warned_unbound{
                    "$rgba_base\0$template_file"}++;
                return "<$rgba_base>";
            }

        }
    };

    ( $target, $pre_script, $post_script, $post_is_run )
        = ( '', '', '', 0 );

    if ($has_hooks) {
        if ( $header
            =~ s/\|\s*\$PRE:(.*?)(?=\|\s*\$(?:RUN|PRE):|$)//s )
        {
            $pre_script = $1;
            $pre_script =~ s/^\s+|\s+$//g;
        }

        if ( $header =~ s/\|\s*\$RUN:(.*)$//s ) {
            $post_script = $1;
            $post_is_run = 1;
            $post_script =~ s/^\s+|\s+$//g;
        }
        elsif ( $header =~ s/\|(.*)$//s ) {
            $post_script = $1;
            $post_script =~ s/^\s+|\s+$//g;
        }

        # Whatever remains before the first pipe is the target
        $header =~ s/^\s+|\s+$//g;
        $header =~ s/\|$//;
        $target = $header;

    }
    elsif ($header) {

    # If header looks like a placeholder (<...>), or a path/filename,
    # treat it as the target. Otherwise treat the entire file as body.
        if (   $header =~ $PLACEHOLDER_RE
            || $header =~ m{[\\/]}
            || $header !~ /\s/ )
        {
            $target = $header;
        }
        else {
            $body = $raw;    # Entire file is body
        }
    }
    else {
        $body = $raw;        # Entire file is body
    }

    # Execute Pre-Hook (only if allowed via HYDE_TMQ_ALLOW_PRE)
    if ($pre_script) {
        $pre_script
            =~ s{$PLACEHOLDER_RE}{$replacer->($1, $2, $3, $4)}ge
            if $pre_script =~ /[<>()]/;

        unless ( $ENV{HYDE_TMQ_PRE_SCAN_RAN} ) {
            import_shell_env($pre_script);
        }
        else {
            warn
                "@[diagnostic:warn:arg:pre_scan(true) - Prescan already ran; skipping PRE for $template_file\n]"
                if $SPIT_DEBUG;
        }
    }

    # Substitute placeholders in target, post_script, and body
    $target =~ s{$PLACEHOLDER_RE}{$replacer->($1, $2, $3, $4)}ge
        if $target && $target =~ /[<>()]/;

    $post_script =~ s{$PLACEHOLDER_RE}{$replacer->($1, $2, $3, $4)}ge
        if $post_script && $post_script =~ /[<>()]/;

    $body =~ s{$PLACEHOLDER_RE}{$replacer->($1, $2, $3, $4)}ge
        if $body && $body =~ /[<>()]/;

# Ensure we have a concrete target path before attempting to write.
# If templates are intended to produce stdout or similar, change this behavior.
    unless ( defined $target && length $target ) {
        print
            "@[arg:empty_path(true)] No target specified in $template_file; skipping\n"
            if $SPIT_DEBUG;
        return;
    }

    $target_dir = dirname($target);

    if ( $target_dir && $target_dir ne '' && $target_dir ne '.' ) {
        unless ( $made_dirs{$target_dir}++ ) {
            make_path($target_dir) unless -d $target_dir;
        }
    }

    $existing = "";
    my $file_exists = 0;

    if ( -f $target ) {
        $existing = do {
            local $/;
            open my $fh, '<', $target
                or die
                "@[populate:error(true)]: Cannot read $target: $!";
            <$fh>;
        };
        $file_exists = 1;
    }

    my $contents_changed = ( $existing ne $body );
    my $needs_write      = ( !$file_exists || $contents_changed );
    my $lockDir;

    if ($needs_write) {
        if ($DRY_RUN) {
            print
                "@[arg:dry_run(true)]: Would populate $target <- $template_file\n"
                if $SPIT_DEBUG;
        }
        else {
            my $lockDir;
            if ($NO_ATOMIC) {

 # Direct write under lock (faster, less durable). Acquire lock first.
                eval {
                    $lockDir = acquire_lock($target);
                    direct_write_to_target( $target, $body );
                    1;
                } or do {
                    my $err
                        = $@ || "Unknown error during direct write";
                    warn
                        "@[populate:error(true)]: Failed writing $target directly: $err";
                    release_lock($lockDir) if defined $lockDir;
                    die $err;
                };
                release_lock($lockDir) if defined $lockDir;
            }
            else {
# Atomic path: prepare tmp (with optional fsync), then lock and rename.
                my $tmp_path;
                eval {
                    $tmp_path = write_temp_file( $target_dir, $body );
                    1;
                } or do {
                    my $err = $@ || "Unknown error preparing tmp";
                    warn
                        "@[populate:error(true)]: Failed preparing tmp for $target: $err";
                    unlink $tmp_path
                        if defined $tmp_path && -f $tmp_path;
                    die $err;
                };

                eval {
                    $lockDir = acquire_lock($target);
                    rename_tmp_to_target( $tmp_path, $target );
                    1;
                } or do {
                    my $err
                        = $@ || "Unknown error during locked rename";
                    warn
                        "@[populate:error(true)]: Failed writing $target: $err";
                    unlink $tmp_path
                        if defined $tmp_path && -f $tmp_path;
                    release_lock($lockDir) if defined $lockDir;
                    die $err;
                };

                release_lock($lockDir) if defined $lockDir;
            }
        }
    }

    if ( $post_script && $ALLOW_RUN ) {
        if ($DRY_RUN) {
            print
                "@[arg:dry_run(true)]: Would run post-script: $post_script\n"
                if $SPIT_DEBUG;
        }
        else {
            if ($post_is_run) {
                system($post_script) == 0
                    or warn
                    "@[execution:error(true)]: Failed to execute $post_script from $template_file: $?";
            }
            elsif ( -x $post_script ) {
                system($post_script) == 0
                    or warn
                    "@[execution:error(true)]: Failed to execute $post_script from $template_file";
            }
            else {
                print
                    "@[execution(false)]: Theme Control - Skipped non-executable script from $template_file\n"
                    if $SPIT_DEBUG;
            }
        }
    }

    if ($SPIT_DEBUG) {
        if ($needs_write) {
            print
                "@[populate:write(true)]: $target <- $template_file\n";
        }
        else {
            print
                "@[populate:write(false)]: Skipped changing $target <- $template_file\n";
        }
    }

}

find(
    {   wanted => sub {
            return
                unless -f && /\.(dcol|theme)$/
                && !exists $SKIP_SET{ basename($_) };
            $found = 1;
            push @files, $File::Find::name;
        },
        no_chdir => 1,
    },
    @template_source
);

unless ($found) {
    printf(
        "@[stream:file_capture(false)]: %s: no .dcol templates found, nothing to apply.\n",
        $SCRIPT_NAME );
    exit 1;
}

@files = map { $_->[0] }
    sort {
    my ( $ap, $bp ) = ( $a->[1], $b->[1] );
    $res = 0;
    for ( my $i = 0; $i < @$ap && $i < @$bp; $i++ ) {
        $res
            = $ap->[$i] =~ /^\d+$/ && $bp->[$i] =~ /^\d+$/
            ? ( $ap->[$i] <=> $bp->[$i] )
            : ( lc( $ap->[$i] ) cmp lc( $bp->[$i] ) );
        last if $res;
    }

    $res || scalar(@$ap) <=> scalar(@$bp);
    }
    map { [ $_, [ split /(\d+)/, $_ ] ] } @files;

if ($ALLOW_PRE_SCAN) {
    unless ($ALLOW_PRE) {
        die
            "@[arg:required_flag(--allow-pre)]: Pre-scan requested but PRE is not allowed. Set \$HYDE_TMQ_ALLOW_PRE=1.\n";

    }

    my %seen_pre;
    foreach my $f (@files) {
        next unless -f $f;
        my $hdr = "";
        if ( open my $fh, '<', $f ) {
            $hdr = <$fh> // "";
            close $fh;
            $hdr =~ s/^\s+|\s+$//g;
        }

        my $pre = "";
        if ( $hdr =~ /\|\s*\$PRE:(.*?)(?=\|\s*\$(?:RUN|PRE):|$)/s ) {
            $pre = $1;
            $pre =~ s/^\s+|\s+$//g;
        }

        next unless $pre;
        unless ( $seen_pre{$pre}++ ) {
            warn
                "@[active:arg:flag(--pre-scan)]: Running PRE - $pre \n"
                if $SPIT_DEBUG;
            import_shell_env($pre);
        }
    }

    $ENV{HYDE_TMQ_PRE_SCAN_RAN} = 1;
    build_env_cache();
}

$n       = scalar @files;
$workers = $n < $NPROC ? $n : $NPROC;
$chunk   = int( ( $n + $workers - 1 ) / $workers ); # ceiling division

my $t0 = [gettimeofday];

for ( my $i = 0; $i < $n; $i += $chunk ) {
    my $end = $i + $chunk - 1;
    $end = $n - 1 if $end >= $n;

    my $pid = fork // die "Fork failed: $!";
    if ( $pid == 0 ) {
        eval {
            process_template( $files[$_] ) for $i .. $end;
            1;
        } or do {
            warn
                "@[diagnostic:error:fork:worker(false)]: Worker encountered an error: \n\t$@";
            exit 1;
        };
        exit 0;
    }
    $pids{$pid} = 1;
}

# Wait for children and record failures
my $failed = 0;
while ( scalar keys %pids ) {
    my $p = wait();
    if ( $p > 0 ) {
        my $status = $? >> 8;
        $failed = 1 if $status != 0;
        delete $pids{$p};
    }
}

if ( $failed == 0 ) {
    my $elapsed = tv_interval($t0);
    printf(
        "@[diagnostic:telemetry(On)]: Rendered %d templates using %d workers in %.4f seconds.\n",
        $n, $workers, $elapsed )
        if $SPIT_DEBUG;
}
exit( $failed ? 1 : 0 );
EOF
