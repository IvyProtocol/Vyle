#!/usr/bin/env bash

# Dear USER: This script was originally wrote in Bash for simplicity. 
# However Perl has become a serious attraction to my eyes and it is generally more faster and efficient.
# Hence, I have semi-migrated its interface to Perl while keeping some bash logics.

# We will source our globalcontrol.sh
scrDir="$(dirname "$(realpath "$0")")"
source "${scrDir}/globalcontrol.sh"

# Case Statement:
case "${1}" in
    -d|--drun)
        rofiMode="drun"
        ;;
    -w|--window)
        rofiMode="window" 
        ;;
    -f|--filebrowser)
        rofiMode="filebrowser"
        ;;
    -h|--help)
        rofiMode="help"
        ;;
    *)
        rofiMode="drun"
        ;;
esac

# Export necessary variables defined from globalcontrol.sh in our environment.
# In preparation of Perl's interface deployment.
export XDG_CONFIG_HOME
export rofiLauncherStyle
export hypr_border
export hypr_width
export rofiLauncherFont
export rofiLauncherScale
export rofiMode
export scrName="$0"

perl -e '
# Header Includes: basename(), find()

use File::Basename qw(basename);
use File::Find;

# Help Function.
sub help_function {
    my $script_name = basename($ENV{scrName});
    print("${script_name} [action]\n");
    print("-d : drun mode\n");
    print("-w : window mode\n");
    print("-f : filebrowser mode\n");
    exit(0);
}

# We will reassign our environment variable into Perl.
# The above exported variables will be picked within $ENV to be accessed.
# NOTE: Bash and Perl are seperate scripting language that are related to each other.

my $XDG_CONFIG_HOME = $ENV{XDG_CONFIG_HOME};
my $rofiLauncherStyle = $ENV{rofiLauncherStyle};
my $rofiLauncherFont = $ENV{rofiLauncherFont};
my $rofiLauncherScale = $ENV{rofiLauncherScale};
my $hypr_border = $ENV{hypr_border};
my $hypr_width = $ENV{hypr_width};
my $rofiMode = $ENV{rofiMode};

# User can dispatch "help" argument to be guided.
( $rofiMode eq "help" ) && help_function();

# Noteworthy is that you can assign variables with my, our, $ENV or empty.
# It feels like bash so much.... Just some semi-color and that is all.

# Assign related path to rofi to access the styles.

my $rofiStyleDir = "${XDG_CONFIG_HOME}/rofi/styles";
my $rofiStyleLaunch = "${rofiStyleDir}/style-${rofiLauncherStyle}.rasi";

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

my $wind_border = int( $hypr_border * 3 );
my $elem_border = ($hypr_border == 0) ? 10 : int($hypr_border * 2);
my $r_override = "window {border: ${hypr_width}px; border-radius: ${wind_border}px;} element {border-radius: ${elem_border}px;}";
my $r_scale = "configuration {font: \"${rofiLauncherFont} ${rofiLauncherScale}\";}";

# Consume $is_override to retrieve icon-theme
chomp(my $is_override = qx(gsettings get org.gnome.desktop.interface icon-theme));

# Using Perl's' native sed to remove extra quotation.
$is_override =~ s/''//g;

# Appending $is_override to $i_override.
my $i_override = "configuration {icon-theme: \"${is_override}\";}";

my $base_rofiStyleLaunch = basename($rofiStyleLaunch);

print(" :: Rofi-Launch :: Profile - $base_rofiStyleLaunch :: Element-Border - ${elem_border} :: Border-Radius - ${wind_border} :: Icon-Theme - ${is_override} \n");

# Execute rofi after necessary variables are appended successfully. 
system(
    "rofi", "-show", "${rofiMode}",
    "-theme-str", "${r_scale}",
    "-theme-str", "${r_override}",
    "-theme-str", "${i_override}",
    "-config", "${rofiStyleLaunch}"
    );
'
