#!/bin/bash

# Скрипт управления Glider Proxy Server

CONFIG_FILE="/etc/glider/glider.conf"
SERVICE_FILE="/etc/systemd/system/glider.service"
BINARY_PATH="/usr/local/bin/glider-bin"
SCRIPT_PATH="/usr/local/bin/glider-manager"
SCRIPT_URL="https://raw.githubusercontent.com/thekhabaroff/GliderProxy/main/glider.sh"
VERSION="0.16.4"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ──────────────────────────────────────────────
#  Навигационное меню стрелками
#  Возвращает: номер выбранного пункта в $ARROW_CHOICE
# ──────────────────────────────────────────────
arrow_menu() {
    local title="$1"
    shift
    local items=("$@")
    local count=${#items[@]}
    local selected=0

    tput civis  # скрыть курсор

    _draw_menu() {
        clear
        echo ""
        echo -e "  ${CYAN}${BOLD}$title${NC}"
        echo -e "  ${DIM}────────────────────────────────${NC}"
        echo ""
        for i in "${!items[@]}"; do
            if [ "$i" -eq "$selected" ]; then
                echo -e "  ${CYAN}›${NC} ${WHITE}${BOLD}${items[$i]}${NC}"
            else
                echo -e "  ${DIM}  ${items[$i]}${NC}"
            fi
        done
        echo ""
        echo -e "  ${DIM}↑↓ — навигация   Enter — выбор${NC}"
    }

    while true; do
        _draw_menu

        IFS= read -rsn1 key
        if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 -t 0.1 key2
            case "$key2" in
                '[A') ((selected--)); [ "$selected" -lt 0 ] && selected=$((count - 1)) ;;
                '[B') ((selected++)); [ "$selected" -ge "$count" ] && selected=0 ;;
            esac
        elif [[ "$key" == "" || "$key" == $'\n' ]]; then
            break
        fi
    done

    tput cnorm  # показать курсор
    ARROW_CHOICE=$selected
}

# ──────────────────────────────────────────────
#  Вспомогательные функции
# ──────────────────────────────────────────────

