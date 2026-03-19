#!/usr/bin/env bash
set -eo pipefail

# -----------------------
# Configuration
# -----------------------
scrDir="$(dirname "$(realpath "$0")")"
source "${scrDir}/../globalcontrol.sh"

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
    echo "ivygen-helper: no .dcol or .ivy templates found, nothing to apply."
    exit 0
fi

# -----------------------
# Load palette files
# -----------------------
[[ -f "$wbDir/theme.ivy" ]] && load_ivy_file "$wbDir/theme.ivy"
[[ -f "$wbDir/theme-rgba.ivy" ]] && load_ivy_file "$wbDir/theme-rgba.ivy"

export palette_vars_list=$(compgen -v | grep -E "^(${plLoader})_" | tr '\n' ' ')

if [[ -z "${palette_vars_list}" ]]; then
    echo "ivygen-helper: no palette variables loaded, nothing to apply."
    exit 0
fi

# -----------------------
# Template processing function
# -----------------------
process_template() {
    set +u
    local template_file="$1"
    
    case "$template_file" in
    *.dcol|*.ivy|*.theme) ;;
    *)
        echo "ivygen-helper: unsupported template type: $template_file" >&2
        return 0
        ;;
    esac

    # Read first line and trim spaces
    read -r raw_first_line < "$template_file"
    local first_line="${raw_first_line%"${raw_first_line##*[![:space:]]}"}"

    # Remove first line from template content
    local template_content
    template_content=$(<"$template_file")
    template_content="${template_content#*$'\n'}"

    # Determine target and optional script
    local target script=""
    if [[ "$first_line" == *"|"* ]]; then
        target="${first_line%%|*}"
        script="${first_line##*|}"
    elif [[ -n "$first_line" ]]; then
        target="$first_line"
    else
        rel="$(realpath --relative-to="$shellDir" "$template_file")"
        case "$rel" in
            *.dcol) target="$targetDir/$(rel%.dcol)" ;;
            *.ivy)  target="$targetDir/$(rel%.ivy)" ;;
            *.theme) target="$targetDir/$(rel%.theme)"
        esac
    fi

    # Expand special variables
    target="${target//\$(scrDir)/$scrDir}"
    target="${target//\$(confDir)/$confDir}"
    target="${target//\$(cacheDir)/$cacheDir}"
    target="${target//\$(homDir)/$homDir}"
    [[ -n "$script" ]] && script="${script//\$(scrDir)/$scrDir}"
    [[ -n "$script" ]] && script="${script//\$(confDir)/$confDir}"
    [[ -n "$script" ]] && script="${script//\$(cacheDir)/$cacheDir}"
    [[ -n "$script" ]] && script="${script//\$(homeDir)/$homeDir}"

    # Replace placeholders
    if [[ "$template_content" =~ \<(${plLoader})_.* ]]; then
        for var in ${palette_vars_list}; do
            value="${!var}"       # original value
            placeholder="<${var}>"

        # 1) Replace simple <wallbash_XXXX>
            template_content="${template_content//${placeholder}/${value}}"

        # 2) Replace <wallbash_XXXX_rgba>
            if [[ "$var" == *_rgba ]]; then
                placeholder_rgba="<${var}>"
                template_content="${template_content//${placeholder_rgba}/${value}}"

            # 3) Replace <wallbash_XXXX_rgba(X)>
            # Use regex to find all occurrences with optional alpha
                while [[ "$template_content" =~ \<${var}\(([0-9.]+)\)\> ]]; do
                    alpha="${BASH_REMATCH[1]}"
                    if [[ "$value" =~ rgba\(([0-9]+),([0-9]+),([0-9]+),([0-9.]+)\) ]]; then
                        r="${BASH_REMATCH[1]}"
                        g="${BASH_REMATCH[2]}"
                        b="${BASH_REMATCH[3]}"
                        template_content="${template_content//<${var}(${alpha})>/rgba($r,$g,$b,$alpha)}"
                    else
                    # Fallback: remove placeholder if badly formatted
                        template_content="${template_content//<${var}(${alpha})>/$value}"
                    fi
                done
            fi
        done
    fi


    # -----------------------
    # Write template output
    # -----------------------
    target_dir="${target%/*}"
    [[ -d "${target_dir}" ]] ||  mkdir -p "${target_dir}"
    if [[ ! -f "${target}" ]] || ! printf "%s" "$template_content" | cmp -s - "$target"; then
        printf "%s" "$template_content" > "$target"
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
        else
            echo " :: Theme Control - Skipping non-executable script from ${template_file}"
        fi
    fi
    set -u
}

export -f process_template setConf notify tomlq
export scrDir confDir cacheDir targetDir homeDir shellDir plLoader thmDcolDir __clause skipTemplate nProcCount
for var in ${palette_vars_list}; do export "$var"; done

# -----------------------
# Run templates in parallel
# -----------------------

if [[ -f "${template_sources[0]}" ]]; then
    process_template "${template_sources[0]}"
else
    find "${template_sources[@]}" -type f \( -name '*.dcol' -o -name '*.ivy' -o -name '*.theme' \) "${__clause[@]}" -print0 \
        | sort -zVf \
        | xargs -0 -n 1 -P "${nProcCount}" bash -c 'process_template "$1"' _
fi


