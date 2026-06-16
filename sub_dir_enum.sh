#!/usr/bin/env bash

set -euo pipefail

# ------------------- Colors --------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ------------------- Help --------------------
show_help() {
    cat <<EOF
Usage: ${0##*/} [OPTIONS] <target> [wordlist]

Advanced Sub-Directory Enumeration Script
Combines the power of ffuf, gobuster, dirsearch, feroxbuster, and dirb.

OPTIONS:
  -u, --target URL        Target domain/IP (with or without scheme)
  -w, --wordlist FILE     Custom wordlist file
  --ffuf                  Use ffuf only
  --gobuster              Use gobuster only
  --dirsearch             Use dirsearch only
  --feroxbuster           Use feroxbuster only
  --dirb                  Use dirb only
  --all                   Use all available tools (default if none specified)
  -h, --help              Show this help message

POSITIONAL ARGUMENTS:
  target                  The target host (e.g., example.com or http://example.com)
  wordlist                (Optional) Path to wordlist file. Auto-detects if omitted.

EXAMPLES:
  ${0##*/} example.com
  ${0##*/} --ffuf -w /path/to/list.txt example.com
  ${0##*/} --gobuster --dirsearch https://example.com
  ${0##*/} --all -w /usr/share/seclists/Discovery/Web-Content/raft-large-directories.txt example.com

NOTES:
  - Output is saved in ./subdir_enum_<target>/ with per‑tool filtered results.
  - If no tool is explicitly selected, all installed tools are used.
  - Wordlist priority: command line > common locations > fallback.
EOF
}

# ------------------- Helper functions ----------
sanitize_target() {
    local raw="$1"
    raw="${raw#http://}"
    raw="${raw#https://}"
    raw="${raw%%/*}"
    printf '%s' "${raw,,}"
}

find_wordlist() {
    local candidate="${1:-}"

    if [[ -n "$candidate" && -f "$candidate" ]]; then
        printf '%s\n' "$candidate"
        return 0
    fi

    local -a paths=(
        # Recommended lists (ordered by quality)
        "/usr/share/seclists/Discovery/Web-Content/directory-list-2.3-medium.txt"
        "/usr/share/seclists/Discovery/Web-Content/raft-large-directories.txt"
        "/usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt"
        "/usr/share/seclists/Discovery/Web-Content/common.txt"
        "/usr/share/wordlists/dirb/common.txt"
        "/usr/share/dirb/wordlists/common.txt"
        "/usr/share/wordlists/dirb/common.txt"
    )

    for p in "${paths[@]}"; do
        if [[ -f "$p" ]]; then
            printf '%s\n' "$p"
            return 0
        fi
    done

    return 1
}

check_command() {
    if ! command -v "$1" &>/dev/null; then
        echo -e "${YELLOW}[!] Skipping $1 (not installed)${NC}"
        return 1
    fi
    return 0
}

# ------------------- Runner functions ----------
run_ffuf() {
    local url="https://${TARGET}"
    local json_out="$OUT_DIR/ffuf.json"
    local filtered_out="$OUT_DIR/ffuf_filtered.txt"

    echo -e "${CYAN}[ffuf] Enumerating paths...${NC}"
    ffuf -u "${url}/FUZZ" -w "$WORDLIST" -t 20 \
        -mc '200,204,301,302,307,308,401,403,405' \
        -o "$json_out" -of json -s >/dev/null || true

    if [[ -f "$json_out" ]]; then
        python3 - "$json_out" "$filtered_out" "$TARGET" <<'PY'
import json, sys
infile, outfile, host = sys.argv[1:4]
results = []
seen = set()
with open(infile, 'r', encoding='utf-8') as fh:
    data = json.load(fh)
for item in data.get('results', []):
    url = item.get('url','').strip()
    status = str(item.get('status','0')).strip()
    if url:
        line = f"{status}  {url}"
        if line not in seen:
            seen.add(line)
            results.append(line)
with open(outfile, 'w', encoding='utf-8') as fh:
    for line in sorted(results):
        fh.write(line + '\n')
PY
        echo -e "${GREEN}[ffuf] Found $(wc -l < "$filtered_out") entries.${NC}"
    else
        echo -e "${RED}[ffuf] No output file produced.${NC}"
    fi
}

run_gobuster() {
    local url="https://${TARGET}"
    local raw_out="$OUT_DIR/gobuster.txt"
    local filtered_out="$OUT_DIR/gobuster_filtered.txt"
    local err_out="$OUT_DIR/gobuster.err"

    echo -e "${CYAN}[gobuster] Enumerating paths...${NC}"
    : > "$err_out"
    gobuster dir -u "$url" -w "$WORDLIST" -e -k -t 20 -o "$raw_out" 2>"$err_out" || true

    if [[ ! -s "$raw_out" ]]; then
        echo "Gobuster produced no file output; retrying in direct mode..."
        gobuster dir -u "$url" -w "$WORDLIST" -e -k -t 20 2>>"$err_out" | tee "$raw_out" || true
    fi

    if [[ -f "$raw_out" ]]; then
        python3 - "$raw_out" "$filtered_out" "$TARGET" <<'PY'
import re, sys
infile, outfile, host = sys.argv[1:4]
results = []
seen = set()
status_re = re.compile(r'(?:Status:\s*|\b)(\d{3})(?:\b|\s)', re.IGNORECASE)
with open(infile, 'r', encoding='utf-8', errors='ignore') as fh:
    for raw_line in fh:
        line = raw_line.strip()
        if not line: continue
        status_match = status_re.search(line)
        status = status_match.group(1) if status_match else '0'
        url = line
        url = re.sub(r'\s*\(Status:\s*\d+\)', '', url)
        url = re.sub(r'^\d+\s+', '', url)
        url = re.sub(r'\s+', ' ', url).strip()
        if not url.startswith('http'):
            url = f"https://{host}/{url.lstrip('/')}" if url else ''
        if url:
            entry = f"{status}  {url}"
            if entry not in seen:
                seen.add(entry)
                results.append(entry)
with open(outfile, 'w', encoding='utf-8') as fh:
    for line in sorted(results):
        fh.write(line + '\n')
PY
        echo -e "${GREEN}[gobuster] Found $(wc -l < "$filtered_out") entries.${NC}"
    else
        echo -e "${RED}[gobuster] No output file.${NC}"
    fi
}

run_dirsearch() {
    local url="https://${TARGET}"
    local out_file="$OUT_DIR/dirsearch.txt"
    local filtered_out="$OUT_DIR/dirsearch_filtered.txt"

    echo -e "${CYAN}[dirsearch] Enumerating paths...${NC}"
    dirsearch -u "$url" -w "$WORDLIST" -e php,html,js,bak,zip,tar.gz,old --format plain -o "$out_file" --quiet 2>/dev/null || true

    if [[ -f "$out_file" ]]; then
        # dirsearch outputs lines with Status: XXX, path
        python3 - "$out_file" "$filtered_out" "$TARGET" <<'PY'
import re, sys
infile, outfile, host = sys.argv[1:4]
results = []
seen = set()
with open(infile, 'r', encoding='utf-8', errors='ignore') as fh:
    for line in fh:
        line = line.strip()
        match = re.match(r'(\d{3})\s+(.+)', line)
        if match:
            status = match.group(1)
            path = match.group(2).strip()
            url = f"https://{host}/{path.lstrip('/')}" if not path.startswith('http') else path
            entry = f"{status}  {url}"
            if entry not in seen:
                seen.add(entry)
                results.append(entry)
with open(outfile, 'w', encoding='utf-8') as fh:
    for line in sorted(results):
        fh.write(line + '\n')
PY
        echo -e "${GREEN}[dirsearch] Found $(wc -l < "$filtered_out") entries.${NC}"
    else
        echo -e "${RED}[dirsearch] No output file.${NC}"
    fi
}

run_feroxbuster() {
    local url="https://${TARGET}"
    local out_file="$OUT_DIR/feroxbuster.txt"
    local filtered_out="$OUT_DIR/feroxbuster_filtered.txt"

    echo -e "${CYAN}[feroxbuster] Enumerating paths...${NC}"
    feroxbuster -u "$url" -w "$WORDLIST" -t 20 --quiet --json -o "$out_file" 2>/dev/null || true

    if [[ -f "$out_file" ]]; then
        python3 - "$out_file" "$filtered_out" "$TARGET" <<'PY'
import json, sys
infile, outfile, host = sys.argv[1:4]
results = []
seen = set()
try:
    with open(infile, 'r', encoding='utf-8') as fh:
        for line in fh:
            line = line.strip()
            if not line: continue
            try:
                item = json.loads(line)
                url = item.get('url','')
                status = str(item.get('status','0'))
                if url:
                    entry = f"{status}  {url}"
                    if entry not in seen:
                        seen.add(entry)
                        results.append(entry)
            except json.JSONDecodeError:
                continue
except FileNotFoundError:
    pass
with open(outfile, 'w', encoding='utf-8') as fh:
    for line in sorted(results):
        fh.write(line + '\n')
PY
        echo -e "${GREEN}[feroxbuster] Found $(wc -l < "$filtered_out") entries.${NC}"
    else
        echo -e "${RED}[feroxbuster] No output file.${NC}"
    fi
}

run_dirb() {
    local url="https://${TARGET}"
    local out_file="$OUT_DIR/dirb.txt"
    local filtered_out="$OUT_DIR/dirb_filtered.txt"

    echo -e "${CYAN}[dirb] Enumerating paths (this may be slow)...${NC}"
    dirb "$url" "$WORDLIST" -o "$out_file" -w >/dev/null 2>&1 || true

    if [[ -f "$out_file" ]]; then
        python3 - "$out_file" "$filtered_out" "$TARGET" <<'PY'
import re, sys
infile, outfile, host = sys.argv[1:4]
results = []
seen = set()
with open(infile, 'r', encoding='utf-8', errors='ignore') as fh:
    for line in fh:
        line = line.strip()
        # dirb output format: + <url> (CODE:200|SIZE:1234)
        match = re.search(r'\(\s*CODE:(\d{3})\s*\|', line)
        if match:
            status = match.group(1)
            # extract URL between '+' and '('
            url_match = re.search(r'^\+\s+(.*?)\s+\(', line)
            if url_match:
                url = url_match.group(1).strip()
                if not url.startswith('http'):
                    url = f"https://{host}/{url.lstrip('/')}"
                entry = f"{status}  {url}"
                if entry not in seen:
                    seen.add(entry)
                    results.append(entry)
with open(outfile, 'w', encoding='utf-8') as fh:
    for line in sorted(results):
        fh.write(line + '\n')
PY
        echo -e "${GREEN}[dirb] Found $(wc -l < "$filtered_out") entries.${NC}"
    else
        echo -e "${RED}[dirb] No output file.${NC}"
    fi
}

combine_results() {
    local combined="$OUT_DIR/all_results.txt"
    echo -e "\n${CYAN}[*] Combining unique results from all tools...${NC}"
    : > "$combined"
    for f in "$OUT_DIR"/*_filtered.txt; do
        [[ -f "$f" ]] && cat "$f" >> "$combined"
    done
    sort -u -o "$combined" "$combined"
    echo -e "${GREEN}[*] Final combined results: $combined ($(wc -l < "$combined") unique paths).${NC}"
}

# ------------------- Main --------------------
main() {
    # Parse arguments
    local -a selected_tools=()
    local target_provided=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help) show_help; exit 0 ;;
            --ffuf) selected_tools+=("ffuf"); shift ;;
            --gobuster) selected_tools+=("gobuster"); shift ;;
            --dirsearch) selected_tools+=("dirsearch"); shift ;;
            --feroxbuster) selected_tools+=("feroxbuster"); shift ;;
            --dirb) selected_tools+=("dirb"); shift ;;
            --all) selected_tools+=("all"); shift ;;
            -w|--wordlist)
                WORDLIST="$2"
                shift 2 ;;
            -u|--target)
                TARGET="$2"
                target_provided=true
                shift 2 ;;
            *)
                if [[ "$target_provided" == false ]]; then
                    TARGET="$1"
                    target_provided=true
                    shift
                elif [[ -z "${WORDLIST-}" && -f "$1" ]]; then
                    WORDLIST="$1"
                    shift
                else
                    echo -e "${RED}Unknown argument: $1${NC}" >&2
                    show_help >&2
                    exit 1
                fi ;;
        esac
    done

    # Validate target
    if [[ -z "${TARGET-}" ]]; then
        echo -e "${RED}Error: Target is required.${NC}" >&2
        show_help >&2
        exit 1
    fi

    TARGET="$(sanitize_target "$TARGET")"
    echo -e "${CYAN}[*] Target: ${TARGET}${NC}"

    # Wordlist
    WORDLIST="$(find_wordlist "${WORDLIST-}")"
    if [[ -z "$WORDLIST" ]]; then
        echo -e "${RED}Error: No wordlist found. Provide one with -w or install common lists.${NC}" >&2
        exit 1
    fi
    echo -e "${CYAN}[*] Wordlist: ${WORDLIST}${NC}"

    # Output directory
    OUT_DIR="./subdir_enum_${TARGET//[^A-Za-z0-9]/_}"
    mkdir -p "$OUT_DIR"
    echo -e "${CYAN}[*] Output directory: ${OUT_DIR}${NC}"

    # Decide which tools to run
    if [[ ${#selected_tools[@]} -eq 0 ]]; then
        # Default: all available
        selected_tools+=("all")
    fi

    local -a final_tools=()
    if printf '%s\n' "${selected_tools[@]}" | grep -q 'all'; then
        final_tools=("ffuf" "gobuster" "dirsearch" "feroxbuster" "dirb")
    else
        final_tools=("${selected_tools[@]}")
    fi

    # Run tools
    for tool in "${final_tools[@]}"; do
        if check_command "$tool"; then
            "run_${tool}"
        fi
    done

    combine_results

    echo -e "\n${GREEN}[✓] Enumeration complete.${NC}"
}

main "$@"
