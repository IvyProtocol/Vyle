#!/usr/bin/env bash

export scrDir="$(dirname "$(realpath "$0")")"

[[ -e "${scrDir}/globalcontrol.sh" ]] && source "${scrDir}/globalcontrol.sh" || exit 1

export dcolDir="${VYLE_CACHE_HOME}/shell"
thmbDir="${VYLE_CACHE_HOME}/thmb"
blurDir="${VYLE_CACHE_HOME}/blur"
colsDir="${VYLE_CACHE_HOME}/cols"
quadDir="${VYLE_CACHE_HOME}/quad"
scrRun="${scrDir}/wallbash.sh"

[[ -d "${thmbDir}" ]] || mkdir -p "${thmbDir}"
[[ -d "${blurDir}" ]] || mkdir -p "${blurDir}"
[[ -d "${colsDir}" ]] || mkdir -p "${colsDir}"
[[ -d "${quadDir}" ]] || mkdir -p "${quadDir}"

fl_wallpaper() {
  OPTIND=1
  local fill=0 fillPath extract_wall w_int="" c_rasi

  while getopts ":f:t:r" prefix; do
    case "${prefix}" in
    f) fill="${OPTARG}" ;;
    t) w_int="${OPTARG}" ;;
    r) w_int="${VYLE_CURRENT_IMAGE}" || return 1 ;;
    esac
  done
  shift $((OPTIND - 1))

  [[ -n "${w_int}" ]] || return 1
  fillPath="${w_int#\"}"
  fillPath="${fillPath%\"}"
  extract_wall="${fillPath##*/}"
  w_int="${extract_wall}"

  [[ "$fill" -eq 1 ]] && w_int="${w_int%.*}"
  echo "$w_int"
}

# cols = For ${rasiDir}/current-wallpaper.png and other usage
# bpex = For blur
# thmb = For thumbnail of rofiselector : thmb
fn_wallcache() {
  local h_sum="${1:-}"
  local w_sum="${2:-}"
  local sr_call="$(fl_wallpaper -t "${w_sum}" -f 1)"

  [[ ! -f "${colsDir}/${sr_call}.cols" ]] && magick "${w_sum}"[0] -strip -resize 1000 -gravity center -extent 1000 -quality 90 "${colsDir}/${sr_call}.cols"
  [[ ! -f "${blurDir}/${sr_call}.bpex" ]] && magick "${w_sum}"[0] -strip -scale 10% -blur 0x3 -resize 100% "${blurDir}/${sr_call}.bpex"
  [[ ! -f "${thmbDir}/${sr_call}.thmb" ]] && magick "${w_sum}"[0] -strip -thumbnail 500x500^ -gravity center -extent 500x500 "${thmbDir}/${sr_call}.thmb"
  [[ ! -f "${quadDir}/${sr_call}.quad" ]] && magick "${thmbDir}/${sr_call}.thmb" \( -size 500x500 xc:white -fill "rgba(0,0,0,7)" -draw "polygon 400,500 500,500 500,0 450,0" -fill black -draw "polygon 500,500 500,0 450,500" \) -alpha Off -compose CopyOpacity -composite png:"${quadDir}/${sr_call}.quad"
  [[ ! -e "${dcolDir}/auto/${h_sum}.dcol" ]] && "${scrRun}" "${w_sum}" -a
  [[ ! -e "${dcolDir}/dark/${h_sum}.dcol" ]] && "${scrRun}" "${w_sum}" -d
  [[ ! -e "${dcolDir}/light/${h_sum}.dcol" ]] && "${scrRun}" "${w_sum}" -l
} >/dev/null 2>&1

