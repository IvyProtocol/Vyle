#!/usr/bin/env bash
scrDir="$(dirname "$(realpath "$0")")"
source "${scrDir}/globalcontrol.sh"

brightness_control() {
  export BRIGHTNESS_FETCHICON
  export steps="$1"
  perl -e '
my $BRIGHTNESS_FETCHICON = $ENV{BRIGHTNESS_FETCHICON};
my $steps = $ENV{steps};

sub get_brightness {
  chomp(my $brightness = qx(brightnessctl -m | cut -d, -f4 | tr -d '%'));
  return $brightness;
}

sub send_notify {
  my ($brightness) = @_;
  my $angle = int(($brightness + 2.5) / 5 ) * 5;
  my $ico = "${BRIGHTNESS_FETCHICON}/vol-${angle}.svg";
  my $step = int($brightness / 15);
  chomp(my $bar = qx(seq -s "." $step | sed "s/[0-9]//g"));

  chomp(my $monitor = qx(
    hyprctl -j monitors | jq -r ".[] | select(.focused==true) | .description"
  ));

  system(
    "notify-send",
    "-a", "t2",
    "-r", "91190",
    "-t", "800",
    "-i", $ico,
    "${brightness}${bar}",
    "${monitor}"
  );
}

sub change_brightness {
  my ($delta) = @_;
  my $current = get_brightness();
  my $new = int($current + $delta);

  $new = 5 if $new < 5;
  $new = 100 if $new > 100;

  system("brightnessctl", "set", "${new}%");
  send_notify($new);
}

($steps eq "--get") ? print get_brightness() : change_brightness($steps);
'
}

case "$1" in
"--inc")
  brightness_control "${2:-$BRIGHTNESS_STEPS}"
  ;;
"--dec")
  brightness_control "-${2:-$BRIGHTNESS_STEPS}"
  ;;
"--get" | *)
  brightness_control "--get"
  ;;
esac
