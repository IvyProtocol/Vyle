#!/usr/bin/env bash

if [[ -z $VYLE_SHELL_INIT ]]; then
  scrDir="$(dirname "$(realpath "$0")")"
  source "${scrDir}/globalcontrol.sh"
fi

export LIB_DIR=$scrDir
export VYLE_CONFIG_HOME VYLE_THEME XDG_CACHE_HOME XDG_CONFIG_HOME VYLE_CONFIGURATION_SKIP_TEMPLATE VYLE_CONFIGURATION_CORE
export SCRIPT_NAME=$0

perl - "$@" <<'EOF'
use File::Find     qw(find);
use File::Path     qw(make_path);

my ($VYLE_CONFIG_HOME, $VYLE_THEME, $XDG_CONFIG_HOME, $XDG_CACHE_HOME,
    $LIB_DIR, $NPROC, $SCRIPT_NAME, $INPUT_PATH,
    $DCOL_PATH, $THEME_DCOL_DIR, $HOME_DIR, $THEMES_DIR, $PLACEHOLDER_RE, $DIR_VAR_RE, $PRECHECK_RE, $XDG_DATA_HOME);
my (%dir_map, %REPLACE, %RGBA_BASE, %SKIP_SET, %made_dirs, @template_source, @files, %pids);
my ($raw, $nl, $header, $body, $target, $script, $target_dir, $existing, $found, $n, $workers, $chunk, $res);

$VYLE_CONFIG_HOME = $ENV{VYLE_CONFIG_HOME};
$VYLE_THEME       = $ENV{VYLE_THEME};
$XDG_CONFIG_HOME  = $ENV{XDG_CONFIG_HOME};
$XDG_CACHE_HOME   = $ENV{XDG_CACHE_HOME};
$XDG_DATA_HOME = $ENV{XDG_DATA_HOME};

$LIB_DIR          = $ENV{LIB_DIR};
$NPROC            = $ENV{VYLE_CONFIGURATION_CORE} || 1;
$SCRIPT_NAME      = $ENV{SCRIPT_NAME};
$SCRIPT_NAME =~ s{/[^/]+$}{};

$INPUT_PATH       = $ARGV[0] // '';
$ENV{INPUT_PATH} = $INPUT_PATH;

$DCOL_PATH = ($VYLE_THEME eq 'Wallbash-Ivy')
  ? "$VYLE_CONFIG_HOME/Wall-Dcol"
  : "$VYLE_CONFIG_HOME/theme/$VYLE_THEME";

$THEME_DCOL_DIR = "$VYLE_CONFIG_HOME/Wall-Ways";
$HOME_DIR       = $ENV{HOME};
$THEMES_DIR     = "$HOME_DIR/.themes";

@template_source =
    -f $INPUT_PATH ? ($INPUT_PATH)
  : -d $INPUT_PATH ? ($INPUT_PATH, $THEME_DCOL_DIR)
  :                  ($DCOL_PATH,  $THEME_DCOL_DIR);

if 
  ( $> == 0 ) 
{
  printf("[%s] must not be ran as root.\n", $SCRIPT_NAME);
  exit 1;
}

$PLACEHOLDER_RE = qr{<\s*(?:(\w+_rgba)\(\s*([^)]+)\s*\)|(\w+))\s*>};
$DIR_VAR_RE     = qr{\$\((\w+)\)};

