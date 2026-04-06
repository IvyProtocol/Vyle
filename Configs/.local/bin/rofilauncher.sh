#!/usr/bin/env bash

# Dear USER: This script was originally wrote in Bash for simplicity. 
# However Perl has become a serious attraction to my eyes and it is generally more faster and efficient.
# Hence, I have semi-migrated its interface to Perl while keeping some bash logics.

# We will source our globalcontrol.sh
scrDir="$(dirname "$(realpath "$0")")"
source "${scrDir}/globalcontrol.sh"

STORE_HELP_FUNCTION="$(
cat <<EOF
Usage: ${0##*/} -[action]

Actions:
    -d      drun mode
    -w      window mode
    -f      filebrowser mode

Examples:
    ${0##*/} -d // drun mode.
    ${0##*/} -w // window mode
    ${0##*/} -f // filebrowser mode

EOF
)"

# Export necessary variables defined from globalcontrol.sh in our environment.
# In preparation of Perl's interface deployment.
export XDG_CONFIG_HOME
export rofiLauncherStyle
export hypr_border
export hypr_width
export rofiLauncherFont
export rofiLauncherScale
export STORE_HELP_FUNCTION

perl - "$@" << 'EOF'
# Header Includes: basename(), find()

# User can dispatch "help" argument to be guided.
# User can trigger any argument except for those that are invalid.
my ($rofiMode) = $ARGV[0];

if 
    (( $rofiMode eq "-d" || $rofiMode eq "--drun" ))
{
    $rofiMode = "drun";
}
elsif
    (( $rofiMode eq "-w" || $rofiMode eq "--window" ))
{
    $rofiMode = "window";
}
elsif 
    (( $rofiMode eq "-f" || $rofiMode eq "--filebrowser" ))
{
    $rofiMode = "filebrowser";
}
elsif 
    (( $rofiMode eq "-h" || $rofiMode eq "--help"))
{
    print("$ENV{STORE_HELP_FUNCTION}\n");
    exit 0;
}
else
{
    $rofiMode = "drun";
}

use File::Find qw(find);
use File::Basename qw(basename);
# We will reassign our environment variable into Perl.
# The above exported variables will be picked within $ENV to be accessed.
# NOTE: Bash and Perl are seperate scripting language that are related to each other.

my ($XDG_CONFIG_HOME);
my ($rofiLauncherFont, $rofiLauncherStyle, $rofiLauncherScale, $hypr_border, $hypr_width, $rofiStyleDir,
    $rofiStyleLaunch, $wind_border, $elem_border, $r_override, $r_scale, $is_override, $i_override,
    $base_rofiStyleLaunch);
$XDG_CONFIG_HOME = $ENV{XDG_CONFIG_HOME};
$rofiLauncherStyle = $ENV{rofiLauncherStyle};
$rofiLauncherFont = $ENV{rofiLauncherFont};
$rofiLauncherScale = $ENV{rofiLauncherScale};
$hypr_border = $ENV{hypr_border};
$hypr_width = $ENV{hypr_width};

# Noteworthy is that you can assign variables with my, our, $ENV or empty.
# Assign related path to rofi to access the styles.

$rofiStyleDir = "${XDG_CONFIG_HOME}/rofi/styles";
$rofiStyleLaunch = "${rofiStyleDir}/style-${rofiLauncherStyle}.rasi";

# If value for rofiStyleLaunch does not exist in the filepath of rofiStyleDir.
# Enlist the first order from rofiStyleDir and append to rofiStyleLaunch.
# Validation of rofiStyleLaunch's' existant.

if ( ! -f $rofiStyleLaunch ) {
    my @matches;

    # Find style-*.rasi related filename from $rofiStyleDir.
    # Does not match style-*.rasi.bak or any other extension.

    find(sub {
        push @matches, $File::Find::name if -f $_ && $_ =~ /^style-.*\.rasi$/;
    }, $rofiStyleDir);

    # Sort the matches alphabetically and pick the first order [0].

    @matches = sort {
        ($a =~ /style-(\d+)/)[0] <=> ($b =~ /style-(\d+)/)[0]
    } @matches;
    $rofiStyleLaunch = shift @matches;
}

# Print Deployment to the User to ensure checks are secured.

print(" :: Rofi-Launch - Preparing to read ${rofiStyleLaunch} - Deploying... \n");

# Define Variables: Calculate the variables needed for Rofi.
# ELEMENT_BORDER, BORDER_RADIUS, FONT, FONT_SCALE

$wind_border = int( $hypr_border * 3 );
$elem_border = ($hypr_border == 0) ? 10 : int($hypr_border * 2);
$r_override = "window {border: ${hypr_width}px; border-radius: ${wind_border}px;} element {border-radius: ${elem_border}px;}";
$r_scale = "configuration {font: \"${rofiLauncherFont} ${rofiLauncherScale}\";}";

# Consume $is_override to retrieve icon-theme
chomp($is_override = qx(gsettings get org.gnome.desktop.interface icon-theme));

# Using Perl's' native sed to remove extra quotation.
$is_override =~ s/''//g;

# Appending $is_override to $i_override.
$i_override = "configuration {icon-theme: \"${is_override}\";}";

$base_rofiStyleLaunch = basename($rofiStyleLaunch);

print(" :: Rofi-Launch :: Profile - $base_rofiStyleLaunch :: Element-Border - ${elem_border} :: Border-Radius - ${wind_border} :: Icon-Theme - ${is_override} \n");

# Execute rofi after necessary variables are appended successfully. 
system(
    "rofi", "-show", "${rofiMode}",
    "-theme-str", "${r_scale}",
    "-theme-str", "${r_override}",
    "-theme-str", "${i_override}",
    "-config", "${rofiStyleLaunch}"
    );
EOF
