#!/usr/bin/env bash

if [[ -z $VYLE_SHELL_INIT ]]; then
  scrDir="$(dirname "$(realpath "$0")")"
  source "${scrDir}/globalcontrol.sh"
fi
export VYLE_CONFIG_HOME VYLE_THEME XDG_CACHE_HOME XDG_CONFIG_HOME skipTemplate scrDir plLoader nProcCount
export SCRIPT_NAME=$0

ionice -c 2 -n 9 perl -e '

use POSIX qw(WNOHANG);
use File::Basename qw(basename dirname);
use File::Find qw(find);
use File::Path qw(make_path);
use Digest::SHA qw(sha1_hex);

# -----------------------
# Configuration
# -----------------------
my ($VYLE_CONFIG_HOME, $VYLE_THEME, $XDG_CONFIG_HOME, $XDG_CACHE_HOME, $LIB_DIR, $PLACELOADER, $NPROC,
    $THEME_DCOL_DIR, $HOME_DIR, $THEMES_DIR, $INPUT_PATH, $SCRIPT_NAME, @SKIP_TEMPLATE, $DCOL_PATH);
my (@template_source, %dir_map);
my ($first_line, $target, $script, $rel, $template_write, $target_dir, $raw_first_line, @first_line, $target_content, $template_hash);

$VYLE_CONFIG_HOME = $ENV{VYLE_CONFIG_HOME};
$VYLE_THEME = $ENV{VYLE_THEME};
$XDG_CONFIG_HOME = $ENV{XDG_CONFIG_HOME};
$XDG_CACHE_HOME = $ENV{XDG_CACHE_HOME};
$LIB_DIR = $ENV{scrDir};
$PLACELOADER = $ENV{plLoader};
$NPROC = $ENV{nProcCount};

$DCOL_PATH = "$VYLE_CONFIG_HOME/theme/$VYLE_THEME";

if ( $VYLE_THEME eq "Wallbash-Ivy" ) {
  $DCOL_PATH = "$VYLE_CONFIG_HOME/Wall-Dcol";
}

$THEME_DCOL_DIR = "$VYLE_CONFIG_HOME/Wall-Ways";
$HOME_DIR = "$ENV{HOME}";
$THEMES_DIR = "$HOME_DIR/.themes";

$INPUT_PATH = $ARGV[0] // "";
$SCRIPT_NAME = $ENV{SCRIPT_NAME};
@SKIP_TEMPLATE = $ENV{skipTemplate} ? split /\s+/, $ENV{skipTemplate} : ();

if 
  ( $INPUT_PATH && -f $INPUT_PATH ) 
{
  @template_source= ( $INPUT_PATH );
} 
elsif 
  ( $INPUT_PATH && -d $INPUT_PATH ) 
{
  @template_source = ( $INPUT_PATH, $THEME_DCOL_DIR );
}
else 
{
  @template_source = ( $DCOL_PATH, $THEME_DCOL_DIR );
}

if 
  ( $> == 0 ) 
{ 
  $SCRIPT_NAME = basename($SCRIPT_NAME);
  print( "[${SCRIPT_NAME}] must not be ran as root.\n" );
  exit 1;
}

# -----------------------
# Load palettes
# -----------------------
sub load_varfs {
  my ($file) = @_;

  open my $fh, "<", $file or die "Cannot open $file or empty: $!";

  while 
    ( defined ( my $line = <$fh> ) ) 
  {
    chomp($line);

    ( $line =~ /^\s*$/ || $line =~ /^\s*#/ ) && next;
    if 
      ( $line =~ /^[^=]+=[^=]*$/ ) 
    {
      my ($key, $value) = split /=/, $line, 2;
      $value =~ s/^#//;
      $ENV{$key} = $value;
    }
  }
  close $fh;
}

load_varfs("$VYLE_CONFIG_HOME/theme.ivy");
load_varfs("$VYLE_CONFIG_HOME/theme-rgba.ivy");

# -----------------------
# Replacement function (dynamic fallback)
# -----------------------
sub r {
  my ($rgba_var, $op, $std_var) = @_;
  
  # Static variable fallback
  if 
    ($std_var) 
  {
    return $ENV{$std_var} // "<$std_var>";
  }
    
  # Dynamic rgba replacement
  if 
    (defined $ENV{$rgba_var} && $ENV{$rgba_var} =~ /rgba\((\d+),(\d+),(\d+),[\d.]+\)/) 
  {
    return "rgba($1,$2,$3,$op)";
  }
  
  my $return = $std_var || $rgba_var || "unknown";
  return "<$return>";
}

# -----------------------
# Replacement engine
# -----------------------
sub apply_env_replacements {
  my @lines = @_;
  my $output = "";

  # -----------------------
  # Precompute static ENV hash (fast path)
  # -----------------------
  my %replace = map { $_ => $ENV{$_} } grep { $_ !~ /_rgba$/ } keys %ENV;

  # -----------------------
  # Precompute RGBA base colors
  # -----------------------
  my %rgba_base;
  for my $k (keys %ENV) {
    if 
      ($k =~ /(.*)_rgba$/ && $ENV{$k} =~ /rgba\((\d+),(\d+),(\d+),[\d.]+\)/)
    {
      $rgba_base{$k} = [$1,$2,$3];
    }
  }

  # -----------------------
  # Single regex pass per line
  # -----------------------
  my $re = qr{<\s*(?:(\w+_rgba)\(\s*([^)]+)\s*\)|(\w+))\s*>}x;

  foreach my $line (@lines) 
  {
    $line =~ s{$re} {
      if 
        ( defined $3 ) 
      {
        # Static variable
        $replace{$3} // r($3, undef, $3);
      } 
      else 
      {
        # RGBA dynamic
        my ($r,$g,$b) = @{ $rgba_base{$1} || [] };
        defined $r ? "rgba($r,$g,$b,$2)" : r($1,$2);
      }
    }gex;
    $output .= $line;
  }
  return $output;
}

