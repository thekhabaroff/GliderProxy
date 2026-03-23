#!/bin/bash

CONFIG_FILE="/etc/glider/glider.conf"
SERVICE_FILE="/etc/systemd/system/glider.service"
BINARY_PATH="/usr/local/bin/glider-bin"
SCRIPT_PATH="/usr/local/bin/glider-manager"
SCRIPT_URL="https://raw.githubusercontent.com/thekhabaroff/GliderProxy/main/glider.sh"
VERSION="0.16.4"

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
pause()   { echo -e "\n\n  ${DIM}Нажмите Enter для продолжения...${NC}"; read; }

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
        prompt "Порт прокси [18443]:"; read PROXY_PORT
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
            prompt "Логин:"; read PROXY_USER
            validate_credentials "$PROXY_USER" "Логин" && break; sleep 1
        done
        while true; do
            prompt "Пароль:"; read -s PROXY_PASS; echo
            validate_credentials "$PROXY_PASS" "Пароль" && break; sleep 1
        done
        LISTEN_STRING="listen=mixed://${PROXY_USER}:${PROXY_PASS}@:${PROXY_PORT}"
    else
        LISTEN_STRING="listen=mixed://:${PROXY_PORT}"
    fi

    echo ""
    run_with_spinner "Обновление пакетов..."     apt update
    run_with_spinner "Установка зависимостей..." apt install -y curl wget tar

    cd /tmp || return
    rm -rf glider_* glider.tar.gz glider.deb 2>/dev/null || true

    run_with_spinner "Скачивание Glider v${VERSION}..." \
        wget -q "https://github.com/nadoo/glider/releases/download/v${VERSION}/glider_${VERSION}_linux_amd64.tar.gz" \
        -O /tmp/glider.tar.gz

    if [ $? -eq 0 ]; then
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
ExecStart=$BINARY_PATH -config $CONFIG_FILE
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    run_with_spinner "Регистрация службы..."    systemctl daemon-reload
    run_with_spinner "Включение автозапуска..." systemctl enable glider
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

    run_with_spinner "Скачивание Glider v${VERSION}..." \
        wget -q "https://github.com/nadoo/glider/releases/download/v${VERSION}/glider_${VERSION}_linux_amd64.tar.gz" \
        -O /tmp/glider.tar.gz

    if [ $? -eq 0 ]; then
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
                    prompt "Логин:"; read NEW_USER
                    validate_credentials "$NEW_USER" "Логин" && break; sleep 1
                done
                while true; do
                    prompt "Пароль:"; read -s NEW_PASS; echo
                    validate_credentials "$NEW_PASS" "Пароль" && break; sleep 1
                done
                while true; do
                    prompt "Порт:"; read NEW_PORT
                    validate_port "$NEW_PORT" || { sleep 1; continue; }
                    check_port_used "$NEW_PORT" && {
                        echo -e "\n  ${RED}✗ Порт занят${NC}"; sleep 1; continue
                    }
                    break
                done
                echo ""
                run_with_spinner "Сохранение конфига..." \
                    sed -i "/^# HTTP + SOCKS5 прокси/a listen=mixed://${NEW_USER}:${NEW_PASS}@:${NEW_PORT}" "$CONFIG_FILE"
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

                prompt "Новый логин [${old_username}]:";       read new_username
                new_username=${new_username:-$old_username}
                validate_credentials "$new_username" "Логин"  || { sleep 2; continue; }
                prompt "Новый пароль [Enter — оставить]:";     read -s new_password; echo
                new_password=${new_password:-$old_password}
                validate_credentials "$new_password" "Пароль" || { sleep 2; continue; }
                prompt "Новый порт [${old_port}]:";            read new_port
                new_port=${new_port:-$old_port}
                validate_port "$new_port"                      || { sleep 2; continue; }
                [ "$new_port" != "$old_port" ] && check_port_used "$new_port" && {
                    echo -e "\n  ${RED}✗ Порт занят${NC}"; sleep 2; continue
                }
                echo ""
                run_with_spinner "Сохранение конфига..." \
                    sed -i "s|^listen=.*:${old_port}$|listen=mixed://${new_username}:${new_password}@:${new_port}|" "$CONFIG_FILE"
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
    run_with_spinner "Удаление файлов..."         bash -c "rm -f $BINARY_PATH $SERVICE_FILE && rm -rf /etc/glider"
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
        3) update_script  ;;
        4) remove_glider  ;;
        5) tput cnorm; clear; exit 0 ;;
    esac
}

check_root
while true; do
    show_menu
done
