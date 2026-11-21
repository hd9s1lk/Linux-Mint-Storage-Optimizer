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
        "${BOLD}Uso:${RESET} Mint_Storage-opt.sh <comando>" \
        "" \
        "Comandos disponíveis:" \
        "  clean     Limpa pacotes órfãos, cache APT, thumbnails e logs antigos com detalhe" \
        "  check     Mostra espaço livre atual e tamanho da cache" \
        "  help      Mostra esta ajuda"
}

run_with_details() {
    local step_title="$1"
    local cmd_preview="$2"
    shift 2

    local log_file
    log_file=$(mktemp /tmp/storage_opt.XXXXXX)

    echo -e "\n${BOLD}▸ ${step_title}${RESET}"
    echo -e "  ${DIM}\$ ${cmd_preview}${RESET}"

    stdbuf -oL -eL "$@" >"$log_file" 2>&1 &
    local pid=$!

    local max_stars=15
    local star_count=0
    local stars=""

    printf "\n\n\n\n\n"

    while kill -0 "$pid" 2>/dev/null; do
        if (( star_count < max_stars )); then
            stars+="*"
            ((star_count++))
        else
            stars="*"
            star_count=1
        fi

        printf "\033[5A"

        local recent_text
        recent_text=$(tr '\r' '\n' < "$log_file" | awk 'NF' | tail -n 4)
        mapfile -t recent_lines <<< "$recent_text"

        for i in 0 1 2 3; do
            printf "\033[2K"
            if [[ -n "${recent_lines[$i]:-}" ]]; then
                printf "  ${DIM}│ %.72s${RESET}\n" "${recent_lines[$i]}"
            else
                printf "  ${DIM}│ A preparar...${RESET}\n"
            fi
        done

        printf "\033[2K${CYAN}  A Otimizar ***${RESET} ${YELLOW}%s${RESET}\n" "$stars"

        sleep 0.25
    done

    wait "$pid"
    local exit_code=$?

    printf "\033[5A"
    for i in 0 1 2 3 4; do
        printf "\033[2K\n"
    done
    printf "\033[5A"

    if (( exit_code == 0 )); then
        local summary
        summary=$(tr '\r' '\n' < "$log_file" | grep -E '^(Removing|Purging|A remover|A purgar|Del |removed|Vacuuming|Deleted)' | tail -n 3 || true)
        if [[ -n "$summary" ]]; then
            while IFS= read -r line; do
                echo -e "  ${DIM}• ${line}${RESET}"
            done <<< "$summary"
        fi
        echo -e "  ${CYAN}A Otimizar ***${RESET} ${GREEN}[OK]${RESET}"
        echo -e "  ${GREEN}✔ Fase concluída:${RESET} ${step_title}"
    else
        echo -e "  ${CYAN}A Otimizar ***${RESET} ${RED}[ERRO]${RESET}"
        echo -e "\n${RED}${BOLD}✖ Falha na fase:${RESET} ${step_title}"
        echo -e "${RED}  Processo/Comando:${RESET} ${cmd_preview}"
        echo -e "${RED}  Código de saída:${RESET} ${exit_code}"
        echo -e "${RED}  Detalhe do erro:${RESET}"
        sed 's/^/    /' "$log_file"
        rm -f "$log_file"
        exit "$exit_code"
    fi

    rm -f "$log_file"
}

# Validação estrita do número e formato dos argumentos
if (( $# == 0 )); then
    printf '%b\n' "${RED}${BOLD}Erro:${RESET} Nenhum comando especificado." >&2
    show_usage
    exit 1
fi

if (( $# > 1 )); then
    printf '%b\n' "${RED}${BOLD}Erro:${RESET} Demasiados argumentos. Espera apenas 1 comando." >&2
    show_usage
    exit 1
fi

cmd="$1"

case "$cmd" in
    clean)
        echo -e "${BOLD}=== Linux Mint Storage Optimizer ===${RESET}"

        if ! sudo -v; then
            echo -e "\n${RED}${BOLD}✖ Erro de autenticação:${RESET} Não foi possível obter permissões de administrador (sudo)."
            exit 1
        fi

        while true; do sudo -n true; sleep 50; kill -0 "$$" || exit; done 2>/dev/null &
        KEEPALIVE_PID=$!
        trap 'kill "$KEEPALIVE_PID" 2>/dev/null || true' EXIT

        run_with_details \
            "1/4 Remover pacotes e dependências órfãs" \
            "sudo apt-get autoremove --purge -y" \
            sudo apt-get autoremove --purge -y

        run_with_details \
            "2/4 Limpar pacotes desatualizados da cache APT" \
            "sudo apt-get autoclean -y" \
            sudo apt-get autoclean -y

        run_with_details \
            "3/4 Limpar cache de miniaturas do utilizador" \
            "find ~/.cache/thumbnails -type f -delete -print" \
            bash -c 'mkdir -p ~/.cache/thumbnails && find ~/.cache/thumbnails -type f -delete -print'

        run_with_details \
            "4/4 Limpar registos do sistema (journald > 7 dias)" \
            "sudo journalctl --vacuum-time=7d" \
            sudo journalctl --vacuum-time=7d

        echo -e "\n${GREEN}${BOLD}✔ Todas as fases foram concluídas com sucesso!${RESET}"
        df -h /
        ;;
    check)
        echo -e "${BOLD}Espaço em disco (raiz):${RESET}"
        df -h /
        echo -e "\n${BOLD}Cache APT:${RESET}"
        du -sh /var/cache/apt/archives 2>/dev/null || true
        echo -e "\n${BOLD}Cache de miniaturas (~/.cache/thumbnails):${RESET}"
        du -sh ~/.cache/thumbnails 2>/dev/null || true
        ;;
    help|-h|--help)
        show_usage
        exit 0
        ;;
    *)
        printf '%b\n' "${RED}${BOLD}Erro:${RESET} Comando desconhecido '${cmd}'." >&2
        show_usage
        exit 1
        ;;
esac