spinner() {
    local pid=$1
    local delay=0.08
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    while ps -p $pid > /dev/null 2>&1; do
        printf " ${CYAN}%s${NC}" "${frames[$i]}"
        i=$(( (i+1) % ${#frames[@]} ))
        sleep $delay
        printf "\b\b\b"
    done
    printf "   \b\b\b"
}

run_with_spinner() {
    local message=$1
    shift
    printf "  ${DIM}${message}${NC}"
    ("$@") > /dev/null 2>&1 &
    spinner $!
    wait $!
    local status=$?
    if [ $status -eq 0 ]; then
        echo -e " ${GREEN}✓${NC}"
    else
        echo -e " ${RED}✗${NC}"
        return $status
    fi
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        clear
        echo ""
        echo -e "  ${RED}${BOLD}Ошибка доступа${NC}"
        echo -e "  ${DIM}Требуются права root${NC}"
        echo ""
        echo -e "  Запустите: ${CYAN}sudo glider${NC}"
        echo ""
        exit 1
    fi
}

validate_credentials() {
    local value="$1"
    local name="$2"
    if [[ "$value" =~ [@:/] ]]; then
        echo -e "  ${RED}✗ ${name} не должен содержать @, : или /${NC}"
        return 1
    fi
    if [ -z "$value" ]; then
        echo -e "  ${RED}✗ ${name} не может быть пустым${NC}"
        return 1
    fi
    return 0
}

validate_port() {
    local port="$1"
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        echo -e "  ${RED}✗ Порт должен быть числом от 1 до 65535${NC}"
        return 1
    fi
    return 0
}

check_glider_installed() {
    [ -f "$BINARY_PATH" ]
}

get_current_version() {
    if check_glider_installed; then
        $BINARY_PATH -help 2>&1 | grep -o "glider [0-9.]*" | awk '{print $2}' || echo "$VERSION"
    else
        echo "—"
    fi
}

prompt() {
    echo -ne "  ${DIM}$1${NC} "
}

pause() {
    echo ""
    echo -ne "  ${DIM}Нажмите Enter для продолжения...${NC}"
    read
}

section() {
    clear
    echo ""
    echo -e "  ${CYAN}${BOLD}$1${NC}"
    echo -e "  ${DIM}────────────────────────────────${NC}"
    echo ""
}

# ──────────────────────────────────────────────
#  Список пользователей
# ──────────────────────────────────────────────
list_users() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "  ${DIM}Нет пользователей${NC}"
        return
    fi

    local count=1
    local found=0

    printf "  ${DIM}%-4s %-20s %-20s %-8s${NC}\n" "ID" "ЛОГИН" "ПАРОЛЬ" "ПОРТ"
    echo -e "  ${DIM}────────────────────────────────────────────────────${NC}"

    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*listen[[:space:]]*=[[:space:]]*mixed://([^:]+):([^@]+)@:([0-9]+) ]]; then
            local u="${BASH_REMATCH[1]}" p="${BASH_REMATCH[2]}" port="${BASH_REMATCH[3]}"
            [ ${#u} -gt 20 ] && u="${u:0:17}..."
            [ ${#p} -gt 20 ] && p="${p:0:17}..."
            printf "  ${WHITE}%-4s${NC} ${GREEN}%-20s${NC} ${YELLOW}%-20s${NC} ${CYAN}%-8s${NC}\n" "$count" "$u" "$p" "$port"
            ((count++)); found=1
        elif [[ $line =~ ^[[:space:]]*listen[[:space:]]*=[[:space:]]*mixed://:([0-9]+) ]]; then
            local port="${BASH_REMATCH[1]}"
            printf "  ${WHITE}%-4s${NC} ${DIM}%-20s${NC} ${DIM}%-20s${NC} ${CYAN}%-8s${NC}\n" "$count" "(без авторизации)" "—" "$port"
            ((count++)); found=1
        fi
    done < "$CONFIG_FILE"

    [ $found -eq 0 ] && echo -e "  ${DIM}Пользователей не найдено${NC}"
    echo ""
}

check_port_used() {
    local port=$1
    if [ -f "$CONFIG_FILE" ] && grep -q ":${port}$" "$CONFIG_FILE" 2>/dev/null; then return 0; fi
    if command -v ss >/dev/null 2>&1; then
        ss -tuln | grep -q ":${port} " && return 0
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tuln | grep -q ":${port} " && return 0
    fi
    return 1
}

# ──────────────────────────────────────────────
#  Установка Glider
# ──────────────────────────────────────────────
install_glider() {
    section "Установка Glider"

    if check_glider_installed; then
        echo -e "  ${YELLOW}Glider уже установлен.${NC}"
        echo -e "  ${DIM}Используйте «Обновить» для переустановки.${NC}"
        pause; return
    fi

    while true; do
        prompt "Порт прокси [18443]:"
        read PROXY_PORT
        PROXY_PORT=${PROXY_PORT:-18443}
        validate_port "$PROXY_PORT" && break
        sleep 1
    done

    arrow_menu "Аутентификация" "Без пароля" "Логин + пароль"
    local auth_choice=$ARROW_CHOICE

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
    run_with_spinner "Обновление пакетов..." apt update
    run_with_spinner "Установка зависимостей..." apt install curl wget tar -y

    cd /tmp; rm -rf glider_* glider.tar.gz glider.deb 2>/dev/null || true

    run_with_spinner "Скачивание Glider v${VERSION}..." wget -q \
        "https://github.com/nadoo/glider/releases/download/v${VERSION}/glider_${VERSION}_linux_amd64.tar.gz" -O glider.tar.gz

    if [ $? -ne 0 ]; then
        run_with_spinner "Альтернативный метод (deb)..." wget -q \
            "https://github.com/nadoo/glider/releases/download/v${VERSION}/glider_${VERSION}_linux_amd64.deb" -O glider.deb
        run_with_spinner "Установка deb..." bash -c "dpkg -i glider.deb && mv /usr/bin/glider $BINARY_PATH 2>/dev/null || true"
        run_with_spinner "Исправление зависимостей..." apt --fix-broken install -y
    else
        run_with_spinner "Распаковка..." tar -xzf glider.tar.gz
        run_with_spinner "Копирование бинарника..." bash -c "find . -name 'glider' -type f -exec cp {} $BINARY_PATH \; && chmod +x $BINARY_PATH"
    fi

    if ! check_glider_installed; then
        echo -e "\n  ${RED}✗ Ошибка установки${NC}"; pause; return
    fi

    mkdir -p /etc/glider
    cat > $CONFIG_FILE <<EOF
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

    cat > $SERVICE_FILE <<EOF
[Unit]
Description=Glider Proxy Server
After=network.target

[Service]
Type=simple
ExecStart=$BINARY_PATH -config $CONFIG_FILE
Restart=on-failure
RestartSec=5
User=nobody
StandardOutput=null
StandardError=null

[Install]
WantedBy=multi-user.target
EOF

    run_with_spinner "Регистрация службы..." systemctl daemon-reload
    run_with_spinner "Включение автозапуска..." systemctl enable glider
    run_with_spinner "Запуск..." systemctl start glider

    sleep 2
    echo ""

    if systemctl is-active --quiet glider; then
        local IP=$(hostname -I | awk '{print $1}')
        echo -e "  ${GREEN}${BOLD}✓ Установка завершена${NC}"
        echo ""
        echo -e "  ${DIM}IP     ${NC}${WHITE}$IP${NC}"
        echo -e "  ${DIM}Порт   ${NC}${CYAN}$PROXY_PORT${NC}"
        if [ "$auth_choice" -eq 1 ]; then
            echo -e "  ${DIM}Логин  ${NC}${WHITE}$PROXY_USER${NC}"
            echo -e "  ${DIM}Пароль ${NC}${WHITE}$PROXY_PASS${NC}"
            echo ""
            echo -e "  ${DIM}HTTP   ${NC}http://${PROXY_USER}:${PROXY_PASS}@${IP}:${PROXY_PORT}"
            echo -e "  ${DIM}SOCKS5 ${NC}socks5://${PROXY_USER}:${PROXY_PASS}@${IP}:${PROXY_PORT}"
        else
            echo ""
            echo -e "  ${DIM}HTTP   ${NC}http://${IP}:${PROXY_PORT}"
            echo -e "  ${DIM}SOCKS5 ${NC}socks5://${IP}:${PROXY_PORT}"
        fi
    else
        echo -e "  ${RED}✗ Служба не запустилась${NC}"
        echo -e "  ${DIM}Лог: journalctl -u glider -n 50${NC}"
    fi

    pause
}

# ──────────────────────────────────────────────
#  Обновление Glider
# ──────────────────────────────────────────────
update_glider() {
    section "Обновление Glider"

    if ! check_glider_installed; then
        echo -e "  ${YELLOW}Glider не установлен.${NC}"; pause; return
    fi

    echo -e "  ${DIM}Текущая версия:${NC} $(get_current_version)"
    echo -e "  ${DIM}Новая версия:  ${NC} $VERSION"
    echo ""
    prompt "Продолжить? (y/n):"; read CONFIRM
    [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]] && return

    echo ""
    run_with_spinner "Остановка службы..." systemctl stop glider
    run_with_spinner "Бэкап конфигурации..." cp $CONFIG_FILE /tmp/glider.conf.backup

    cd /tmp; rm -rf glider_* glider.tar.gz 2>/dev/null || true

    run_with_spinner "Скачивание Glider v${VERSION}..." wget -q \
        "https://github.com/nadoo/glider/releases/download/v${VERSION}/glider_${VERSION}_linux_amd64.tar.gz" -O glider.tar.gz

    if [ $? -eq 0 ]; then
        run_with_spinner "Распаковка..." tar -xzf glider.tar.gz
        run_with_spinner "Копирование бинарника..." bash -c "find . -name 'glider' -type f -exec cp {} $BINARY_PATH \; && chmod +x $BINARY_PATH"
    else
        echo -e "  ${RED}✗ Ошибка скачивания${NC}"
        systemctl start glider > /dev/null 2>&1
        pause; return
    fi

    run_with_spinner "Восстановление конфигурации..." cp /tmp/glider.conf.backup $CONFIG_FILE
    run_with_spinner "Запуск службы..." systemctl start glider
    sleep 2

    echo ""
    if systemctl is-active --quiet glider; then
        echo -e "  ${GREEN}✓ Обновлено до $(get_current_version)${NC}"
    else
        echo -e "  ${RED}✗ Ошибка после обновления${NC}"
    fi
    pause
}

# ──────────────────────────────────────────────
#  Управление пользователями
# ──────────────────────────────────────────────
manage_users() {
    while true; do
        section "Пользователи"

        if ! check_glider_installed; then
            echo -e "  ${YELLOW}Glider не установлен.${NC}"; pause; return
        fi

        list_users

        local user_count=0
        [ -f "$CONFIG_FILE" ] && user_count=$(grep -c "^[[:space:]]*listen=" "$CONFIG_FILE" 2>/dev/null || echo 0)

        arrow_menu "Действие" \
            "Добавить пользователя" \
            "Изменить пользователя" \
            "Удалить пользователя" \
            "← Назад"

        case $ARROW_CHOICE in
            0) # Добавить
                section "Добавить пользователя"

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
                    if check_port_used "$NEW_PORT"; then
                        echo -e "  ${RED}✗ Порт $NEW_PORT занят${NC}"; sleep 1; continue
                    fi
                    break
                done

                echo ""
                run_with_spinner "Сохранение..." sed -i "/^# HTTP + SOCKS5 прокси/a listen=mixed://${NEW_USER}:${NEW_PASS}@:${NEW_PORT}" $CONFIG_FILE
                run_with_spinner "Перезапуск..." systemctl restart glider
                sleep 2

                echo ""
                if systemctl is-active --quiet glider; then
                    echo -e "  ${GREEN}✓ Пользователь добавлен${NC}"
                    echo -e "  ${DIM}Логин ${NC}$NEW_USER  ${DIM}Порт ${NC}$NEW_PORT"
                else
                    echo -e "  ${RED}✗ Ошибка${NC}"
                fi
                pause
                ;;

            1) # Изменить
                if [ "$user_count" -eq 0 ]; then
                    echo -e "\n  ${YELLOW}Нет пользователей${NC}"; sleep 2; continue
                fi

                section "Изменить пользователя"
                list_users

                prompt "Введите порт пользователя:"; read target_port
                [ -z "$target_port" ] && continue

                local user_num=$(grep -n ":${target_port}$" "$CONFIG_FILE" | cut -d: -f1)
                if [ -z "$user_num" ]; then
                    echo -e "  ${RED}✗ Не найден${NC}"; sleep 2; continue
                fi

                local line=$(sed -n "${user_num}p" "$CONFIG_FILE")
                if [[ $line =~ ^[[:space:]]*listen[[:space:]]*=[[:space:]]*mixed://([^:]+):([^@]+)@:([0-9]+) ]]; then
                    old_username="${BASH_REMATCH[1]}"
                    old_password="${BASH_REMATCH[2]}"
                    old_port="${BASH_REMATCH[3]}"
                else
                    echo -e "  ${RED}✗ Ошибка чтения${NC}"; sleep 2; continue
                fi

                echo ""
                prompt "Новый логин [$old_username]:"; read new_username
                new_username=${new_username:-$old_username}
                if ! validate_credentials "$new_username" "Логин"; then sleep 2; continue; fi

                prompt "Новый пароль [Enter — оставить]:"; read -s new_password; echo
                new_password=${new_password:-$old_password}
                if ! validate_credentials "$new_password" "Пароль"; then sleep 2; continue; fi

                prompt "Новый порт [$old_port]:"; read new_port
                new_port=${new_port:-$old_port}
                if ! validate_port "$new_port"; then sleep 2; continue; fi

                if [ "$new_port" != "$old_port" ] && check_port_used "$new_port"; then
                    echo -e "  ${RED}✗ Порт занят${NC}"; sleep 2; continue
                fi

                echo ""
                run_with_spinner "Сохранение..." sed -i "s|^listen=.*:${old_port}$|listen=mixed://${new_username}:${new_password}@:${new_port}|" $CONFIG_FILE
                run_with_spinner "Перезапуск..." systemctl restart glider || true
                sleep 2

                systemctl is-active --quiet glider \
                    && echo -e "\n  ${GREEN}✓ Изменено${NC}" \
                    || echo -e "\n  ${RED}✗ Ошибка${NC}"
                pause
                ;;

            2) # Удалить
                if [ "$user_count" -le 1 ]; then
                    echo -e "\n  ${RED}✗ Нельзя удалить последнего пользователя${NC}"; sleep 2; continue
                fi

                section "Удалить пользователя"
                list_users

                prompt "Введите номер пользователя:"; read user_num
                if ! [[ "$user_num" =~ ^[0-9]+$ ]] || [ "$user_num" -lt 1 ] || [ "$user_num" -gt "$user_count" ]; then
                    echo -e "  ${RED}✗ Неверный номер${NC}"; sleep 2; continue
                fi

                local line=$(grep "^[[:space:]]*listen=" "$CONFIG_FILE" | sed -n "${user_num}p")
                [[ $line =~ :([0-9]+)[[:space:]]*$ ]] && port="${BASH_REMATCH[1]}" || { echo -e "  ${RED}✗ Ошибка${NC}"; sleep 2; continue; }
                [[ $line =~ mixed://([^:]+): ]] && username="${BASH_REMATCH[1]}" || username="noauth"

                echo ""
                prompt "Удалить '$username' (порт $port)? (y/n):"; read CONFIRM
                [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]] && continue

                echo ""
                run_with_spinner "Удаление..." sed -i "/^listen=.*:${port}$/d" $CONFIG_FILE
                run_with_spinner "Перезапуск..." systemctl restart glider || true
                sleep 2

                systemctl is-active --quiet glider \
                    && echo -e "\n  ${GREEN}✓ Удалено${NC}" \
                    || echo -e "\n  ${RED}✗ Ошибка${NC}"
                pause
                ;;

            3) return ;;
        esac
    done
}

# ──────────────────────────────────────────────
#  Обновление скрипта
# ──────────────────────────────────────────────
update_script() {
    section "Обновление скрипта"

    prompt "Загрузить последнюю версию? (y/n):"; read CONFIRM
    [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]] && return

    echo ""
    TEMP_SCRIPT=$(mktemp)

    run_with_spinner "Скачивание..." wget -q "$SCRIPT_URL" -O "$TEMP_SCRIPT"
    if [ ! -s "$TEMP_SCRIPT" ]; then
        echo -e "  ${RED}✗ Файл пуст или не скачался${NC}"; rm -f "$TEMP_SCRIPT"; pause; return
    fi

    run_with_spinner "Резервная копия..." cp "$SCRIPT_PATH" "${SCRIPT_PATH}.backup"
    run_with_spinner "Установка..." bash -c "cp $TEMP_SCRIPT $SCRIPT_PATH && chmod +x $SCRIPT_PATH"
    rm -f "$TEMP_SCRIPT"

    echo ""
    echo -e "  ${GREEN}✓ Скрипт обновлён. Перезапуск...${NC}"
    sleep 2
    exec "$SCRIPT_PATH" "$@"
}

# ──────────────────────────────────────────────
#  Удаление Glider
# ──────────────────────────────────────────────
remove_glider() {
    section "Удалить Glider"

    if ! check_glider_installed; then
        echo -e "  ${YELLOW}Glider не установлен.${NC}"; pause; return
    fi

    echo -e "  ${RED}Все данные и пользователи будут удалены!${NC}"
    echo ""
    prompt "Вы уверены? (y/n):"; read CONFIRM
    [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]] && return

    echo ""
    run_with_spinner "Остановка..." systemctl stop glider
    run_with_spinner "Отключение автозапуска..." systemctl disable glider
    run_with_spinner "Удаление файлов..." bash -c "rm -f $BINARY_PATH $SERVICE_FILE && rm -rf /etc/glider"
    run_with_spinner "Перезагрузка systemd..." systemctl daemon-reload

    echo ""
    echo -e "  ${GREEN}✓ Glider удалён${NC}"
    pause
}

# ──────────────────────────────────────────────
#  Главное меню
# ──────────────────────────────────────────────
show_menu() {
    local status_line
    if check_glider_installed; then
        local ver=$(get_current_version)
        local svc=$(systemctl is-active glider 2>/dev/null || echo "—")
        if [ "$svc" == "active" ]; then
            status_line="${GREEN}● active${NC}  v${ver}"
        else
            status_line="${RED}● $svc${NC}  v${ver}"
        fi
    else
        status_line="${DIM}не установлен${NC}"
    fi

    local TITLE="GliderProxy  ${DIM}│${NC}  $status_line"

    arrow_menu "$(echo -e $TITLE)" \
        "Установить Glider" \
        "Обновить Glider" \
        "Пользователи" \
        "Обновить скрипт" \
        "Удалить Glider" \
        "Выход"

    case $ARROW_CHOICE in
        0) install_glider ;;
        1) update_glider ;;
        2) manage_users ;;
        3) update_script ;;
        4) remove_glider ;;
        5) tput cnorm; clear; exit 0 ;;
    esac
}

# ──────────────────────────────────────────────
check_root
while true; do
    show_menu
done
