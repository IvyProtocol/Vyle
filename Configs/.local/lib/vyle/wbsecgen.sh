#!/usr/bin/env bash

scrDir="$(dirname "$(realpath "$0")")"
source "${scrDir}/globalcontrol.sh"
export BASH_SRC="${BASH_SOURCE[0]##*/}"
export XDG_RUNTIME_DIR VYLE_CACHE_HOME VYLE_CONFIG_HOME VYLE_RESERVED_THEME VYLE_STATE_HOME dunstDir

LOCK_FILE="$XDG_RUNTIME_DIR/${BASH_SRC}.lock"
trap 'rm -f $LOCK_FILE' EXIT

eval "$(
  perl - "$@" <<'EOF'
use Fcntl qw(:flock);

my ($XDG_RUNTIME_DIR, $LOCK_FILE, $VYLE_INSIDER_CACHE, $DUNST_DIR, $BASH_SRC);
$BASH_SRC = $ENV{BASH_SRC};
$XDG_RUNTIME_DIR = $ENV{XDG_RUNTIME_DIR};
$LOCK_FILE = "$XDG_RUNTIME_DIR/${BASH_SRC}.lock";
$VYLE_INSIDER_CACHE = "$ENV{VYLE_CACHE_HOME}/cache";

for my $dir ( "$VYLE_INSIDER_CACHE", "$VYLE_INSIDER_CACHE/blur", "$VYLE_INSIDER_CACHE/cols", "$VYLE_INSIDER_CACHE/thumb" ) 
{
    mkdir $dir unless -d $dir;
}


if 
  ( -e $LOCK_FILE )
{
  print("Error: Another instance of ${BASH_SRC} is running \n");
  print("if you are sure that no other instances of ${BASH_SRC} is running. Then, remove the lock file: \n");
  print("   $LOCK_FILE \n");

  system(
    "notify-send", "-a", "t2",
    "-r", "91190",
    "-t", "800",
    "-i", "$ENV{dunstDir}/icons/hyprdots.svg",
    "Vyle", "Another instance of $BASH_SRC is running!"
  ) == 0 or die "Failed to notify user to prompt a LOCK_FILE session existence.";
  exit 0;
}

open(my $fh, ">", $LOCK_FILE) or die "Cannot create lock: $!";
flock($fh, LOCK_EX | LOCK_NB) or die "Another instance is running\n";
print $fh $$;

print("export DUNST_DIR=$DUNST_DIR VYLE_INSIDER_CACHE=$VYLE_INSIDER_CACHE\n");
EOF
)"

HASH_WALLPAPER() {
  export WALLPAPER_CONFIGURATION_BACKEND WALLPAPER_SWWW_TRANSITION_STEPS WALLPAPER_SWWW_TRANSIITON_DURATION wallFramerate wallTransitionBezier VYLE_CURRENT_IMAGE VYLE_IMAGE_SOURCE
  eval "$(
    perl - "$@" <<'HASH'

my ($VYLE_IMAGE_SOURCE, $WALLPAPER_SET_FLAGS, $WALLPAPER_HAD_SET, $BASH_SRC, $LIB_DIR);

$VYLE_IMAGE_SOURCE = $ENV{VYLE_IMAGE_SOURCE};
$WALLPAPER_SET_FLAGS = $ENV{WALLPAPER_SET_FLAGS};
$WALLPAPER_HAD_SET = $ENV{VYLE_CURRENT_IMAGE};
$BASH_SRC = $ENV{BASH_SRC};
$LIB_DIR = $ENV{scrDir};

if
  ( ! defined $VYLE_IMAGE_SOURCE || $VYLE_IMAGE_SOURCE eq "" )
{
  $VYLE_IMAGE_SOURCE = "$WALLPAPER_HAD_SET";

  if 
    ( ! defined $VYLE_IMAGE_SOURCE || $VYLE_IMAGE_SOURCE eq "" )
  {
    system(
      "notify-send", "-a", "t2",
      "-u", "critical",
      "Vyle", "Inalid Wallpaper?",
      "-t", "900",
      "-i", "$ENV{DUNST_DIR}/icons/hyprdots.svg"
    ) == 0 or die "Failed to capture wallpaper for user. Is it empty and seems like notify is broke.";
    exit(1)
  }
}

print STDERR " :: Theme Control - $BASH_SRC - Wallpaper Control - Applying $VYLE_IMAGE_SOURCE \n";

if 
  ( $WALLPAPER_SET_FLAGS eq "--swww-p" )
{
  $WALLPAPER_SET_FLAGS = "-p";
}
elsif
  ( $WALLPAPER_SET_FLAGS eq "--swww-t" )
{
  $WALLPAPER_SET_FLAGS = "-t";
}
elsif
  ( $WALLPAPER_SET_FLAGS eq "swww-n" || $WALLPAPER_SET_FLAGS eq "" || ! defined $WALLPAPER_SET_FLAGS )
{
  $WALLPAPER_SET_FLAGS = "-n";
}

print("export WALLPAPER_SET_FLAGS=$WALLPAPER_SET_FLAGS VYLE_IMAGE_SOURCE=$VYLE_IMAGE_SOURCE \n");
HASH
  )"
  [[ -f "$VYLE_IMAGE_SOURCE" ]] || {
    echo "Invalid path: $VYLE_IMAGE_SOURCE"
    exit 1
  }
  export VYLE_IMAGE_SOURCE_HASH="$(md5sum "${VYLE_IMAGE_SOURCE}" | awk '{print $1}')"
}

