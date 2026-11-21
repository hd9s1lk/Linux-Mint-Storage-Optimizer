#!/usr/bin/env bash
set -uo pipefail

BOLD="\033[1m"
DIM="\033[2m"
CYAN="\033[1;36m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
RESET="\033[0m"

show_usage() {
    printf '%b\n' \
        "${BOLD}Usage:${RESET} Mint_Storage-opt.sh <command>" \
        "" \
        "Available commands:" \
        "  clean     Clean orphaned packages, APT cache, thumbnails, and old logs in detail" \
        "  check     Show current free disk space and cache sizes" \
        "  help      Show this help message"
}

run_with_details() {
    local step_title="$1"
    local cmd_preview="$2"
    shift 2

    local log_file
    log_file=$(mktemp /tmp/storage_opt.XXXXXX)

    echo -e "\n${BOLD}▸ ${step_title}${RESET}"
    echo -e "  ${DIM}\$ ${cmd_preview}${RESET}"

    # Run command in background with unbuffered output for live updates
    stdbuf -oL -eL "$@" >"$log_file" 2>&1 &
    local pid=$!

    local max_stars=15
    local star_count=0
    local stars=""

    # Reserve 5 lines in the terminal
    printf "\n\n\n\n\n"

    while kill -0 "$pid" 2>/dev/null; do
        if (( star_count < max_stars )); then
            stars+="*"
            ((star_count++))
        else
            stars="*"
            star_count=1
        fi

        # Move cursor up 5 lines to redraw the status box
        printf "\033[5A"

        # Extract the last 4 non-empty lines without failing if the log is still empty
        local recent_text
        recent_text=$(tr '\r' '\n' < "$log_file" | awk 'NF' | tail -n 4)
        mapfile -t recent_lines <<< "$recent_text"

        for i in 0 1 2 3; do
            printf "\033[2K"
            if [[ -n "${recent_lines[$i]:-}" ]]; then
                printf "  ${DIM}│ %.72s${RESET}\n" "${recent_lines[$i]}"
            else
                printf "  ${DIM}│ Preparing...${RESET}\n"
            fi
        done

        printf "\033[2K${CYAN}  A Otimizar ***${RESET} ${YELLOW}%s${RESET}\n" "$stars"

        sleep 0.25
    done

    wait "$pid"
    local exit_code=$?

    # Clear the 5 temporary progress lines
    printf "\033[5A"
    for i in 0 1 2 3 4; do
        printf "\033[2K\n"
    done
    printf "\033[5A"

    if (( exit_code == 0 )); then
        local summary
        summary=$(tr '\r' '\n' < "$log_file" | grep -E '^(Removing|Purging|Del |removed|Vacuuming|Deleted)' | tail -n 3 || true)
        if [[ -n "$summary" ]]; then
            while IFS= read -r line; do
                echo -e "  ${DIM}• ${line}${RESET}"
            done <<< "$summary"
        fi
        echo -e "  ${CYAN}A Otimizar ***${RESET} ${GREEN}[OK]${RESET}"
        echo -e "  ${GREEN}✔ Stage completed:${RESET} ${step_title}"
    else
        echo -e "  ${CYAN}A Otimizar ***${RESET} ${RED}[ERROR]${RESET}"
        echo -e "\n${RED}${BOLD}✖ Failed at stage:${RESET} ${step_title}"
        echo -e "${RED}  Process/Command:${RESET} ${cmd_preview}"
        echo -e "${RED}  Exit code:${RESET} ${exit_code}"
        echo -e "${RED}  Error details:${RESET}"
        sed 's/^/    /' "$log_file"
        rm -f "$log_file"
        exit "$exit_code"
    fi

    rm -f "$log_file"
}

# Strict argument count and format validation
if (( $# == 0 )); then
    printf '%b\n' "${RED}${BOLD}Error:${RESET} No command specified." >&2
    show_usage
    exit 1
fi

if (( $# > 1 )); then
    printf '%b\n' "${RED}${BOLD}Error:${RESET} Too many arguments. Expected exactly 1 command." >&2
    show_usage
    exit 1
fi

cmd="$1"

case "$cmd" in
    clean)
        echo -e "${BOLD}=== Linux Mint Storage Optimizer ===${RESET}"

        # Request sudo password upfront
        if ! sudo -v; then
            echo -e "\n${RED}${BOLD}✖ Authentication error:${RESET} Unable to acquire administrator (sudo) privileges."
            exit 1
        fi

        # Keep sudo session active while the script runs
        while true; do sudo -n true; sleep 50; kill -0 "$$" || exit; done 2>/dev/null &
        KEEPALIVE_PID=$!
        trap 'kill "$KEEPALIVE_PID" 2>/dev/null || true' EXIT

        # Stage 1: Orphaned packages and old kernels
        run_with_details \
            "1/4 Remove orphaned packages and dependencies" \
            "sudo apt-get autoremove --purge -y" \
            sudo apt-get autoremove --purge -y

        # Stage 2: Outdated .deb files in APT cache
        run_with_details \
            "2/4 Clean outdated packages from APT cache" \
            "sudo apt-get autoclean -y" \
            sudo apt-get autoclean -y

        # Stage 3: User thumbnails
        run_with_details \
            "3/4 Clean user thumbnail cache" \
            "find ~/.cache/thumbnails -type f -delete -print" \
            bash -c 'mkdir -p ~/.cache/thumbnails && find ~/.cache/thumbnails -type f -delete -print'

        # Stage 4: Systemd logs older than 7 days
        run_with_details \
            "4/4 Clean system logs (journald > 7 days)" \
            "sudo journalctl --vacuum-time=7d" \
            sudo journalctl --vacuum-time=7d

        echo -e "\n${GREEN}${BOLD}✔ All stages completed successfully!${RESET}"
        df -h /
        ;;
    check)
        echo -e "${BOLD}Disk space (root):${RESET}"
        df -h /
        echo -e "\n${BOLD}APT cache:${RESET}"
        du -sh /var/cache/apt/archives 2>/dev/null || true
        echo -e "\n${BOLD}Thumbnail cache (~/.cache/thumbnails):${RESET}"
        du -sh ~/.cache/thumbnails 2>/dev/null || true
        ;;
    help|-h|--help)
        show_usage
        exit 0
        ;;
    *)
        printf '%b\n' "${RED}${BOLD}Error:${RESET} Unknown command '${cmd}'." >&2
        show_usage
        exit 1
        ;;
esac