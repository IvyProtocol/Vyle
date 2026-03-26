#!/usr/bin/env bash
set -eo pipefail

# -----------------------
# Configuration
# -----------------------
scrDir="$(dirname "$(realpath "$0")")"
source "${scrDir}/globalcontrol.sh"

wbDir="${VYLE_CONFIG_HOME}"
shellDir="${1:-${wbDir}/theme/${VYLE_THEME}}"

if [[ "${VYLE_THEME}" == "Wallbash-Ivy" ]]; then
    shellDir="${1:-${wbDir}/Wall-Dcol}"
fi
thmDcolDir="${wbDir}/Wall-Ways"
targetDir="${2:-${XDG_CACHE_HOME:-$HOME/.cache}/wal/wal-dir/}"
mkdir -p "$targetDir"
confDir="${XDG_CONFIG_HOME}"
cacheDir="${XDG_CACHE_HOME}"
homeDir="$HOME"
themesDir="$HOME/.themes"

inputPath="${@}"
template_sources=()

if [[ -n "${inputPath}" && -f "${inputPath}" ]]; then
    template_sources=("${inputPath}")
elif [[ -n "${inputPath}" && -d "${inputPath}" ]]; then
    template_sources=("${inputPath}" "${thmDcolDir}")
else
    template_sources=("${shellDir}" "${thmDcolDir}")
fi

if [[ -n "${skipTemplate}" ]]; then
    __clause=()
    for indx in "${skipTemplate[@]}"; do
        __clause+=( ! -name "${indx}" )
    done
fi

[[ -z "${plLoader}" ]] && plLoader="ivy"

# -----------------------
# Early Fallback Check
# -----------------------
[[ "$EUID" -eq 0 ]] && echo "[$0] must not be run as root." >&2 && exit 1

if ! find "$shellDir" "${thmDcolDir}" -type f \( -name '*.dcol' -o -name '*.ivy' -o -name '*.theme' \) -print -quit | grep -q .; then
    echo "${0##*/}: no .dcol or .ivy templates found, nothing to apply."
    exit 0
fi

# -----------------------
# Load palette files
# -----------------------
[[ -f "$wbDir/theme.ivy" ]] && load_ivy_file "$wbDir/theme.ivy"
[[ -f "$wbDir/theme-rgba.ivy" ]] && load_ivy_file "$wbDir/theme-rgba.ivy"

export palette_vars_list=$(compgen -v | grep -E "^(${plLoader})_")

if [[ -z "${palette_vars_list}" ]]; then
    echo "${0##*/} no palette variables loaded, nothing to apply."
    exit 0
fi

# -----------------------
# Template processing engine - PERL
# -----------------------
export PERL_REPLACER='
    my %env = %ENV;

    # Subroutine to handle the replacement logic safely
    sub r {
        my ($rgba_var, $op, $std_var) = @_;
        if ($std_var) {
            return $env{$std_var} // $_[0];
        }
        if (defined $env{$rgba_var} && $env{$rgba_var} =~ /rgba\((\d+),(\d+),(\d+),[\d.]+\)/) {
            return "rgba($1,$2,$3,$op)";
        }
        return $_[0];
    }

    while (<>) {
        # Match <VAR> or <VAR_rgba(OP)> and pass captures to r()
        s/(< (?:(\w+_rgba)\(([^)]+)\)|(\w+)) >)/r($2, $3, $4)/gex;
        print;
    }
'

process_template() {
    local template_file="$1"
    [[ ! -f "$template_file" ]] && return 0

    # Read first line and trim spaces
    read -r raw_first_line < "$template_file"
    local first_line="${raw_first_line%"${raw_first_line##*[![:space:]]}"}"

    # Determine target and optional script
    local target script=""
    if [[ "$first_line" == *"|"* ]]; then
        target="${first_line%%|*}"
        script="${first_line##*|}"
    elif [[ -n "$first_line" ]]; then
        target="$first_line"
    else
        rel="$(realpath --relative-to="$shellDir" "$template_file")"
        target="$targetDir/${rel%.*}"
    fi

    # Expand special variables
    target="${target//\$(scrDir)/$scrDir}"
    target="${target//\$(confDir)/$confDir}"
    target="${target//\$(cacheDir)/$cacheDir}"
    target="${target//\$(homDir)/$homeDir}"
    target="${target//\$(themesDir)/$themesDir}"
    [[ -n "$script" ]] && script="${script//\$(scrDir)/$scrDir}"
    [[ -n "$script" ]] && script="${script//\$(confDir)/$confDir}"
    [[ -n "$script" ]] && script="${script//\$(cacheDir)/$cacheDir}"
    [[ -n "$script" ]] && script="${script//\$(homeDir)/$homeDir}"
    [[ -n "$script" ]] && script="${script//\$(themesDir)/$themesDir}"

    # Call perl to replace placeholders.
    local template_write=$(tail -n +2 "$template_file" | perl -e "$PERL_REPLACER")
    # -----------------------
    # Write template output
    # -----------------------
    
    target_dir="${target%/*}"
    [[ -d "${target_dir}" ]] || mkdir -p "${target_dir}"
    if [[ ! -f "${target}" ]] || ! printf "%s" "$template_write" | cmp -s - "$target"; then
        printf "%s" "${template_write}" > "$target"
        echo " :: Theme Control - Populating ${target} <- ${template_file}"
    else
        echo " :: Theme Control - Skipped changing ${target} <- ${template_file}"
        return 0
    fi

    # -----------------------
    # Execute optional script safely
    # -----------------------
    if [[ -n "$script" ]]; then
        # Inline commands prefixed with $RUN:
        if [[ "$script" == \$RUN:* ]]; then
            bash -c "${script#\$RUN:}"
        # Executable file
        elif [[ -x "$script" ]]; then
            "$script"
        fi
    fi
    set -u
}

export -f process_template setConf notify tomlq
export scrDir confDir cacheDir targetDir homeDir themesDir shellDir plLoader thmDcolDir __clause skipTemplate nProcCount

# -----------------------
# Run templates in parallel
# -----------------------

if [[ -f "${template_sources[0]}" ]]; then
    process_template "${template_sources[0]}"
else
    find "${template_sources[@]}" -type f \( -name '*.dcol' -o -name '*.ivy' -o -name '*.theme' \) "${__clause[@]}" -print0 \
        | sort -zVf \
        | xargs -0 -n 5 -P "${nProcCount}" bash -c 'for f in "$@"; do process_template "$f"; done' _
fi
