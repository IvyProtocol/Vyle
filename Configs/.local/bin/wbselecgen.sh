#!/usr/bin/env bash

scrDir=$(dirname "$(realpath "$0")")
source "$scrDir/globalcontrol.sh"

export BASH_SRC="${BASH_SOURCE[0]##*/}"
export XDG_RUNTIME_DIR dunstDir wallDir WallAddCustomPath 
export VYLE_CACHE_HOME wallSet VYLE_CONFIG_HOME VYLE_RESERVED_THEME rofiThemeStyle VYLE_STATE_HOME rasiDir 
export dcolMode scrDir enableWallIde VYLE_THEME wallBackend wallTransitionStep wallTransDuration 
export wallFramerate rofiWallpaperScale rofiWallpaperColumn rofiWallpaperFont hypr_border mon_scale mon_res
export -f generate_theme setConf

perl - "$@" <<'EOF'
use File::Path qw(make_path);
use File::Basename qw(basename dirname);
use File::Find qw(find);
use Digest::MD5 qw(md5_hex);
use Getopt::Long;

my ($BASH_SRC, $LOCK_FILE, $XDG_RUNTIME_DIR, $DUNST_DIR, $WALLPAPER_PATH, $VYLE_CACHE_HOME, $DCOL_PATH,
  $VYLE_INSIDER_CACHE, $VYLE_IMAGE_SOURCE, $WALLBASH_COLOR_ARGUMENT, $WALLPAPER_SET_FLAGS, $NO_NOTIFICATION, $WALLPAPER_HAD_SET,
  $STRIP_VYLE_IMAGE_SOURCE, $VYLE_CONFIG_HOME, $VYLE_RESERVED_THEME, $PID, $BASENAME_VYLE_IMAGE_SOURCE, $ROFI_THEME_STYLE,
  $THEME_FILE_EXTENSION, $VYLE_IMAGE_SOURCE_HASH, $ENABLE_WALLBASH_COLOR_MODE, $VYLE_DCOL_PATH, $VYLE_WALLBASH_COLOR_MODE, $ROFI_WALLPAPER_SCALE
  $ROFI_WALLPAPER_COLUMN, $ROFI_WALLPAPER_FONT
  );
my (@WALLPAPER_CUSTOM_PATH);

$BASH_SRC = $ENV{BASH_SRC};
$XDG_RUNTIME_DIR = $ENV{XDG_RUNTIME_DIR};
$LOCK_FILE = "${XDG_RUNTIME_DIR}/${BASH_SRC}.lock";
$DUNST_DIR = $ENV{dunstDir};
$WALLPAPER_HAD_SET = $ENV{wallSet};

if 
  ( -e $LOCK_FILE )
{
  print("Error: Another instance of ${BASH_SRC} is running.\n");
  print("If you are sure that no other instance is running. Remove the lock file: \n");
  print("   $LOCK_FILE");
  
  system(
    "notify-send", "-a", "t2",
    "-r", "91190",
    "-t", "800",
    "-i", "${DUNST_DIR}/icons/hyprdots.svg",
    "Vyle", "Another instance of $BASH_SRC is running."
  );
  exit 0;
}

open(my $fh, ">", $LOCK_FILE);
print;
close $fh;

END {
  return unless defined $LOCK_FILE;
  unlink $LOCK_FILE;
}
$LIB_DIR = $ENV{scrDir};

$WALLPAPER_PATH = $ENV{wallDir};
@WALLPAPER_CUSTOM_PATH = $ENV{WallAddCustomPath} ? split /\s+/, $ENV{WallAddCustomPath} : ();

$VYLE_CONFIG_HOME = $ENV{VYLE_CONFIG_HOME};
$VYLE_RESERVED_THEME = $ENV{VYLE_RESERVED_THEME};
$VYLE_CACHE_HOME = $ENV{VYLE_CACHE_HOME};
$VYLE_STATE_HOME = $ENV{VYLE_STATE_HOME};
$VYLE_RESERVED_THEME = $ENV{VYLE_RESERVED_THEME};
$VYLE_THEME = $ENV{VYLE_THEME};

$ROFI_THEME_STYLE = $ENV{rofiThemeStyle};
$ROFI_SHARED_DIRECTORY = $ENV{rasiDir};
$ROFI_WALLPAPER_SCALE = $ENV{rofiWallpaperScale};
$ROFI_WALLPAPER_COLUMN = $ENV{rofiWallpaperColumn};
$ROFI_WALLPAPER_FONT = $ENV{rofiWallpaperFont};

