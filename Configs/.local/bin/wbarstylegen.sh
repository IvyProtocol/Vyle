#!/usr/bin/env bash

scrDir=$(dirname "$(realpath "$0")")
source "$scrDir/globalcontrol.sh"

export XDG_CONFIG_HOME WAYBAR_SCALE WAYBAR_FONT WAYBAR_BORDER_RADIUS hypr_border
export -f get_hyprConf

perl -e '

my ($XDG_CONFIG_HOME, $WAYBAR_DIR, $WAYBAR_MODULE_DIR, $CONFIG_CTL, $WAYBAR_MODULE_STYLE, $WAYBAR_STYLE, $SOURCE_FILE, $WAYBAR_FONT, $WAYBAR_SCALE, $WAYBAR_BORDER_RADIUS);
my ($y_monres, $b_height, $w_position, $c_radius, $e_margin, $s_fontpx, $e_paddin, $g_margin, $g_paddin, $b_radius, $w_padact, $font_name, $hypr_border);

$XDG_CONFIG_HOME = $ENV{XDG_CONFIG_HOME};

$WAYBAR_DIR = "${XDG_CONFIG_HOME}/waybar";
$WAYBAR_MODULE_DIR = "${WAYBAR_DIR}/modules";
$CONFIG_CTL = "${WAYBAR_DIR}/config.ctl";

$WAYBAR_MODULE_STYLE = "${WAYBAR_MODULE_DIR}/style.css";
$WAYBAR_STYLE = "${WAYBAR_DIR}/style.css";
$WAYBAR_SCALE = $ENV{WAYBAR_SCALE};
$WAYBAR_FONT = $ENV{WAYBAR_FONT};
$WAYBAR_BORDER_RADIUS = $ENV{WAYBAR_BORDER_RADIUS};

$SOURCE_FILE = "${XDG_CONFIG_HOME}/hypr/themes/theme.conf";

$b_height = $WAYBAR_SCALE;

if 
  ( ! defined $b_height )
{
  $b_height = qx(grep '^1|' "${CONFIG_CTL}" | cut -d '|' -f 2);
  chomp($b_height) if $b_height;
}

if 
  ( ! defined $b_height || $b_height eq "" || $b_height == 0 ) 
{
  $y_monres = qx(hyprctl -j monitors | jq ".[] | select(.focused==true) | (.height / .scale)");
  chomp($y_monres);
  $b_height = int( ( $y_monres * 3 ) / 100 ); 
}

$b_radius = int( ( $b_height * 0.70 ) );
$c_radius = int( ( $b_height * 0.25 ) );
$e_margin = int( ( $b_height * 0.30 ) );
$s_fontpx = int( ( $b_height * 0.34 ) );
$g_paddin = int( ( $b_height * 0.15 ) );
$w_padact = int( ( $b_height * 0.40 ) );
$e_paddin = ( $b_height < 30 ) ? 0 : int( ( $b_height * 0.10 ) );
$g_margin = int( ( $b_height * 0.14 ) );

( $s_fontpx < 10 ) && $s_fontpx = 10;

$ENV{b_radius} = $b_radius;
$ENV{c_radius} = $c_radius;
$ENV{e_margin} = $e_margin;
$ENV{g_margin} = $g_margin;
$ENV{g_paddin} = $g_paddin;
$ENV{w_padact} = $w_padact;
$ENV{e_paddin} = $e_paddin;
$ENV{s_fontpx} = $s_fontpx;

$ENV{t_radius} = $c_radius;
$ENV{w_radius} = $e_margin;
$ENV{w_margin} = $e_paddin;
$ENV{w_paddin} = $e_paddin;

$w_position = qx(grep '^1|' "$CONFIG_CTL" | cut -d '|' -f 3);
chomp($w_position);

@ENV{"x1rb_radius", "x2lc_radius", "x3lc_radius", "x3lb_radius", "x1rc_radius", "x4rc_radius"} = ( (0) x 6);
@ENV{"x3rb_radius", "x1lb_radius"} = ( ($b_radius) x 2);
@ENV{"x2rc_radius", "x3rc_radius", "x1lc_radius", "x4lc_radius"} = ( ($c_radius) x 4);

if 
  ( $w_position eq "top" || $w_position eq "bottom" ) 
{
  @ENV{"x1g_margin", "x3g_margin"} = ( ($g_margin) x 2);
  @ENV{"x2g_margin", "x4g_margin", "x4rb_radius", "x2lb_radius"} = ( (0) x 4);
  @ENV{"x2rb_radius","x4lb_radius"} = ( ($b_radius) x 2);
  @ENV{"x1", "x2", "x3", "x4"} = ("top", "bottom", "left", "right");
} 
elsif 
  ( $w_position eq "left" || $w_position eq "right" )
{
  @ENV{"x2g_margin", "x4g_margin"} = ( ($g_margin) x 2);
  @ENV{"x1g_margin", "x3g_margin", "x2rb_radius", "x4lb_radius"} = ( (0) x 4);
  @ENV{"x4rb_radius", "x2lb_radius"} = ( ($b_radius) x 2);
  @ENV{"x1", "x2", "x3", "x4"} = ("left", "right", "top", "bottom");
}

$font_name = $WAYBAR_FONT // qx(bash -c "get_hyprConf WAYBAR_FONT");
chomp($font_name);

$ENV{font_name} = (! defined $font_name || $font_name eq "" ) ? "JetBrainsMono Nerd Font" : $font_name;

my @modules;
foreach my $file (glob("${WAYBAR_MODULE_DIR}/*.jsonc")) {
  next if $file =~ /footer\.jsonc$/;
  if 
    (open my $fh, "<", $file) 
  {
    while 
      (my $line = <$fh>) 
    {
      if 
        ($line =~ /"(.+)":\s*\{/) 
      {
        my @parts = split("/", $1);
        my $m = $parts[-1];
        push @modules, ($parts[0] eq "custom" ? "#custom-$m" : "#$m");
        last;
      }
    }
    close $fh;
  }
}

$ENV{modules_ls} = join(", ", @modules);

system("envsubst < \"$WAYBAR_MODULE_STYLE\" > \"$WAYBAR_STYLE\"");
$hypr_border = $ENV{hypr_border} || $WAYBAR_BORDER_RADIUS;

if 
  ( $hypr_border == 0 || ! defined $hypr_border ) 
{
  {
    local $^I   = "";

    while (<>) {
        s/border-radius:\s*[^;]+;/border-radius: 0px;/;
        print($WAYBAR_STYLE);
    }
  }
}
'