sub load_varfs {
  my ($file) = @_;

  open my $fh, "<", $file or die "Cannot open $file or empty: $!";

  while 
    ( defined ( my $line = <$fh> ) ) 
  {
    chomp($line);

    $line =~ s/^\s+|\s+$//g;
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

sub build_env_cache {
  %REPLACE = %RGBA_BASE = ();
  while 
    (my ($k, $v) = each %ENV) 
  {
    if 
      (substr($k, -5) eq '_rgba')
    {
      $RGBA_BASE{$k} = "rgba($1,$2,$3," if $v =~ /rgba\((\d+),(\d+),(\d+),/;
    } 
    else 
    {
      $REPLACE{$k} = $v;
    }
  }
}

build_env_cache();

%dir_map = (
  scrDir    => $LIB_DIR,      
  confDir   => $XDG_CONFIG_HOME,
  cacheDir  => $XDG_CACHE_HOME, 
  homeDir   => $HOME_DIR,
  themesDir => $THEMES_DIR,
  dataDir => $XDG_DATA_HOME,
);

%SKIP_SET = map { $_ => 1 }
  ($ENV{VYLE_CONFIGURATION_SKIP_TEMPLATE} ? split /\s+/, $ENV{VYLE_CONFIGURATION_SKIP_TEMPLATE} : ());

sub process_template {
  my ($template_file) = @_;
  return unless -f $template_file;
  $raw = do { local $/; open my $fh, '<', $template_file or die "Cannot open $template_file: $!"; <$fh> };

  # index()/substr() for header detection — no regex engine startup cost.
  $nl     = index($raw, "\n");
  $header = $nl >= 0 ? substr($raw, 0, $nl) : $raw;
  $body   = $nl >= 0 ? substr($raw, $nl + 1) : '';

  $header =~ s/^\s+|\s+$//g;

  ($target, $script) = ('', '');
  $pipe = index($header, '|');
  
  if 
    ($pipe >= 0 || ($header && $header !~ /^\s*</)) 
  {
    if 
      ($pipe >= 0) 
    {
      $target = substr($header, 0, $pipe);
      $script = substr($header, $pipe + 1);
      $target =~ s/^\s+|\s+$//g;
      $script =~ s/^\s+|\s+$//g;
    } 
    else 
    {
      $target = $header;
    }
  } 
  else 
  {
    $body = $raw;    # no header — whole file is the body
  }

  $target =~ s{$DIR_VAR_RE}{$dir_map{$1} // $&}ge;
  $script =~ s{$DIR_VAR_RE}{$dir_map{$1} // $&}ge if $script;
  
  if 
    ( $body =~ /[<>()]/ )
  {
    $body =~ s{$PLACEHOLDER_RE} { defined $3 ? (exists $REPLACE{$3} ? $REPLACE{$3} : "<$3>") : exists $RGBA_BASE{$1} ? "$RGBA_BASE{$1}$2)" : "<$1>" }ge;
  }

  $target_dir = $target;
  $target_dir =~ s{/[^/]+$}{};

  unless 
    ($made_dirs{$target_dir}++)
  {
    make_path($target_dir) unless -d $target_dir;
  }

  $existing = "";
  if 
    (-f $target) 
  {
    $existing = do { local $/; open my $fh, '<', $target or die "Cannot read $target: $!"; <$fh> };
  }

  if 
    ($existing ne $body) 
  {
    open my $wfh, '>', $target or die "Cannot write $target: $!";
    print $wfh $body;
    close $wfh;

    if 
      ($script)
    {
      if 
        ((my $cmd = $script) =~ s/^\$RUN://) 
      {
        system($cmd) == 0
          or warn " :: Theme Control - Failed to execute $cmd from $template_file: $?";
      } 
      elsif 
        (-x $script) 
      {
        system($script) == 0
          or warn " :: Theme Control - Failed to execute $script from $template_file";
      } 
      else 
      {
        print " :: Theme Control - Skipped non-executable script from $template_file\n";
      }
    }
    print " :: Theme Control - Populating $target <- $template_file\n";
  } 
  else 
  {
    print " :: Theme Control - Skipped changing $target <- $template_file\n";
  }
}

if 
  (-f $template_source[0]) 
{
  process_template($template_source[0]);
  exit 0;
}

find(
  {
    wanted => sub {
      return unless -f && /\.(dcol|ivy|theme)$/ && !exists $SKIP_SET{$_};
      $found = 1;
      push @files, $File::Find::name;
    },
    no_chdir => 1,
  },
  @template_source
);

unless ($found) {
  printf("%s: no .dcol or .ivy templates found, nothing to apply.\n", $SCRIPT_NAME);
  exit 1;
}

@files = map  { $_->[0] }
  sort {
    my ($ap, $bp) = ($a->[1], $b->[1]);
    $res = 0;
    for 
      (my $i = 0; $i < @$ap && $i < @$bp; $i++) 
    {
      $res = $ap->[$i] =~ /^\d+$/ && $bp->[$i] =~ /^\d+$/ ? ($ap->[$i] <=>  $bp->[$i]) : (lc($ap->[$i]) cmp lc($bp->[$i]));
      last if $res;
    }
    
    $res || scalar(@$ap) <=> scalar(@$bp);
  }
  map  { [ $_, [ split /(\d+)/, $_ ] ] }
  @files;

$n       = scalar @files;
$workers = $n < $NPROC ? $n : $NPROC;
$chunk   = int(($n + $workers - 1) / $workers);   # ceiling division

for 
  (my $i = 0; $i < $n; $i += $chunk) 
{
  my $end = $i + $chunk - 1;
  $end = $n - 1 if $end >= $n;

  my $pid = fork // die "Fork failed: $!";
  if 
    ($pid == 0) 
  {
    process_template($files[$_]) for $i .. $end;
    exit 0;
  }
  $pids{$pid} = 1;
}

while 
  (scalar keys %pids) 
{
  my $p = wait();
  delete $pids{$p} if $p > 0;
}
EOF