$ENABLE_WALLBASH_COLOR_MODE = $ENV{dcolMode};
$DCOL_PATH = "$VYLE_CACHE_HOME/shell";
$VYLE_INSIDER_CACHE = "${VYLE_CACHE_HOME}/cache";

( -d "$VYLE_INSIDER_CACHE" ) || make_path("$VYLE_INSIDER_CACHE") or die "ERR: Failed to create $VYLE_INSIDER_CACHE directory.";
( -d "$VYLE_INSIDER_CACHE/blur" ) || make_path("$VYLE_INSIDER_CACHE/blur") or die "ERR: Failed to create $VYLE_INSIDER_CACHE/blur directory!";
( -d "$VYLE_INSIDER_CACHE/cols" ) || make_path("$VYLE_INSIDER_CACHE/cols") or die "ERR: Failed to create $VYLE_INSIDER_CACHE/cols directory!";
( -d "$VYLE_INSIDER_CACHE/thumb" ) || make_path("$VYLE_INSIDER_CACHE/thumb") or die "ERR: Failed to create $VYLE_INSIDER_CACHE/thumb directory!";

sub SWITCH_WALLPAPER {
  GetOptions(
    "i=s" => \$VYLE_IMAGE_SOURCE,
    "s=s" => \$WALLBASH_COLOR_ARGUMENT,
    "w=s" => \$WALLPAPER_SET_FLAGS,
    "n=s" => \$NO_NOTIFICATION,
  );
  
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
        "Vyle", "Invalid Wallpaper?",
        "-t", "900"
      ) == 0 or die "Failed to execute system(notify-send) to user.";
      exit(1);
    }
  }

  $STRIP_VYLE_IMAGE_SOURCE = basename($VYLE_IMAGE_SOURCE);
  $BASENAME_VYLE_IMAGE_SOURCE = $STRIP_VYLE_IMAGE_SOURCE;
  $STRIP_VYLE_IMAGE_SOURCE =~ s/\.[^.]+$//;

  open my $fh, ">", "$VYLE_CONFIG_HOME/theme/$VYLE_RESERVED_THEME/wallpapers/.wallbash-main" 
  or die "Failed to write $VYLE_CONFIG_HOME/theme/$VYLE_RESERVED_THEME/wallpapers/.wallbash.main: $!";

  print $fh "$VYLE_IMAGE_SOURCE";
  close $fh;

  print(" :: Theme Control - $BASH_SRC - Wallpaper Control - Applying $VYLE_IMAGE_SOURCE\n");
  if 
    ( $NO_NOTIFICATION == 0 )
  {
    system(
      "notify-send", "-e", "-h", 
      "string:x-canonical-private-synchronous:theme_engine", 
      "-a", "t1", 
      "-t", "1600", 
      "-i", "$VYLE_INSIDER_CACHE/thumb/${STRIP_VYLE_IMAGE_SOURCE}.sloc",
      "$BASENAME_VYLE_IMAGE_SOURCE"
    ) == 0 or die "Failed to execute system(notify-send) to update user!";
  }

  if 
    ( $ROFI_THEME_STYLE == 2 )
  {
    $THEME_FILE_EXTENSION = "quad";
  } 
  elsif
    ( $ROFI_THEME_STYLE == 1 || ! defined $ROFI_THEME_STYLE )
  {
    $THEME_FILE_EXTENSION = "thumb";
  }

  system("bash", "-c", "setConf 'wallSet' '${VYLE_CONFIG_HOME}/theme/${VYLE_RESERVED_THEME}/wallpapers/$BASENAME_VYLE_IMAGE_SOURCE' '${VYLE_STATE_HOME}/staterc'");

  symlink("$VYLE_INSIDER_CACHE/cols/${STRIP_VYLE_IMAGE_SOURCE}.cols", "$ROFI_SHARED_DIRECTORY/wall.cols");
  symlink("$VYLE_INSIDER_CACHE/bpex/${STRIP_VYLE_IMAGE_SOURCE}.bpex", "$ROFI_SHARED_DIRECTORY/wall.bpex");
  symlink("$VYLE_INSIDER_CACHE/thumb/${STRIP_VYLE_IMAGE_SOURCE}.sloc", "$ROFI_SHARED_DIRECTORY/wall.thmb");

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
    ( $WALLPAPER_SET_FLAGS eq "--swww-n" || $WALLPAPER_SET_FLAGS eq "" || ! defined $WALLPAPER_SET_FLAGS )
  {
    $WALLPAPER_SET_FLAGS = "-n";
  }

  if 
    (open(my $fh, "<", $VYLE_IMAGE_SOURCE)) 
  {
    binmode($fh);
    # this should be better. since it uses the libs function...
    $VYLE_IMAGE_SOURCE_HASH = Digest::MD5->new->addfile($fh)->hexdigest;
    close($fh);
  }

  $VYLE_WALLBASH_COLOR_MODE = $ENV{enableWallIde};
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
        ( ! -e "$DCOL_PATH/$ENABLE_WALLBASH_COLOR_MODE/ivy-${VYLE_IMAGE_SOURCE_HASH}.dcol")
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

  $ENV{VYLE_DCOL_PATH} = $VYLE_DCOL_PATH;
  $ENV{VYLE_THEME} = $VYLE_THEME;
  $ENV{VYLE_CONFIG_HOME} = $VYLE_CONFIG_HOME;
  $ENV{VYLE_IMAGE_SOURCE} = $VYLE_IMAGE_SOURCE;
  $ENV{WALLPAPER_SET_FLAGS} = $WALLPAPER_SET_FLAGS;
  system("bash", "-c", "
  generate_theme '' '$VYLE_CONFIG_HOME/theme.ivy';
  generate_theme '_rgba' '$VYLE_CONFIG_HOME/theme-rgba.ivy' '_rgba';
  source '$LIB_DIR/tmq.write.sh';
  source '$LIB_DIR/wallpaper.hybrid.sh';");
}

