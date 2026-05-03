#!/bin/bash

CONFIG_FILE="/etc/glider/glider.conf"
SERVICE_FILE="/etc/systemd/system/glider.service"
BINARY_PATH="/usr/local/bin/glider-bin"
SCRIPT_PATH="/usr/local/bin/glider-manager"
SCRIPT_URL="https://raw.githubusercontent.com/thekhabaroff/GliderProxy/main/glider.sh"
VERSION="0.16.4"
STATS_DIR="/var/lib/glider-manager/stats"
STATS_STATE_FILE="${STATS_DIR}/traffic.tsv"
STATS_ARCHIVE_FILE="${STATS_DIR}/deleted.tsv"
STATS_IN_CHAIN="GLIDER_STATS_IN"
STATS_OUT_CHAIN="GLIDER_STATS_OUT"

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
CYAN_BOLD=$'\033[1;36m'
WHITE=$'\033[1;37m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
ITALIC=$'\033[3m'
NC=$'\033[0m'
MUTED=$'\033[38;5;67m'

run_with_spinner() {
    local msg="$1"; shift
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0

    ("$@") > /dev/null 2>&1 &
    local pid=$!

    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  ${CYAN}%s${NC}  ${DIM}%s${NC}" "${frames[$i]}" "$msg"
        i=$(( (i+1) % 10 ))
        sleep 0.1
    done

    wait "$pid"
    local s=$?

    if [ $s -eq 0 ]; then
        printf "\r  ${GREEN}✓${NC}  ${DIM}%s${NC}\n" "$msg"
    else
        printf "\r  ${RED}✗${NC}  ${DIM}%s${NC}\n" "$msg"
    fi

    return $s
}

arrow_menu() {
    local title="$1"; shift
    local items=("$@")
    local count=${#items[@]}
    local selected=0

    tput civis

    _render() {
        clear
        echo ""
        echo -e "  ${CYAN_BOLD}${title}${NC}"
        echo -e "  ${DIM}────────────────────────────────${NC}"
        echo ""
        for i in "${!items[@]}"; do
            local raw="${items[$i]}"
            local label="${raw%%	*}"
            local desc=""
            [[ "$raw" == *$'\t'* ]] && desc="${raw#*	}"
            if [ "$i" -eq "$selected" ]; then
                [ -n "$desc" ] \
                    && echo -e "  ${CYAN_BOLD}► ${BOLD}${label}${NC}  ${ITALIC}${MUTED}${desc}${NC}" \
                    || echo -e "  ${CYAN_BOLD}► ${BOLD}${label}${NC}"
            else
                [ -n "$desc" ] \
                    && echo -e "  ${MUTED}  ${label}${NC}  ${DIM}${desc}${NC}" \
                    || echo -e "  ${MUTED}  ${label}${NC}"
            fi
        done
        echo ""
        echo -e "  ${DIM}↑↓ — навигация   Enter — выбор${NC}"
    }

    while true; do
        _render
        IFS= read -rsn1 key
        if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 -t 0.1 rest
            case "$rest" in
                '[A') ((selected--)); [ "$selected" -lt 0 ] && selected=$((count-1)) ;;
                '[B') ((selected++)); [ "$selected" -ge "$count" ] && selected=0 ;;
            esac
        elif [[ "$key" == "" || "$key" == $'\n' ]]; then
            break
        fi
    done

    tput cnorm
    ARROW_CHOICE=$selected
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        clear; echo ""
        echo -e "  ${RED}${BOLD}Ошибка доступа${NC}"
        echo -e "  ${DIM}Требуются права root${NC}"
        echo -e "\n  Запустите: ${CYAN_BOLD}sudo glider${NC}\n"
        exit 1
    fi
}

validate_credentials() {
    local v="$1" n="$2"
    [[ "$v" =~ [@:/] ]] && { echo -e "\n  ${RED}✗ ${n} не должен содержать @, : или /${NC}"; return 1; }
    [ -z "$v" ]         && { echo -e "\n  ${RED}✗ ${n} не может быть пустым${NC}"; return 1; }
    return 0
}

validate_port() {
    local p="$1"
    if ! [[ "$p" =~ ^[0-9]+$ ]] || [ "$p" -lt 1 ] || [ "$p" -gt 65535 ]; then
        echo -e "\n  ${RED}✗ Порт должен быть от 1 до 65535${NC}"; return 1
    fi
}

check_glider_installed() { [ -f "$BINARY_PATH" ]; }

run_cli_command() {
    case "${1:-}" in
        --sync-stats)
            sync_config_stats >/dev/null 2>&1 || true
            exit 0
            ;;
    esac
}

get_current_version() {
    if check_glider_installed; then
        local v
        v=$(  "$BINARY_PATH" -help 2>&1 \
            | grep -o "glider [0-9][0-9.]*" \
            | awk '{print $2}' \
            | tr -d '[:space:]' \
            | head -1 )
        printf '%s' "${v:-$VERSION}"
    else
        printf '%s' "—"
    fi
}

copy_binary() {
    local src
    src=$(find /tmp -maxdepth 4 -name 'glider' -type f 2>/dev/null | head -1)
    if [ -z "$src" ]; then
        src=$(find /tmp -maxdepth 4 -name 'glider*' -type f \
            ! -name '*.tar*' ! -name '*.gz' ! -name '*.deb' 2>/dev/null | head -1)
    fi
    [ -z "$src" ] && return 1
    cp "$src" "$BINARY_PATH" && chmod +x "$BINARY_PATH"
}

prompt()  { echo -ne "\n  ${DIM}$1${NC} "; }
pause()   { echo -e "\n\n  ${DIM}Нажмите Enter для продолжения...${NC}"; read -r; }

section() {
    clear; echo ""
    echo -e "  ${CYAN_BOLD}${BOLD}$1${NC}"
    echo -e "  ${DIM}────────────────────────────────${NC}"
    echo ""
}

check_port_used() {
    local port=$1
    { [ -f "$CONFIG_FILE" ] && grep -q ":${port}" "$CONFIG_FILE" 2>/dev/null; } && return 0
    command -v ss      >/dev/null 2>&1 && ss -tuln      | grep -q ":${port} " && return 0
    command -v netstat >/dev/null 2>&1 && netstat -tuln | grep -q ":${port} " && return 0
    return 1
}