%dir_map = (
  scrDir    => $LIB_DIR,
  confDir   => $XDG_CONFIG_HOME,
  cacheDir  => $XDG_CACHE_HOME,
  homeDir   => $HOME_DIR,
  themesDir => $THEMES_DIR
);

# -----------------------
# Template processing engine
# -----------------------
sub process_template 
{
  my ($template_file) = @_;

  ( ! -f $template_file ) && exit 0;

  open my $fh, "<", $template_file or die "Cannot open $template_file or empty: $!";
  @first_line = <$fh>;
  close($fh);

  my $raw_first_line = $first_line[0];
  chomp($raw_first_line);

  $raw_first_line =~ s/^\s+|\s+$//g;
  $first_line = $raw_first_line;

  if 
    ( $first_line =~ /\|/ || ($first_line && $first_line !~ /^\s*</) )
  {
    ($target, $script) = ($first_line =~ /\|/) ? split(/\|/, $first_line, 2) : ($first_line, "");
    shift @first_line;
  }

  $target =~ s{\$\((\w+)\)}{$dir_map{$1} // $&}ge;
  $script =~ s{\$\((\w+)\)}{$dir_map{$1} // $&}ge if $script;
  $template_write = apply_env_replacements(@first_line);

  # -----------------------
  # Write template output
  # -----------------------
  $target_dir = dirname($target);
  ( -d $target_dir ) || make_path($target_dir) or die " :: Failed to create $target_dir !";
  
  $target_content = (-f $target) ? do { open my $fh, "<", $target; sha1_hex(<$fh>) } : "";
  $template_hash = sha1_hex($template_write);

  if 
    ( ! -f $target || $template_hash ne $target_content )
  {
    open my $fh, ">", $target or die "Cannot write to $target: $!";
    print $fh $template_write;
    close $fh;

    # -----------------------
    # Execute optional script safely
    # -----------------------
    if 
      ($script)
    {
      $script =~ s/^\s+|\s+$//g;
      if 
        ( $script eq "")
      {
      
      }
      if 
        ( $script =~ /^\$RUN:/ )
      {
        $script =~ s/^\$RUN://;
        system("$script") == 0 
        or warn " :: Theme Control - Failed to execute ${script} from ${template_file} : $?";
      }
      elsif 
        ( -x $script ) 
      { 
        system("$script") == 0 
        or warn " :: Theme Control - Failed to execute ${script} from ${template_file}";
      }
      else 
      {
        print(" :: Theme Control - Skipped non-executable script from ${template_file}\n");
      }
    }
    print(" :: Theme Control - Populating $target <- $template_file\n");
  }
  else
  {
    print(" :: Theme Control - Skipped changing $target <- $template_file\n");
  }


}

# Optional glob-to-regex helper
sub glob_to_re {
  my ($glob) = @_;
  $glob =~ s/([\\.^$+(){}|\[\]])/\\$1/g;
  $glob =~ s/\*/.*/g;
  $glob =~ s/\?/.?/g;
  return qr/\A$glob\z/;
}

sub is_skipped {
  my ($name) = @_;
  for my $skip (@SKIP_TEMPLATE) {
    return 1 if $name eq $skip;  # exact match
    # if $skip contains a glob, use this:
    # my $re = glob_to_re($skip);
    # return 1 if $name =~ $re;
  }
  return 0;
}

if 
  ( -f $template_source[0] )
{
  process_template("${template_source[0]}");
}
else 
{
  # -----------------------
  # Run templates in parallel
  # -----------------------
  my (@files, @a_parts, $b_parts, @res, %pids, $waited, $zombie, $last_pid, $pid, $found);
  $found = 0;
  find 
  (
    {
      wanted => sub 
      {
        return unless -f $_;
        return unless /\.(dcol|ivy|theme)$/;
        return if is_skipped($_);

        $found = 1;
        push @files, $File::Find::name;
      },
      no_chdir => 1,
    },
    @template_source
  );

  if 
    ( ! $found )
  {
    $SCRIPT_NAME = basename($SCRIPT_NAME);
    print("${SCRIPT_NAME}: no .dcol or .ivy templates found, nothing to apply.");
    exit 1;
  }

  @files = sort {
    @a_parts = split(/(\d+)/, $a);
    @b_parts = split(/(\d+)/, $b);
    $res = 0;

    for 
      ( my $i = 0; $i < @a_parts && $i < @b_parts; $i++ )
    {
      if 
        ( $a_parts[$i] =~ /^\d+$/ && $b_parts[$i] =~ /^\d+$/ )
      {
        $res = $a_parts[$i] <=> $b_parts[$i];
      }
      else
      {
        $res = lc($a_parts[$i]) cmp lc($b_parts[$i]);
      }
      last if $res;
    }
    $res || @a_parts <=> @b_parts;
  } @files;

  foreach my $f (@files) {
    if 
      ( keys %pids >= $NPROC )
    {
      $waited = wait();
      delete $pids{$waited} if $waited > 0;
    }

    $pid = fork();
    die "Fork failed" unless defined $pid;
    if 
      ( $pid == 0 )
    {
      process_template($f);
      exit(0);
    }
    else
    {
      $pids{$pid} = 1;
    }

    while (($zombie = waitpid(-1, WNOHANG)) > 0) { delete $pids{$zombie}; }
  }

  while
    ( keys %pids )
  {
    $last_pid = wait();
    delete $pids{$last_pid} if $last_pid > 0;
  }
}
' "$@"
