#!/usr/bin/env bash

# Dear USER: This script was originally wrote in Bash for simplicity. 
# However Perl has become a serious attraction to my eyes and it is generally more faster and efficient.
# Hence, I have semi-migrated its interface to Perl while keeping some bash logics.

# We will source our globalcontrol.sh 
scrDir="$(dirname "$(realpath "$0")")"
source "${scrDir}/globalcontrol.sh"

# Our package validator with notify-send as notify function, ensure if it exist. Or else return error code.
if ! env_pkg -- -Q "wlogout" >/dev/null 2>&1; then
    notify -m 1 -p "Is wlogout installed? Exit-Code 1" -u critical -t 900 -a "t2" -s "${dunstDir}/icons/hyprdots.svg"
    exit 1
else
    pgrep -x "wlogout" 2>/dev/null && [[ $? -lt 1 ]] && pkill -x "wlogout" && exit 0
fi

# We will export the necessary vars needed in our environment. 
# In prepare for the preparation of Perl interface.
export wlogoutStyle="${1:-${wlogoutStyle}}"
export mon_scale
export dcolMode
export mon_res
export enableWallIde
export hypr_border
 
perl -e '
use File::Temp qw(tempfile);

# We will reassign our environment variable into Perl.
# If you are dummy, we are only doing this because perl and bash are seperate scripting language.
# With $ENV, we can pick up our exported variable from above.

my $XDG_CONFIG_HOME = $ENV{XDG_CONFIG_HOME};
my $VYLE_CONFIG_HOME = $ENV{VYLE_CONFIG_HOME};
my $VYLE_RESERVED_THEME = $ENV{VYLE_RESERVED_THEME};
my $wlogoutStyle = $ENV{wlogoutStyle};
my $mon_scale = $ENV{mon_scale};
my $dcolMode = $ENV{dcolMode};
my $mon_res = $ENV{mon_res};
my $hypr_border = $ENV{hypr_border};
my $enableWallIde = $ENV{enableWallIde};

# Noteworthy is that you can assign variables with my, our, $ENV or empty. 
# It feels like bash so much. Just some semi-colon, that is all.
#
my $wLayout = "${XDG_CONFIG_HOME}/wlogout/layout_${wlogoutStyle}";
my $wlTmplt = "${XDG_CONFIG_HOME}/wlogout/style_${wlogoutStyle}.css";

# Checks to ensure our wLayout or wlTmplt actually exists. 
# Although, mind you. :) It is fragile.

if (!-f $wLayout || !-f $wlTmplt) {
  $wlogoutStyle = 1;
  $wLayout = "${XDG_CONFIG_HOME}/wlogout/layout_${wlogoutStyle}";
  $wlTmplt = "${XDG_CONFIG_HOME}/wlogout/style_${wlogoutStyle}.css";
}

# Consume $y_mon to retrieve hyprctl value.
chomp(my $y_mon = qx(hyprctl -j monitors | jq ".[] | .height"));

# Normal thing: If you have been following the hash quotes. then you know what is happening here.
my $wlColms;
if ($wlogoutStyle == 1 ) {
  $wlColms = 6;
  $ENV{mgn} = int(( $y_mon * 28 ) / $mon_scale);
  $ENV{hvr} = int(( $y_mon * 23 ) / $mon_scale);
}
elsif ($wlogoutStyle == 2 ) {
  $wlColms = 2;
  $ENV{x_mgn} = int(( $mon_res * 35 ) / $mon_scale);
  $ENV{y_mgn} = int(( $y_mon * 25 ) / $mon_scale);
  $ENV{x_hvr} = int(( $mon_res * 32 ) / $mon_scale);
  $ENV{y_hvr} = int(( $y_mon * 20 ) / $mon_scale);
}

# Validate if $enableWallIde is equal to 3 = theme
# Retrieves theme settings from the selected theme folder.
if (( $enableWallIde == 3 )) {
  chomp(my $colorScheme = qx(grep "^[[:space:]]*\$COLOR[-_]SCHEME\s*=" "${VYLE_CONFIG_HOME}/theme/${VYLE_RESERVED_THEME}/hypr.theme" \
    || gsettings get org.gnome.desktop.interface color-scheme));
  
  # Using Perl native sed to remove prefer and any quotation.
  $colorScheme =~ "s/.*-//g; s/''//g";

  # What sorcery is this? Eh.. It is just that if colorScheme returns empty, then assign dark.
  $colorScheme ||= "dark";
  
  # What the hell is this? Just an if statement. if ? true : else
  $dcolMode = ($colorScheme eq "light") ? "light" : "dark";
}

$ENV{BtnCol} = ($dcolMode eq "light") ? "black" : "white";
$ENV{active_rad} = int($hypr_border * 5);
$ENV{button_rad} = int($hypr_border * 8);
$ENV{fntSize} = int(( $y_mon * 2 ) / 100);

print(" :: Deploying :: Profile - ${wlogoutStyle} :: DcolMode - ${dcolMode} :: Theme - ${VYLE_RESERVED_THEME} :: Font-Size - $ENV{fntSize}\n");

# Environment substitute our exported global variables to wlTmplt locally.
chomp(my $wlStyle = qx(envsubst < $wlTmplt));

my ($fh, $filename) = tempfile();
print $fh $wlStyle;
close $fh;

# Execute wlogout after environment substitution.
system("wlogout -b $wlColms -c 0 -r 0 -m 0 --layout $wLayout --css $filename --protocol layer-shell");
'