format_bytes() {
    local bytes=${1:-0}
    awk -v b="$bytes" 'BEGIN {
        split("B KiB MiB GiB TiB PiB", unit)
        i = 1
        while (b >= 1024 && i < 6) { b /= 1024; i++ }
        if (i == 1) printf "%d %s", b, unit[i]
        else printf "%.2f %s", b, unit[i]
    }'
}

ensure_stats_rules() {
    command -v iptables >/dev/null 2>&1 || return 1

    mkdir -p "$STATS_DIR"
    touch "$STATS_STATE_FILE"

    iptables -N "$STATS_IN_CHAIN"  2>/dev/null || true
    iptables -N "$STATS_OUT_CHAIN" 2>/dev/null || true

    iptables -C INPUT  -j "$STATS_IN_CHAIN"  >/dev/null 2>&1 || iptables -I INPUT  1 -j "$STATS_IN_CHAIN"
    iptables -C OUTPUT -j "$STATS_OUT_CHAIN" >/dev/null 2>&1 || iptables -I OUTPUT 1 -j "$STATS_OUT_CHAIN"
}

add_stats_port() {
    local port="$1" proto
    ensure_stats_rules || return 1

    for proto in tcp udp; do
        iptables -C "$STATS_IN_CHAIN"  -p "$proto" --dport "$port" >/dev/null 2>&1 || \
            iptables -A "$STATS_IN_CHAIN"  -p "$proto" --dport "$port"
        iptables -C "$STATS_OUT_CHAIN" -p "$proto" --sport "$port" >/dev/null 2>&1 || \
            iptables -A "$STATS_OUT_CHAIN" -p "$proto" --sport "$port"
    done

    ensure_stats_service_hook
}

remove_stats_port() {
    local port="$1" proto
    command -v iptables >/dev/null 2>&1 || return 0

    for proto in tcp udp; do
        while iptables -D "$STATS_IN_CHAIN"  -p "$proto" --dport "$port" >/dev/null 2>&1; do :; done
        while iptables -D "$STATS_OUT_CHAIN" -p "$proto" --sport "$port" >/dev/null 2>&1; do :; done
    done
}

remove_stats_rules() {
    command -v iptables >/dev/null 2>&1 || return 0

    while iptables -D INPUT  -j "$STATS_IN_CHAIN"  >/dev/null 2>&1; do :; done
    while iptables -D OUTPUT -j "$STATS_OUT_CHAIN" >/dev/null 2>&1; do :; done
    iptables -F "$STATS_IN_CHAIN"  >/dev/null 2>&1 || true
    iptables -F "$STATS_OUT_CHAIN" >/dev/null 2>&1 || true
    iptables -X "$STATS_IN_CHAIN"  >/dev/null 2>&1 || true
    iptables -X "$STATS_OUT_CHAIN" >/dev/null 2>&1 || true
}

