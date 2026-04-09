#!/usr/bin/env bash

scrDir="$(dirname "$(realpath "$0")")"
source "$scrDir/globalcontrol.sh"

export rasiDir
export scrDir
export rofiLauncherStyle
export rofiStyleScale 
export rofiColCount
export rofiAssetDir
export mon_scale 
export mon_res

export -f tomlq 
export -f setConf
export -f notify

perl -E '
use File::Basename qw(basename);
use File::Find;

my $VYLE_CONFIG_HOME = $ENV{VYLE_CONFIG_HOME};
my $BIN_DIR = $ENV{scrDir};
my $rasiPath = $ENV{rasiDir};
my $rasiDir = "$rasiPath/selector.rasi";
my $rofiLauncherStyle = $ENV{rofiLauncherStyle};
my $rofiStyleScale = $ENV{rofiStyleScale};
my $rofiColCount = $ENV{rofiColCount};
my $rofiAssetDir = $ENV{rofiAssetDir};
my $mon_scale = $ENV{mon_scale};
my $mon_res = $ENV{mon_res};

my $elem_border = int(2 * 5);
my $icon_border = int($elem_border - 5);
my $mon_x_res = int(( $mon_res * 100) / $mon_scale);
my $elm_width = int(( 20 + 12 + 16) * $rofiStyleScale);
my $max_avail = int( $mon_x_res - (4 * $rofiStyleScale));

if ( ! $rofiColCount ) {
  $rofiColCount = int( $max_avail / $elm_width );
  $rofiColCount = 5 if $rofiColCount > 5;
}

my $r_override = "window{width:100%;} \
  listview{columns:${rofiColCount};} \
  element{orientation:vertical; border-radius:${elem_border}px;} \
  element-icon{border-radius:${icon_border}px; size:25em;} \
  element-text{enabled:false;}";

my @style_files;
find(
  sub {
    return unless -f $File::Find::name && $File::Find::name =~ /\.png$/;
    push @style_files, $File::Find::name;
  },
  $rofiAssetDir
);

my @style_names = map { basename($_) } @style_files;

@style_names = sort {
  my ($a_num) = $a =~ /(\d+)/;
  my ($b_num) = $b =~ /(\d+)/;
  ($a_num // 0) <=> ($b_num // 0) || $a cmp $b;
} @style_names;

my $rofi_list=""; 
for my $style_name (@style_names) { 
  $rofi_list .= "${style_name}\\x00icon\\x1f${rofiAssetDir}/${style_name}\\n"; 
}

print("$rofi_list");
my $RofiSel = qx(printf "%b" "$rofi_list" | rofi -dmenu -markup-rows -theme-str "$r_override" -theme "$rasiDir" -select "style-${rofiLauncherStyle}.png");
chomp($RofiSel);

if ( defined $RofiSel && $RofiSel ne "" ) {
  (my $UpdRofiSel = $RofiSel) =~ s/[A-Za-z.\-]//g;

  my $bash_cmd;
  $bash_cmd = qq(bash -c "tomlq -i "${VYLE_CONFIG_HOME}/vyle.toml" "Rofi.Launch" "Style" "${UpdRofiSel}"");
  system($bash_cmd) == 0 or die "Failed to apply config";
}
'