sub OPEN_ROFI_WALLPAPER_SELECTOR {
  if
    ( ! defined $ROFI_WALLPAPER_SCALE || $ROFI_WALLPAPER_SCALE == 0 )
  {
    $ROFI_WALLPAPER_SCALE = 10;
  }

  my ($r_scale, $elem_border, $mon_x_res, $elm_width, $max_avail, $r_override);

  $r_scale = "configuration {font: \"${ROFI_WALLPAPER_FONT} ${ROFI_WALLPAPER_SCALE}\";}";
  $elem_border = int( $ENV{hypr_border} * 3 );

  $mon_x_res = int( ( $ENV{mon_res} * 100 ) / $ENV{mon_scale} );
  $elm_width = int( ( 28 + 8 + 5 ) * $ROFI_WALLPAPER_SCALE );
  $max_avail = int( $mon_x_res - ( 4 * $ROFI_WALLPAPER_SCALE ) );
  if 
    ( $ROFI_WALLPAPER_COLUMN == 0 || ! defined $ROFI_WALLPAPER_COLUMN )
  {
    $ROFI_WALLPAPER_COLUMN = ( $max_avail / $elm_width );
  }

  $r_override = "window{width:100%;} listview{columns:${ROFI_WALLPAPER_COLUMN}; spacing:5em;} element{border-radius:${elem_border}px; orientation:vertical;} element-icon{size:28em;border-radius:0em; } element-text{padding:1em;}"
  my ($found, $res)
  $found = 0;
  my (@files, @a_parts, @b_parts);

  find(
    {
      wanted => sub
      {
        return unless -f $_;
        return unless /\.(png|jpg|webp|gif|jpeg);
        $found = 1

        push @files, $File::Find::name;
      },
      no_chdir => 1,
    },
    
  );

  if 
    ( ! $found )
  {
    print("$BASH_SRC : No files have been found.\n");
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

  
  my ($indx, $name, $thumb, $rofi_list);
  for $indx ( 0 .. @files ) {
    $name = basename($indx);
    $name =~ s/\.[^.]+$//; 
    $thumb = "$VYLE_INSIDER_CACHE/thumb/${name}.sloc";
    if
      ( ! -f $thumb )
    {
      system("$LIB_DIR/swwwallcache.sh", "-f", "$indx");
    }
 
    $rofi_list = "%s\\x00icon\\x1f%s\\n";
  }
  
  my $WALLPAPER_CHOICE = qx(printf "%b" "$rofi_list" | rofi -dmenu -i -p "Wallpaper" -theme-str "$")

}
EOF