ensure_stats_service_hook() {
    [ -f "$SERVICE_FILE" ] || return 0
    grep -q -- "--sync-stats" "$SERVICE_FILE" && return 0

    local tmp
    tmp=$(mktemp) || return 1
    awk -v hook="ExecStartPre=-$SCRIPT_PATH --sync-stats" '
        /^\[Service\]$/ { in_service = 1 }
        /^\[/ && $0 != "[Service]" { in_service = 0 }
        in_service && /^ExecStart=/ && !added { print hook; added = 1 }
        { print }
    ' "$SERVICE_FILE" > "$tmp" && mv "$tmp" "$SERVICE_FILE"

    systemctl daemon-reload >/dev/null 2>&1 || true
}

get_stats_counter() {
    local chain="$1" proto="$2" marker="$3" port="$4"
    iptables -L "$chain" -v -x -n 2>/dev/null \
        | awk -v proto="$proto" -v marker="$marker" -v port="$port" '$3 == proto && $0 ~ marker port "([^0-9]|$)" { bytes += $2 } END { print bytes + 0 }'
}

set_stats_state() {
    local port="$1" in_tcp_total="$2" in_udp_total="$3" out_tcp_total="$4" out_udp_total="$5"
    local in_tcp_last="$6" in_udp_last="$7" out_tcp_last="$8" out_udp_last="$9" updated="${10}" tmp
    mkdir -p "$STATS_DIR"
    tmp=$(mktemp "${STATS_DIR}/traffic.XXXXXX") || return 1

    if [ -f "$STATS_STATE_FILE" ]; then
        awk -F '\t' -v p="$port" '$1 != p { print }' "$STATS_STATE_FILE" > "$tmp"
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$port" "$in_tcp_total" "$in_udp_total" "$out_tcp_total" "$out_udp_total" \
        "$in_tcp_last" "$in_udp_last" "$out_tcp_last" "$out_udp_last" "$updated" >> "$tmp"
    mv "$tmp" "$STATS_STATE_FILE"
}

read_stats_state() {
    local port="$1" row
    local c1 c2 c3 c4 c5 c6 c7 c8 c9 c10
    STAT_IN_TCP_TOTAL=0
    STAT_IN_UDP_TOTAL=0
    STAT_OUT_TCP_TOTAL=0
    STAT_OUT_UDP_TOTAL=0
    STAT_IN_TCP_LAST=0
    STAT_IN_UDP_LAST=0
    STAT_OUT_TCP_LAST=0
    STAT_OUT_UDP_LAST=0

    row=$(awk -F '\t' -v p="$port" '$1 == p { line = $0 } END { print line }' "$STATS_STATE_FILE" 2>/dev/null)
    [ -z "$row" ] && return 0

    IFS=$'\t' read -r c1 c2 c3 c4 c5 c6 c7 c8 c9 c10 <<< "$row"
    : "${c1:=}"
    if [ -n "${c10:-}" ]; then
        STAT_IN_TCP_TOTAL=${c2:-0}
        STAT_IN_UDP_TOTAL=${c3:-0}
        STAT_OUT_TCP_TOTAL=${c4:-0}
        STAT_OUT_UDP_TOTAL=${c5:-0}
        STAT_IN_TCP_LAST=${c6:-0}
        STAT_IN_UDP_LAST=${c7:-0}
        STAT_OUT_TCP_LAST=${c8:-0}
        STAT_OUT_UDP_LAST=${c9:-0}
    else
        STAT_IN_TCP_TOTAL=${c2:-0}
        STAT_OUT_TCP_TOTAL=${c3:-0}
        STAT_IN_TCP_LAST=${c4:-0}
        STAT_OUT_TCP_LAST=${c5:-0}
    fi
}

delete_stats_state() {
    local port="$1" tmp
    [ -f "$STATS_STATE_FILE" ] || return 0
    tmp=$(mktemp "${STATS_DIR}/traffic.XXXXXX") || return 1
    awk -F '\t' -v p="$port" '$1 != p { print }' "$STATS_STATE_FILE" > "$tmp"
    mv "$tmp" "$STATS_STATE_FILE"
}

sync_stats_port() {
    local port="$1" updated
    local cur_in_tcp cur_in_udp cur_out_tcp cur_out_udp
    local in_tcp_total in_udp_total out_tcp_total out_udp_total
    local in_tcp_last in_udp_last out_tcp_last out_udp_last

    add_stats_port "$port" || return 1

    read_stats_state "$port"
    in_tcp_total=${STAT_IN_TCP_TOTAL:-0}
    in_udp_total=${STAT_IN_UDP_TOTAL:-0}
    out_tcp_total=${STAT_OUT_TCP_TOTAL:-0}
    out_udp_total=${STAT_OUT_UDP_TOTAL:-0}
    in_tcp_last=${STAT_IN_TCP_LAST:-0}
    in_udp_last=${STAT_IN_UDP_LAST:-0}
    out_tcp_last=${STAT_OUT_TCP_LAST:-0}
    out_udp_last=${STAT_OUT_UDP_LAST:-0}

    cur_in_tcp=$(get_stats_counter "$STATS_IN_CHAIN" "tcp" "dpt:" "$port")
    cur_in_udp=$(get_stats_counter "$STATS_IN_CHAIN" "udp" "dpt:" "$port")
    cur_out_tcp=$(get_stats_counter "$STATS_OUT_CHAIN" "tcp" "spt:" "$port")
    cur_out_udp=$(get_stats_counter "$STATS_OUT_CHAIN" "udp" "spt:" "$port")

    if [ "$cur_in_tcp" -ge "$in_tcp_last" ]; then
        in_tcp_total=$((in_tcp_total + cur_in_tcp - in_tcp_last))
    else
        in_tcp_total=$((in_tcp_total + cur_in_tcp))
    fi

    if [ "$cur_in_udp" -ge "$in_udp_last" ]; then
        in_udp_total=$((in_udp_total + cur_in_udp - in_udp_last))
    else
        in_udp_total=$((in_udp_total + cur_in_udp))
    fi

    if [ "$cur_out_tcp" -ge "$out_tcp_last" ]; then
        out_tcp_total=$((out_tcp_total + cur_out_tcp - out_tcp_last))
    else
        out_tcp_total=$((out_tcp_total + cur_out_tcp))
    fi

    if [ "$cur_out_udp" -ge "$out_udp_last" ]; then
        out_udp_total=$((out_udp_total + cur_out_udp - out_udp_last))
    else
        out_udp_total=$((out_udp_total + cur_out_udp))
    fi

    updated=$(date '+%Y-%m-%d %H:%M:%S')
    set_stats_state "$port" "$in_tcp_total" "$in_udp_total" "$out_tcp_total" "$out_udp_total" \
        "$cur_in_tcp" "$cur_in_udp" "$cur_out_tcp" "$cur_out_udp" "$updated"

    STAT_IN_TCP_TOTAL="$in_tcp_total"
    STAT_IN_UDP_TOTAL="$in_udp_total"
    STAT_OUT_TCP_TOTAL="$out_tcp_total"
    STAT_OUT_UDP_TOTAL="$out_udp_total"
}

sync_config_stats() {
    [ -f "$CONFIG_FILE" ] || return 0
    local line port

    ensure_stats_rules || return 1
    while IFS= read -r line; do
        port=""
        if [[ $line =~ ^[[:space:]]*listen[[:space:]]*=[[:space:]]*mixed://([^:]+):([^@]+)@:([0-9]+) ]]; then
            port="${BASH_REMATCH[3]}"
        elif [[ $line =~ ^[[:space:]]*listen[[:space:]]*=[[:space:]]*mixed://:([0-9]+) ]]; then
            port="${BASH_REMATCH[1]}"
        fi
        [ -n "$port" ] && sync_stats_port "$port" >/dev/null 2>&1
    done < "$CONFIG_FILE"
}

archive_stats_port() {
    local port="$1" user="$2" archived_at safe_user
    local in_total=0 out_total=0
    STAT_IN_TCP_TOTAL=0
    STAT_IN_UDP_TOTAL=0
    STAT_OUT_TCP_TOTAL=0
    STAT_OUT_UDP_TOTAL=0
    sync_stats_port "$port" >/dev/null 2>&1 || true
    mkdir -p "$STATS_DIR"
    safe_user=${user//$'\t'/ }
    archived_at=$(date '+%Y-%m-%d %H:%M:%S')
    in_total=$((${STAT_IN_TCP_TOTAL:-0} + ${STAT_IN_UDP_TOTAL:-0}))
    out_total=$((${STAT_OUT_TCP_TOTAL:-0} + ${STAT_OUT_UDP_TOTAL:-0}))
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$archived_at" "$safe_user" "$port" \
        "${STAT_IN_TCP_TOTAL:-0}" "${STAT_IN_UDP_TOTAL:-0}" \
        "${STAT_OUT_TCP_TOTAL:-0}" "${STAT_OUT_UDP_TOTAL:-0}" \
        "$in_total" "$out_total" >> "$STATS_ARCHIVE_FILE"
}

reset_stats_port() {
    local port="$1"
    remove_stats_port "$port"
    add_stats_port "$port" || return 1
    set_stats_state "$port" 0 0 0 0 0 0 0 0 "$(date '+%Y-%m-%d %H:%M:%S')"
}

move_stats_port() {
    local old_port="$1" new_port="$2"

    STAT_IN_TCP_TOTAL=0
    STAT_IN_UDP_TOTAL=0
    STAT_OUT_TCP_TOTAL=0
    STAT_OUT_UDP_TOTAL=0
    sync_stats_port "$old_port" >/dev/null 2>&1 || true
    remove_stats_port "$old_port"
    delete_stats_state "$old_port"
    add_stats_port "$new_port" || return 1
    set_stats_state "$new_port" \
        "${STAT_IN_TCP_TOTAL:-0}" "${STAT_IN_UDP_TOTAL:-0}" \
        "${STAT_OUT_TCP_TOTAL:-0}" "${STAT_OUT_UDP_TOTAL:-0}" \
        0 0 0 0 "$(date '+%Y-%m-%d %H:%M:%S')"
}

list_users() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "  ${DIM}Нет пользователей${NC}\n"; return
    fi

    local count=1 found=0
    printf "  ${DIM}%-4s %-20s %-20s %-8s${NC}\n" "ID" "ЛОГИН" "ПАРОЛЬ" "ПОРТ"
    echo -e "  ${DIM}────────────────────────────────────────────────────${NC}"

    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*listen[[:space:]]*=[[:space:]]*mixed://([^:]+):([^@]+)@:([0-9]+) ]]; then
            local u="${BASH_REMATCH[1]}" p="${BASH_REMATCH[2]}" port="${BASH_REMATCH[3]}"
            [ ${#u} -gt 20 ] && u="${u:0:17}..."
            [ ${#p} -gt 20 ] && p="${p:0:17}..."
            printf "  ${WHITE}%-4s${NC} ${GREEN}%-20s${NC} ${YELLOW}%-20s${NC} ${CYAN}%-8s${NC}\n" \
                "$count" "$u" "$p" "$port"
            ((count++)); found=1
        elif [[ $line =~ ^[[:space:]]*listen[[:space:]]*=[[:space:]]*mixed://:([0-9]+) ]]; then
            printf "  ${WHITE}%-4s${NC} ${DIM}%-20s${NC} ${DIM}%-20s${NC} ${CYAN}%-8s${NC}\n" \
                "$count" "(без авторизации)" "—" "${BASH_REMATCH[1]}"
            ((count++)); found=1
        fi
    done < "$CONFIG_FILE"

    [ $found -eq 0 ] && echo -e "  ${DIM}Пользователей не найдено${NC}"
    echo ""
}

show_stats_table() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "  ${DIM}Нет пользователей${NC}\n"; return
    fi

    if ! command -v iptables >/dev/null 2>&1; then
        echo -e "  ${RED}iptables не найден. Статистика недоступна.${NC}\n"; return
    fi

    sync_config_stats >/dev/null 2>&1 || true

    local count=1 found=0 line user port in_total out_total total
    printf "  ${DIM}%-4s %-20s %-8s %-12s %-12s %-12s${NC}\n" "ID" "ЛОГИН" "ПОРТ" "ВХОД" "ИСХОД" "ВСЕГО"
    echo -e "  ${DIM}────────────────────────────────────────────────────────────────────────${NC}"

    while IFS= read -r line; do
        user=""; port=""
        if [[ $line =~ ^[[:space:]]*listen[[:space:]]*=[[:space:]]*mixed://([^:]+):([^@]+)@:([0-9]+) ]]; then
            user="${BASH_REMATCH[1]}"; port="${BASH_REMATCH[3]}"
        elif [[ $line =~ ^[[:space:]]*listen[[:space:]]*=[[:space:]]*mixed://:([0-9]+) ]]; then
            user="(без авторизации)"; port="${BASH_REMATCH[1]}"
        fi

        if [ -n "$port" ]; then
            read_stats_state "$port"
            in_total=$((${STAT_IN_TCP_TOTAL:-0} + ${STAT_IN_UDP_TOTAL:-0}))
            out_total=$((${STAT_OUT_TCP_TOTAL:-0} + ${STAT_OUT_UDP_TOTAL:-0}))
            total=$((in_total + out_total))
            [ ${#user} -gt 20 ] && user="${user:0:17}..."
            printf "  ${WHITE}%-4s${NC} ${GREEN}%-20s${NC} ${CYAN}%-8s${NC} ${YELLOW}%-12s${NC} ${YELLOW}%-12s${NC} ${WHITE}%-12s${NC}\n" \
                "$count" "$user" "$port" "$(format_bytes "$in_total")" "$(format_bytes "$out_total")" "$(format_bytes "$total")"
            ((count++)); found=1
        fi
    done < "$CONFIG_FILE"

    [ $found -eq 0 ] && echo -e "  ${DIM}Пользователей не найдено${NC}"
    echo ""
    echo -e "  ${DIM}Вход — трафик к порту пользователя; исход — ответы с этого порта.${NC}"
    echo -e "  ${DIM}Данные сохраняются в ${STATS_STATE_FILE}${NC}"
    echo ""
}

show_stats_detail() {
    local user="$1" port="$2" in_total out_total total

    while true; do
        if ! command -v iptables >/dev/null 2>&1; then
            section "Статистика: ${user}"
            echo -e "  ${RED}iptables не найден. Статистика недоступна.${NC}"
            pause; return
        fi

        sync_stats_port "$port" >/dev/null 2>&1 || true
        read_stats_state "$port"
        in_total=$((${STAT_IN_TCP_TOTAL:-0} + ${STAT_IN_UDP_TOTAL:-0}))
        out_total=$((${STAT_OUT_TCP_TOTAL:-0} + ${STAT_OUT_UDP_TOTAL:-0}))
        total=$((in_total + out_total))

        arrow_menu "Статистика: ${user}  порт ${port}" \
            "Входящий TCP: $(format_bytes "${STAT_IN_TCP_TOTAL:-0}")	— трафик к порту пользователя" \
            "Входящий UDP: $(format_bytes "${STAT_IN_UDP_TOTAL:-0}")	— трафик к порту пользователя" \
            "Исходящий TCP: $(format_bytes "${STAT_OUT_TCP_TOTAL:-0}")	— ответы с порта пользователя" \
            "Исходящий UDP: $(format_bytes "${STAT_OUT_UDP_TOTAL:-0}")	— ответы с порта пользователя" \
            "Всего: $(format_bytes "$total")	— входящий + исходящий" \
            "Сбросить статистику	— обнулить счётчики порта ${port}" \
            "← Назад	"

        case $ARROW_CHOICE in
            5)  arrow_menu "Сбросить статистику?" \
                    "Да, сбросить порт ${port}	— действие необратимо" \
                    "Нет	— вернуться назад"
                [ "$ARROW_CHOICE" -ne 0 ] && continue
                section "Сброс статистики"
                echo ""
                run_with_spinner "Сброс счётчиков..." reset_stats_port "$port"
                echo -e "\n  ${GREEN}✓  Статистика порта ${port} сброшена${NC}"
                pause ;;
            6)  return ;;
        esac
    done
}

show_archived_stats() {
    section "Архив статистики"

    if [ ! -s "$STATS_ARCHIVE_FILE" ]; then
        echo -e "  ${DIM}Архив пуст${NC}"
        pause; return
    fi

    printf "  ${DIM}%-19s %-20s %-8s %-10s %-10s %-10s %-10s${NC}\n" "ДАТА" "ЛОГИН" "ПОРТ" "ВХ.TCP" "ВХ.UDP" "ИСХ.TCP" "ИСХ.UDP"
    echo -e "  ${DIM}────────────────────────────────────────────────────────────────────────────────────────${NC}"

    tail -n 20 "$STATS_ARCHIVE_FILE" | while IFS=$'\t' read -r archived_at user port in_tcp in_udp out_tcp out_udp in_total out_total; do
        [ ${#user} -gt 20 ] && user="${user:0:17}..."
        if [ -z "${out_total:-}" ]; then
            in_total=${in_tcp:-0}
            out_total=${in_udp:-0}
            in_tcp=$in_total
            in_udp=0
            out_tcp=$out_total
            out_udp=0
        fi
        printf "  ${WHITE}%-19s${NC} ${GREEN}%-20s${NC} ${CYAN}%-8s${NC} ${YELLOW}%-10s${NC} ${YELLOW}%-10s${NC} ${YELLOW}%-10s${NC} ${YELLOW}%-10s${NC}\n" \
            "$archived_at" "$user" "$port" "$(format_bytes "${in_tcp:-0}")" "$(format_bytes "${in_udp:-0}")" "$(format_bytes "${out_tcp:-0}")" "$(format_bytes "${out_udp:-0}")"
    done
    pause
}

pick_user() {
    local title="$1"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "  ${DIM}Нет пользователей${NC}"; return 1
    fi

    local labels=()
    local ports=()

    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*listen[[:space:]]*=[[:space:]]*mixed://([^:]+):([^@]+)@:([0-9]+) ]]; then
            labels+=("${BASH_REMATCH[1]}	порт ${BASH_REMATCH[3]}")
            ports+=("${BASH_REMATCH[3]}")
        elif [[ $line =~ ^[[:space:]]*listen[[:space:]]*=[[:space:]]*mixed://:([0-9]+) ]]; then
            labels+=("(без авторизации)	порт ${BASH_REMATCH[1]}")
            ports+=("${BASH_REMATCH[1]}")
        fi
    done < "$CONFIG_FILE"

    [ ${#labels[@]} -eq 0 ] && { echo -e "  ${DIM}Нет пользователей${NC}"; return 1; }

    labels+=("← Назад	")
    arrow_menu "$title" "${labels[@]}"

    if [ "$ARROW_CHOICE" -ge "${#ports[@]}" ]; then
        USER_SEL_PORT=""
        return 1
    fi

    USER_SEL_PORT="${ports[$ARROW_CHOICE]}"
    return 0
}

install_glider() {
    section "Установка Glider"

    if check_glider_installed; then
        echo -e "  ${YELLOW}Glider уже установлен.${NC}"
        echo -e "  ${DIM}Используйте «Обновить» для переустановки.${NC}"
        pause; return
    fi

    while true; do
        prompt "Порт прокси [18443]:"; read -r PROXY_PORT
        PROXY_PORT=${PROXY_PORT:-18443}
        validate_port "$PROXY_PORT" && break; sleep 1
    done

    arrow_menu "Выберите режим аутентификации" \
        "Без пароля	— открытый доступ" \
        "Логин + пароль	— защита учётными данными"
    local auth_choice=$ARROW_CHOICE

    section "Установка Glider"

    if [ "$auth_choice" -eq 1 ]; then
        while true; do
            prompt "Логин:"; read -r PROXY_USER
            validate_credentials "$PROXY_USER" "Логин" && break; sleep 1
        done
        while true; do
            prompt "Пароль:"; read -rs PROXY_PASS; echo
            validate_credentials "$PROXY_PASS" "Пароль" && break; sleep 1
        done
        LISTEN_STRING="listen=mixed://${PROXY_USER}:${PROXY_PASS}@:${PROXY_PORT}"
    else
        LISTEN_STRING="listen=mixed://:${PROXY_PORT}"
    fi

    echo ""
    run_with_spinner "Обновление пакетов..."     apt update
    run_with_spinner "Установка зависимостей..." apt install -y curl wget tar iptables

    cd /tmp || return
    rm -rf glider_* glider.tar.gz glider.deb 2>/dev/null || true

    if run_with_spinner "Скачивание Glider v${VERSION}..." \
        wget -q "https://github.com/nadoo/glider/releases/download/v${VERSION}/glider_${VERSION}_linux_amd64.tar.gz" \
        -O /tmp/glider.tar.gz; then
        run_with_spinner "Распаковка архива..."     tar -xzf /tmp/glider.tar.gz -C /tmp
        run_with_spinner "Копирование бинарника..." copy_binary
    else
        run_with_spinner "Альтернативный метод (deb)..." \
            wget -q "https://github.com/nadoo/glider/releases/download/v${VERSION}/glider_${VERSION}_linux_amd64.deb" \
            -O /tmp/glider.deb
        run_with_spinner "Установка deb-пакета..." \
            bash -c "dpkg -i /tmp/glider.deb && cp /usr/bin/glider $BINARY_PATH && chmod +x $BINARY_PATH"
        run_with_spinner "Исправление зависимостей..." apt --fix-broken install -y
    fi

    if ! check_glider_installed; then
        echo ""
        echo -e "  ${RED}${BOLD}✗  Ошибка установки бинарного файла${NC}"
        echo -e "  ${DIM}Найдено в /tmp:${NC}"
        find /tmp -maxdepth 4 -type f 2>/dev/null | sed 's/^/    /'
        pause; return
    fi

    mkdir -p /etc/glider
    cat > "$CONFIG_FILE" <<EOF
verbose=False

# HTTP + SOCKS5 прокси
${LISTEN_STRING}

# Прямое соединение
forward=direct://

# Проверка доступности
check=http://www.msftconnecttest.com/connecttest.txt#expect=200
checkinterval=30
checktimeout=10

# Стратегия
strategy=rr
EOF

    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Glider Proxy Server
After=network.target

[Service]
Type=simple
ExecStartPre=-$SCRIPT_PATH --sync-stats
ExecStart=$BINARY_PATH -config $CONFIG_FILE
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    run_with_spinner "Регистрация службы..."    systemctl daemon-reload
    run_with_spinner "Включение автозапуска..." systemctl enable glider
    run_with_spinner "Настройка статистики..."  add_stats_port "$PROXY_PORT"
    run_with_spinner "Запуск службы..."         systemctl start glider
    sleep 2
    echo ""

    if systemctl is-active --quiet glider; then
        local IP; IP=$(hostname -I | awk '{print $1}')
        echo -e "  ${GREEN}${BOLD}✓  Установка завершена${NC}\n"
        echo -e "  ${DIM}IP     ${NC}${WHITE}${IP}${NC}"
        echo -e "  ${DIM}Порт   ${NC}${CYAN_BOLD}${PROXY_PORT}${NC}"
        if [ "$auth_choice" -eq 1 ]; then
            echo -e "  ${DIM}Логин  ${NC}${WHITE}${PROXY_USER}${NC}"
            echo -e "  ${DIM}Пароль ${NC}${WHITE}${PROXY_PASS}${NC}"
            echo ""
            echo -e "  ${DIM}HTTP   ${NC}http://${PROXY_USER}:${PROXY_PASS}@${IP}:${PROXY_PORT}"
            echo -e "  ${DIM}SOCKS5 ${NC}socks5://${PROXY_USER}:${PROXY_PASS}@${IP}:${PROXY_PORT}"
        else
            echo ""
            echo -e "  ${DIM}HTTP   ${NC}http://${IP}:${PROXY_PORT}"
            echo -e "  ${DIM}SOCKS5 ${NC}socks5://${IP}:${PROXY_PORT}"
        fi
    else
        echo -e "  ${RED}${BOLD}✗  Служба не запустилась${NC}\n"
        echo -e "  ${DIM}Последние записи журнала:${NC}"
        echo -e "  ${DIM}────────────────────────────────${NC}"
        journalctl -u glider -n 10 --no-pager 2>/dev/null | sed 's/^/  /'
        echo -e "  ${DIM}────────────────────────────────${NC}"
    fi

    pause
}

update_glider() {
    if ! check_glider_installed; then
        section "Обновление Glider"
        echo -e "  ${YELLOW}Glider не установлен.${NC}"; pause; return
    fi

    local cur_ver
    cur_ver=$(get_current_version | tr -d '[:space:]')

    arrow_menu "Обновление Glider" \
        "Обновить до v${VERSION}	— текущая: v${cur_ver}" \
        "← Назад	"

    [ "$ARROW_CHOICE" -ne 0 ] && return

    section "Обновление Glider"
    echo -e "  ${DIM}v${cur_ver}  →  ${NC}${WHITE}v${VERSION}${NC}\n"

    run_with_spinner "Остановка службы..."   systemctl stop glider
    run_with_spinner "Бэкап конфигурации..." cp "$CONFIG_FILE" /tmp/glider.conf.backup

    cd /tmp || return
    rm -rf glider_* glider.tar.gz 2>/dev/null || true

    if run_with_spinner "Скачивание Glider v${VERSION}..." \
        wget -q "https://github.com/nadoo/glider/releases/download/v${VERSION}/glider_${VERSION}_linux_amd64.tar.gz" \
        -O /tmp/glider.tar.gz; then
        run_with_spinner "Распаковка архива..."     tar -xzf /tmp/glider.tar.gz -C /tmp
        run_with_spinner "Копирование бинарника..." copy_binary
    else
        echo -e "\n  ${RED}✗  Ошибка скачивания${NC}"
        run_with_spinner "Восстановление службы..." systemctl start glider
        pause; return
    fi

    run_with_spinner "Восстановление конфига..." cp /tmp/glider.conf.backup "$CONFIG_FILE"
    run_with_spinner "Перезагрузка systemd..."   systemctl daemon-reload
    run_with_spinner "Запуск службы..."          systemctl start glider
    sleep 2
    echo ""

    local new_ver
    new_ver=$(get_current_version | tr -d '[:space:]')

    if systemctl is-active --quiet glider; then
        echo -e "  ${GREEN}${BOLD}✓  Обновлено до v${new_ver}${NC}"
    else
        echo -e "  ${RED}${BOLD}✗  Служба не запустилась после обновления${NC}"
        echo -e "  ${DIM}────────────────────────────────${NC}"
        journalctl -u glider -n 10 --no-pager 2>/dev/null | sed 's/^/  /'
        echo -e "  ${DIM}────────────────────────────────${NC}"
    fi
    pause
}

manage_users() {
    while true; do
        section "Пользователи"

        if ! check_glider_installed; then
            echo -e "  ${YELLOW}Glider не установлен.${NC}"; pause; return
        fi

        list_users

        local user_count=0
        [ -f "$CONFIG_FILE" ] && \
            user_count=$(grep -c "^[[:space:]]*listen=" "$CONFIG_FILE" 2>/dev/null || echo 0)

        arrow_menu "Выберите действие" \
            "Добавить пользователя	— новый логин, пароль, порт" \
            "Изменить пользователя	— редактировать существующего" \
            "Удалить пользователя	— удалить по номеру" \
            "← Назад	"

        case $ARROW_CHOICE in
            0)  section "Добавить пользователя"
                while true; do
                    prompt "Логин:"; read -r NEW_USER
                    validate_credentials "$NEW_USER" "Логин" && break; sleep 1
                done
                while true; do
                    prompt "Пароль:"; read -rs NEW_PASS; echo
                    validate_credentials "$NEW_PASS" "Пароль" && break; sleep 1
                done
                while true; do
                    prompt "Порт:"; read -r NEW_PORT
                    validate_port "$NEW_PORT" || { sleep 1; continue; }
                    check_port_used "$NEW_PORT" && {
                        echo -e "\n  ${RED}✗ Порт занят${NC}"; sleep 1; continue
                    }
                    break
                done
                echo ""
                run_with_spinner "Сохранение конфига..." \
                    sed -i "/^# HTTP + SOCKS5 прокси/a listen=mixed://${NEW_USER}:${NEW_PASS}@:${NEW_PORT}" "$CONFIG_FILE"
                run_with_spinner "Настройка статистики..." add_stats_port "$NEW_PORT"
                run_with_spinner "Перезапуск службы..." systemctl restart glider
                sleep 2; echo ""
                systemctl is-active --quiet glider \
                    && echo -e "  ${GREEN}✓  Добавлен:${NC} ${WHITE}${NEW_USER}${NC}  ${DIM}порт ${NC}${CYAN}${NEW_PORT}${NC}" \
                    || echo -e "  ${RED}✗  Ошибка перезапуска${NC}"
                pause ;;

            1)  [ "$user_count" -eq 0 ] && {
                    echo -e "\n  ${YELLOW}Нет пользователей${NC}"; sleep 2; continue
                }

                pick_user "Выберите пользователя" || continue
                local target_port="$USER_SEL_PORT"

                local user_num; user_num=$(grep -n ":${target_port}" "$CONFIG_FILE" | cut -d: -f1)
                [ -z "$user_num" ] && { echo -e "\n  ${RED}✗ Не найден${NC}"; sleep 2; continue; }
                local line; line=$(sed -n "${user_num}p" "$CONFIG_FILE")

                if [[ $line =~ ^[[:space:]]*listen[[:space:]]*=[[:space:]]*mixed://([^:]+):([^@]+)@:([0-9]+) ]]; then
                    old_username="${BASH_REMATCH[1]}"
                    old_password="${BASH_REMATCH[2]}"
                    old_port="${BASH_REMATCH[3]}"
                else
                    echo -e "\n  ${RED}✗ Ошибка чтения${NC}"; sleep 2; continue
                fi

                section "Изменить пользователя"
                echo -e "  ${DIM}Редактирование:${NC} ${WHITE}${old_username}${NC}  ${DIM}порт ${NC}${CYAN}${old_port}${NC}\n"

                prompt "Новый логин [${old_username}]:";       read -r new_username
                new_username=${new_username:-$old_username}
                validate_credentials "$new_username" "Логин"  || { sleep 2; continue; }
                prompt "Новый пароль [Enter — оставить]:";     read -rs new_password; echo
                new_password=${new_password:-$old_password}
                validate_credentials "$new_password" "Пароль" || { sleep 2; continue; }
                prompt "Новый порт [${old_port}]:";            read -r new_port
                new_port=${new_port:-$old_port}
                validate_port "$new_port"                      || { sleep 2; continue; }
                [ "$new_port" != "$old_port" ] && check_port_used "$new_port" && {
                    echo -e "\n  ${RED}✗ Порт занят${NC}"; sleep 2; continue
                }
                echo ""
                run_with_spinner "Сохранение конфига..." \
                    sed -i "s|^listen=.*:${old_port}$|listen=mixed://${new_username}:${new_password}@:${new_port}|" "$CONFIG_FILE"
                if [ "$new_port" != "$old_port" ]; then
                    run_with_spinner "Перенос статистики..." move_stats_port "$old_port" "$new_port"
                else
                    run_with_spinner "Проверка статистики..." add_stats_port "$new_port"
                fi
                run_with_spinner "Перезапуск службы..." systemctl restart glider || true
                sleep 2; echo ""
                systemctl is-active --quiet glider \
                    && echo -e "  ${GREEN}✓  Изменено${NC}" \
                    || echo -e "  ${RED}✗  Ошибка перезапуска${NC}"
                pause ;;

            2)  [ "$user_count" -le 1 ] && {
                    echo -e "\n  ${RED}✗ Нельзя удалить последнего пользователя${NC}"
                    sleep 2; continue
                }

                pick_user "Выберите пользователя для удаления" || continue
                local del_port="$USER_SEL_PORT"

                local del_line; del_line=$(grep "listen=.*:${del_port}" "$CONFIG_FILE" | head -1)
                [[ $del_line =~ mixed://([^:]+): ]] && del_user="${BASH_REMATCH[1]}" || del_user="noauth"

                arrow_menu "Удалить пользователя?" \
                    "Да, удалить '${del_user}'	— порт ${del_port}" \
                    "Нет	— вернуться назад"
                [ "$ARROW_CHOICE" -ne 0 ] && continue

                section "Удалить пользователя"
                echo ""
                run_with_spinner "Архивация статистики..." archive_stats_port "$del_port" "$del_user"
                run_with_spinner "Удаление статистики..."   remove_stats_port "$del_port"
                delete_stats_state "$del_port"
                run_with_spinner "Удаление из конфига..." sed -i "/^listen=.*:${del_port}/d" "$CONFIG_FILE"
                run_with_spinner "Перезапуск службы..."   systemctl restart glider || true
                sleep 2; echo ""
                systemctl is-active --quiet glider \
                    && echo -e "  ${GREEN}✓  Удалено${NC}" \
                    || echo -e "  ${RED}✗  Ошибка перезапуска${NC}"
                pause ;;

            3) return ;;
        esac
    done
}

manage_stats() {
    while true; do
        section "Статистика"

        if ! check_glider_installed; then
            echo -e "  ${YELLOW}Glider не установлен.${NC}"; pause; return
        fi

        if [ ! -f "$CONFIG_FILE" ]; then
            echo -e "  ${DIM}Нет пользователей${NC}"; pause; return
        fi

        if ! command -v iptables >/dev/null 2>&1; then
            echo -e "  ${RED}iptables не найден. Статистика недоступна.${NC}"
            pause; return
        fi

        sync_config_stats >/dev/null 2>&1 || true

        local labels=()
        local ports=()
        local users=()
        local line user port display_user in_total out_total total

        while IFS= read -r line; do
            user=""; port=""
            if [[ $line =~ ^[[:space:]]*listen[[:space:]]*=[[:space:]]*mixed://([^:]+):([^@]+)@:([0-9]+) ]]; then
                user="${BASH_REMATCH[1]}"; port="${BASH_REMATCH[3]}"
            elif [[ $line =~ ^[[:space:]]*listen[[:space:]]*=[[:space:]]*mixed://:([0-9]+) ]]; then
                user="(без авторизации)"; port="${BASH_REMATCH[1]}"
            fi

            if [ -n "$port" ]; then
                read_stats_state "$port"
                in_total=$((${STAT_IN_TCP_TOTAL:-0} + ${STAT_IN_UDP_TOTAL:-0}))
                out_total=$((${STAT_OUT_TCP_TOTAL:-0} + ${STAT_OUT_UDP_TOTAL:-0}))
                total=$((in_total + out_total))
                display_user="$user"
                [ ${#display_user} -gt 20 ] && display_user="${display_user:0:17}..."
                labels+=("${display_user}	порт ${port}, всего $(format_bytes "$total")")
                users+=("$user")
                ports+=("$port")
            fi
        done < "$CONFIG_FILE"

        if [ ${#labels[@]} -eq 0 ]; then
            echo -e "  ${DIM}Пользователей не найдено${NC}"
            pause; return
        fi

        labels+=("Архив удалённых пользователей	— последние сохранённые значения")
        labels+=("← Назад	")

        arrow_menu "Пользователи" "${labels[@]}"

        if [ "$ARROW_CHOICE" -lt "${#ports[@]}" ]; then
            show_stats_detail "${users[$ARROW_CHOICE]}" "${ports[$ARROW_CHOICE]}"
        elif [ "$ARROW_CHOICE" -eq "${#ports[@]}" ]; then
            show_archived_stats
        else
            return
        fi
    done
}

update_script() {
    arrow_menu "Обновление скрипта" \
        "Загрузить последнюю версию	— текущий файл будет заменён" \
        "← Назад	"

    [ "$ARROW_CHOICE" -ne 0 ] && return

    section "Обновление скрипта"
    echo ""

    local TEMP_SCRIPT
    TEMP_SCRIPT=$(mktemp)
    run_with_spinner "Скачивание новой версии..." wget -q "$SCRIPT_URL" -O "$TEMP_SCRIPT"

    if [ ! -s "$TEMP_SCRIPT" ]; then
        echo -e "\n  ${RED}✗  Файл пуст или не скачался${NC}"
        rm -f "$TEMP_SCRIPT"; pause; return
    fi

    run_with_spinner "Резервная копия..."  cp "$SCRIPT_PATH" "${SCRIPT_PATH}.backup"
    run_with_spinner "Установка..."        bash -c "cp $TEMP_SCRIPT $SCRIPT_PATH && chmod +x $SCRIPT_PATH"
    rm -f "$TEMP_SCRIPT"

    echo -e "\n  ${GREEN}✓  Скрипт обновлён. Перезапуск...${NC}"
    sleep 2
    exec "$SCRIPT_PATH" "$@"
}

remove_glider() {
    if ! check_glider_installed; then
        section "Удалить Glider"
        echo -e "  ${YELLOW}Glider не установлен.${NC}"; pause; return
    fi

    arrow_menu "Удалить Glider?" \
        "Да, удалить полностью	— бинарник, конфиг, служба" \
        "Нет	— вернуться в меню"

    [ "$ARROW_CHOICE" -ne 0 ] && return

    section "Удалить Glider"
    echo ""

    run_with_spinner "Остановка службы..."        systemctl stop glider
    run_with_spinner "Отключение автозапуска..."  systemctl disable glider
    run_with_spinner "Удаление статистики..."     remove_stats_rules
    run_with_spinner "Удаление файлов..."         bash -c "rm -f $BINARY_PATH $SERVICE_FILE && rm -rf /etc/glider $STATS_DIR"
    run_with_spinner "Перезагрузка systemd..."    systemctl daemon-reload

    echo -e "\n  ${GREEN}${BOLD}✓  Glider полностью удалён${NC}"
    pause
}

show_menu() {
    local ver svc status_line

    if check_glider_installed; then
        ver=$(get_current_version | tr -d '[:space:]')
        svc=$(systemctl is-active glider 2>/dev/null | tr -d '[:space:]')
        svc=${svc:-stopped}
        if [ "$svc" == "active" ]; then
            status_line="${CYAN_BOLD}GliderProxy${NC}  ${DIM}|${NC}  ${GREEN}● running${NC}  ${DIM}v${ver}${NC}"
        else
            status_line="${CYAN_BOLD}GliderProxy${NC}  ${DIM}|${NC}  ${RED}● ${svc}${NC}  ${DIM}v${ver}${NC}"
        fi
    else
        status_line="${CYAN_BOLD}GliderProxy${NC}  ${DIM}|${NC}  ${DIM}не установлен${NC}"
    fi

    local items=(
        "Установить Glider	— скачать и настроить прокси-сервер"
        "Обновить Glider	— установить новую версию"
        "Пользователи	— управление доступом"
        "Статистика	— входящий и исходящий трафик по портам"
        "Обновить скрипт	— загрузить последнюю версию менеджера"
        "Удалить Glider	— полное удаление"
        "Выход	"
    )
    local count=${#items[@]} selected=0

    tput civis

    _render_main() {
        clear
        echo ""
        echo -e "  ${status_line}"
        echo -e "  ${DIM}────────────────────────────────${NC}"
        echo ""
        for i in "${!items[@]}"; do
            local raw="${items[$i]}"
            local label="${raw%%	*}"
            local desc=""
            [[ "$raw" == *$'\t'* ]] && desc="${raw#*	}"
            if [ "$i" -eq "$selected" ]; then
                [ -n "$desc" ] \
                    && echo -e "  ${CYAN_BOLD}► ${BOLD}${label}${NC}  ${ITALIC}${MUTED}${desc}${NC}" \
                    || echo -e "  ${CYAN_BOLD}► ${BOLD}${label}${NC}"
            else
                [ -n "$desc" ] \
                    && echo -e "  ${MUTED}  ${label}${NC}  ${DIM}${desc}${NC}" \
                    || echo -e "  ${MUTED}  ${label}${NC}"
            fi
        done
        echo ""
        echo -e "  ${DIM}↑↓ — навигация   Enter — выбор${NC}"
    }

    while true; do
        _render_main
        IFS= read -rsn1 key
        if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 -t 0.1 rest
            case "$rest" in
                '[A') ((selected--)); [ "$selected" -lt 0 ] && selected=$((count-1)) ;;
                '[B') ((selected++)); [ "$selected" -ge "$count" ] && selected=0 ;;
            esac
        elif [[ "$key" == "" || "$key" == $'\n' ]]; then
            break
        fi
    done

    tput cnorm
    ARROW_CHOICE=$selected

    case $ARROW_CHOICE in
        0) install_glider ;;
        1) update_glider  ;;
        2) manage_users   ;;
        3) manage_stats   ;;
        4) update_script "$@" ;;
        5) remove_glider  ;;
        6) tput cnorm; clear; exit 0 ;;
    esac
}

run_cli_command "$1"
check_root
while true; do
    show_menu "$@"
done