fn_wallcache_thumb() {
  local h_sum="${1:-}"
  local w_sum="${2:-}"
  local sr_call="$(fl_wallpaper -t "${w_sum}" -f 1)"
  [[ ! -f "${colsDir}/${sr_call}.cols" ]] && magick "${w_sum}"[0] -strip -resize 1000 -gravity center -extent 1000 -quality 90 "${colsDir}/${sr_call}.cols"
  [[ ! -f "${thmbDir}/${sr_call}.thmb" ]] && magick "${w_sum}"[0] -strip -thumbnail 500x500^ -gravity center -extent 500x500 "${thmbDir}/${sr_call}.thmb"
  [[ ! -f "${quadDir}/${sr_call}.quad" ]] && magick "${thmbDir}/${sr_call}.thmb" \( -size 500x500 xc:white -fill "rgba(0,0,0,7)" -draw "polygon 400,500 500,500 500,0 450,0" -fill black -draw "polygon 500,500 500,0 450,500" \) -alpha Off -compose CopyOpacity -composite png:"${quadDir}/${sr_call}.quad"
} >/dev/null 2>&1

fn_wallcache_blur() {
  local h_sum="${1:-}"
  local w_sum="${2:-}"
  local sr_call="$(fl_wallpaper -t "${w_sum}" -f 1)"
  [[ ! -f "${blurDir}/${sr_call}.bpex" ]] && magick "${w_sum}"[0] -strip -scale 10% -blur 0x3 -resize 100% "${blurDir}/${sr_call}.bpex"
} >/dev/null 2>&1

fn_wallcache_force() {
  local h_sum="${1:-}"
  local w_sum="${2:-}"
  local sr_call="$(fl_wallpaper -t "${w_sum}" -f 1)"

  magick "${w_sum}"[0] -strip -resize 1000 -gravity center -extent 1000 -quality 90 "${colsDir}/${sr_call}.cols"
  magick "${w_sum}"[0] -strip -scale 10% -blur 0x3 -resize 100% "${blurDir}/${sr_call}.bpex"
  magick "${w_sum}"[0] -strip -thumbnail 500x500^ -gravity center -extent 500x500 "${thmbDir}/${sr_call}.thmb"
  magick "${thmbDir}/${sr_call}.thmb" \( -size 500x500 xc:white -fill "rgba(0,0,0,7)" -draw "polygon 400,500 500,500 500,0 450,0" -fill black -draw "polygon 500,500 500,0 450,500" \) -alpha Off -compose CopyOpacity -composite png:"${quadDir}/${sr_call}.quad"
  "${scrRun}" "${w_sum}" -d
  "${scrRun}" "${w_sum}" -l
  "${scrRun}" "${w_sum}" -a
} >/dev/null 2>&1

export -f fn_wallcache fn_wallcache_force fn_wallcache_blur fn_wallcache_thumb fl_wallpaper
export thmbDir blurDir dcolDir scrRun mode cacheIn colsDir sr_call scrDir quadDir VYLE_CACHE_HOME

mode="${mode:-}"
cacheIn="${cacheIn:-}"
while getopts ":f:w:b:t:" option; do
  case $option in
  f)
    cacheIn="${OPTARG}"
    mode="_force"
    [[ -z "${OPTARG}" || ! -e "${OPTARG}" ]] && {
      echo "Error: Input wallpaper has returned exit code 1"
      exit 1
    }
    ;;
  w)
    cacheIn="$OPTARG"
    [[ -z "${OPTARG}" || ! -e "${OPTARG}" ]] && {
      echo "Error: Input wallpaper \"${OPTARG}\" not found!"
      exit 1
    }
    ;;
  b)
    cacheIn="${OPTARG}"
    mode="_blur"
    [[ -z "${OPTARG}" || ! -e "${OPTARG}" ]] && {
      echo "Error: Input wallpaper \"${OPTARG}\" not found!"
      exit 1
    }
    ;;
  t)
    cacheIn="${OPTARG}"
    mode="_thumb"
    [[ -z "${OPTARG}" || ! -e "${OPTARG}" ]] && {
      echo "Error: Input wallpaper \"${OPTARG}\" not found!"
      exit 1
    }
    ;;
  esac
done

wallPathArray=("${cacheIn}")
hashmap -v -t "${wallPathArray[@]}" >/dev/null
mkdir -p "${scrDir}/tmpfs"
parallel --bar --link --compress --tmpdir "${scrDir}/tmpfs" fn_wallcache${mode} ::: "${wallHash[@]}" ::: "${wallList[@]}"
rm -rf "${scrDir}/tmpfs"
exit 0