SYNCHRONIZE_CONFIGURATION() {
  export ROFI_THEME_STYLE rasiDir VYLE_IMAGE_SOURCE
  eval "$(
    perl - "$@" <<'SYNCHRONIZE_CONFIGURATION'
use File::Basename qw(basename dirname);

my ($VYLE_IMAGE_SOURCE, $BASENAME_VYLE_IMAGE_SOURCE, $STRIP_VYLE_IMAGE_SOURCE);
my ($VYLE_CONFIG_HOME, $VYLE_RESERVED_THEME, $ROFI_THEME_STYLE, $THEME_FILE_EXTENSION, $BASH_SRC);

$VYLE_CONFIG_HOME = $ENV{VYLE_CONFIG_HOME};
$VYLE_RESERVED_THEME = $ENV{VYLE_RESERVED_THEME};
$ROFI_THEME_STYLE = $ENV{ROFI_THEME_STYLE};
$ROFI_SHARED_DIRECTORY = $ENV{rasiDir};

$VYLE_IMAGE_SOURCE = $ENV{VYLE_IMAGE_SOURCE};
$STRIP_VYLE_IMAGE_SOURCE = basename($VYLE_IMAGE_SOURCE);
$BASENAME_VYLE_IMAGE_SOURCE = $STRIP_VYLE_IMAGE_SOURCE;
$STRIP_VYLE_IMAGE_SOURCE =~ s/\.[^.]+$//;

open(my $fh, ">", "$VYLE_CONFIG_HOME/theme/$VYLE_RESERVED_THEME/wallpapers/.wallbash-main") or die "Failed to write $VYLE_CONFIG_HOME/theme/$VYLE_RESERVED_THEME/wallpapers/.wallbash-main: $!";

print $fh $VYLE_IMAGE_SOURCE;
close $fh;

$THEME_FILE_EXTENSION = ( $ROFI_THEME_STYLE == 2 ) ? "quad" 
                      : ( $ROFI_THEME_STYLE == 1 ) ? "thumb"
                      : "thumb";

print("export STRIP_VYLE_IMAGE_SOURCE=$STRIP_VYLE_IMAGE_SOURCE ROFI_SHARED_DIRECTORY=$ROFI_SHARED_DIRECTORY THEME_FILE_EXTENSION=$THEME_FILE_EXTENSION BASENAME_VYLE_IMAGE_SOURCE=$BASENAME_VYLE_IMAGE_SOURCE \n");
SYNCHRONIZE_CONFIGURATION
  )"

  setConf "VYLE_CURRENT_IMAGE" "\${VYLE_CONFIG_HOME}/theme/\${VYLE_RESERVED_THEME}/wallpapers/${BASENAME_VYLE_IMAGE_SOURCE}" "${VYLE_STATE_HOME}/staterc"
  perl - "$@" <<'SYNCHRONIZE_CONFIGURATION'
my ($VYLE_INSIDER_CACHE, $BASENAME_VYLE_IMAGE_SOURCE, $STRIP_VYLE_IMAGE_SOURCE, $ROFI_SHARED_DIRECTORY, $THEME_FILE_EXTENSION);

$VYLE_CONFIG_HOME = $ENV{VYLE_CONFIG_HOME};
$VYLE_RESERVED_THEME = $ENV{VYLE_RESERVED_THEME};

$VYLE_INSIDER_CACHE = $ENV{VYLE_INSIDER_CACHE} || "$ENV{VYLE_CACHE_HOME}/cache";
$STRIP_VYLE_IMAGE_SOURCE = $ENV{STRIP_VYLE_IMAGE_SOURCE};

$ROFI_SHARED_DIRECTORY = $ENV{ROFI_SHARED_DIRECTORY};
$THEME_FILE_EXTENSION = $ENV{THEME_FILE_EXTENSION};

my %targets = (
  'cols'  => 'wall.cols',
  'blur'  => 'wall.bpex',
  'thumb' => 'wall.thmb',
);

for my $dir (keys %targets) {
  my $symlink_path = "$ROFI_SHARED_DIRECTORY/$targets{$dir}";
  unlink($symlink_path) if -e $symlink_path;  # remove old symlink
  my $source_path = "$VYLE_INSIDER_CACHE/$dir/$STRIP_VYLE_IMAGE_SOURCE." . ($dir eq 'cols' ? 'cols' : $dir eq 'blur' ? 'bpex' : 'sloc');
  symlink($source_path, $symlink_path) or die "Failed to create symlink $symlink_path: $!";
}

( -e "$VYLE_CONFIG_HOME/theme/$VYLE_RESERVED_THEME/wall.set" ) && unlink("$VYLE_CONFIG_HOME/theme/$VYLE_RESERVED_THEME/wall.set");
symlink("$VYLE_INSIDER_CACHE/$THEME_FILE_EXTENSION/${STRIP_VYLE_IMAGE_SOURCE}.${THEME_FILE_EXTENSION}", "$VYLE_CONFIG_HOME/theme/$VYLE_RESERVED_THEME/wall.set");
SYNCHRONIZE_CONFIGURATION
}

EXECUTE_WALLBASH_UPDATE() {
  export VYLE_CURRENT_IMAGE WALLBASH_MODE VYLE_IMAGE_SOURCE_HASH WALLBASH_COLOR_ARGUMENT VYLE_CACHE_HOME dcolMode scrDir
  export -f generate_theme
  eval "$(
    perl - "$@" <<'EOF'

my ($VYLE_IMAGE_SOURCE_HASH, $WALLPAPER_HAD_SET, $VYLE_WALLBASH_COLOR_MODE, $WALLBASH_COLOR_ARGUMENT, $DCOL_PATH, $ENABLE_WALLBASH_COLOR_MODE, $LIB_DIR, $VYLE_DCOL_PATH);
$LIB_DIR = $ENV{scrDir};
$WALLPAPER_HAD_SET = $ENV{VYLE_CURRENT_IMAGE};
$VYLE_IMAGE_SOURCE = $ENV{VYLE_IMAGE_SOURCE} //= $ENV{VYLE_CURRENT_IMAGE};

$VYLE_IMAGE_SOURCE_HASH = $ENV{VYLE_IMAGE_SOURCE_HASH};
$VYLE_WALLBASH_COLOR_MODE = $ENV{WALLBASH_MODE};
$WALLBASH_COLOR_ARGUMENT = $ENV{WALLBASH_COLOR_ARGUMENT};
$DCOL_PATH = "$ENV{VYLE_CACHE_HOME}/shell";
$ENABLE_WALLBASH_COLOR_MODE = $ENV{dcolMode};

if
  ( $VYLE_IMAGE_SOURCE_HASH eq "" || ! defined $VYLE_IMAGE_SOURCE_HASH )
{
  use Digest::MD5;

  open(my $fh, "<", "$VYLE_IMAGE_SOURCE") or die $!;
  binmode($fh);

  my $ctx = Digest::MD5 -> new;
  $ctx -> addfile($fh);
  $VYLE_IMAGE_SOURCE_HASH = $ctx -> hexdigest;

  close($fh);
}

if 
  ( $WALLBASH_COLOR_ARGUMENT eq "dark" || $WALLBASH_COLOR_ARGUMENT eq "light" || $WALLBASH_COLOR_ARGUMENT eq "auto" )
{
  if
    ( ! -f "$DCOL_PATH/$ENABLE_WALLBASH_COLOR_MODE/ivy-${VYLE_IMAGE_SOURCE_HASH}.dcol" )
  {
    if
      ( $WALLBASH_COLOR_ARGUMENT eq "auto" )
    {
      system(
        "ionice", "-c", "3",
        "nice", "-n", "19",
        "$LIB_DIR/wallbash.sh", "$VYLE_IMAGE_SOURCE"
      ) == 0 or die "Failed to execute wallbash.sh $VYLE_IMAGE_SOURCE : $!";
    }
    else
    {
      system(
        "ionice", "-c", "3",
        "nice", "-n", "19",
        "$LIB_DIR/wallbash.sh", "$VYLE_IMAGE_SOURCE", "--${WALLBASH_COLOR_ARGUMENT}"
      ) == 0 or die "Failed to execute wallbash.sh $VYLE_IMAGE_SOURCE --${WALLBASH_COLOR_ARGUMENT} : $!";
    }
  }
  $VYLE_DCOL_PATH = "$DCOL_PATH/$ENABLE_WALLBASH_COLOR_MODE/ivy-${VYLE_IMAGE_SOURCE_HASH}.dcol";
}
elsif
  ( $WALLBASH_COLOR_ARGUMENT eq "theme" || $WALLBASH_COLOR_ARGUMENT eq "" || ! defined $WALLBASH_COLOR_ARGUMENT )
{
  if
    ( "$VYLE_WALLBASH_COLOR_MODE" == 3 && "$ENABLE_WALLBASH_COLOR_MODE" eq "theme" )
  {
    if
      ( ! -e "$DCOL_PATH/$ENABLE_WALLBASH_COLOR_MODE/ivy-${VYLE_IMAGE_SOURCE_HASH}.dcol" )
    {
      system(
        "ionice", "-c", "3",
        "nice", "-n", "19",
        "$LIB_DIR/wallbash.sh", "$VYLE_IMAGE_SOURCE"
      ) == 0 or die "Failed to execute wallbash.sh $VYLE_IMAGE_SOURCE : $!";
    }
    $VYLE_DCOL_PATH = "$DCOL_PATH/auto/ivy-${VYLE_IMAGE_SOURCE_HASH}.dcol";
  }
  else
  {
    if
      ( ! -e "$DCOL_PATH/$ENABLE_WALLBASH_COLOR_MODE/ivy-${VYLE_IMAGE_SOURCE_HASH}.dcol" )
    {
      system(
        "ionice", "-c", "3",
        "nice", "-n", "19",
        "$LIB_DIR/wallbash.sh", "$VYLE_IMAGE_SOURCE"
      ) == 0 or die "Failed to execute wallbash.sh $VYLE_IMAGE_SOURCE : $!";
    }
    $VYLE_DCOL_PATH = "$DCOL_PATH/$ENABLE_WALLBASH_COLOR_MODE/ivy-${VYLE_IMAGE_SOURCE_HASH}.dcol";
  }
}

print "export VYLE_DCOL_PATH=$VYLE_DCOL_PATH VYLE_THEME=$ENV{VYLE_THEME} VYLE_CONFIG_HOME=$ENV{VYLE_CONFIG_HOME} \n";
EOF
  )"

  generate_theme "" "$VYLE_CONFIG_HOME/theme.ivy" ""
  generate_theme "_rgba" "$VYLE_CONFIG_HOME/theme-rgba.ivy" "_rgba"
  source "$scrDir/tmq.write.sh"
  source "$scrDir/wallpaper.hybrid.sh"
}

NOTIFICATION_TOGGLE() {
  perl - "$@" <<'EOF'
my $NO_NOTIFICATION;

$NO_NOTIFICATION = $ENV{NO_NOTIFICATION};

if 
  ( $NO_NOTIFICATION == 0 )
{
  system(
    "notify-send", "-e", "-h",
    "string:x-canonical-private-synchronous:theme_engine", 
    "-a", "t1",
    "-t", "1600",
    "-i", "$ENV{VYLE_INSIDER_CACHE}/thumb/$ENV{STRIP_VYLE_IMAGE_SOURCE}.sloc",
    "$ENV{BASENAME_VYLE_IMAGE_SOURCE}"
  ) == 0 or die "Failed to execute system(notify-send) to update user!";
}
EOF
}

VYLE_IMAGE_SOURCE="${VYLE_CONFIG_HOME}/theme/${VYLE_RESERVED_THEME}/wallpapers/$1"
HASH_WALLPAPER
SYNCHRONIZE_CONFIGURATION
NOTIFICATION_TOGGLE
EXECUTE_WALLBASH_UPDATE
