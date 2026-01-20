#!/bin/bash

# Скрипт управления Glider Proxy Server
# Использование: glider

set -e

CONFIG_FILE="/etc/glider/glider.conf"
SERVICE_FILE="/etc/systemd/system/glider.service"
BINARY_PATH="/usr/local/bin/glider-bin"
SCRIPT_PATH="/usr/local/bin/glider-manager"
SCRIPT_URL="https://raw.githubusercontent.com/thekhabaroff/GliderProxy/main/glider.sh"
VERSION="0.16.4"

# Расширенная цветовая палитра
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
LIGHT_BLUE='\033[1;34m'
LIGHT_GREEN='\033[1;32m'
LIGHT_CYAN='\033[1;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Эмодзи и иконки
ICON_ROCKET="🚀"
ICON_CHECK="✓"
ICON_CROSS="✗"
ICON_ARROW="→"
ICON_GEAR="⚙"
ICON_USER="👤"
ICON_TRASH="🗑"
ICON_UPDATE="⬆"
ICON_WARNING="⚠"
ICON_INFO="ℹ"

# Улучшенная анимация загрузки
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local temp
    
    while kill -0 $pid 2>/dev/null; do
        temp=${spinstr#?}
        printf " [${CYAN}%c${NC}]  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Красивое выполнение с анимацией
run_with_spinner() {
    local message=$1
    shift
    printf "${CYAN}${message}${NC}"
    ("$@") > /dev/null 2>&1 &
    spinner $!
    wait $!
    local status=$?
    if [ $status -eq 0 ]; then
        echo -e " ${GREEN}${ICON_CHECK}${NC}"
    else
        echo -e " ${RED}${ICON_CROSS}${NC}"
        return $status
    fi
}

# Функция для рисования линии
draw_line() {
    local char="${1:-─}"
    local width="${2:-60}"
    printf "${CYAN}"
    printf "%${width}s" | tr ' ' "$char"
    printf "${NC}\n"
}

# Красивый заголовок
print_header() {
    clear
    echo ""
    echo -e "${PURPLE}${BOLD}"
    echo "    ╔══════════════════════════════════════════════════════════╗"
    echo "    ║                                                          ║"
    echo "    ║       ${ICON_ROCKET}  ${LIGHT_CYAN}GLIDER PROXY MANAGER${PURPLE}  ${ICON_ROCKET}                    ║"
    echo "    ║                                                          ║"
    echo "    ╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Проверка root прав
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        clear
        echo ""
        echo -e "${RED}${BOLD}"
        echo "    ╔══════════════════════════════════════════════════════════╗"
        echo "    ║                                                          ║"
        echo "    ║                  ${ICON_WARNING}  ОШИБКА ДОСТУПА  ${ICON_WARNING}                     ║"
        echo "    ║                                                          ║"
        echo "    ╚══════════════════════════════════════════════════════════╝"
        echo -e "${NC}"
        echo ""
        echo -e "    ${YELLOW}Для запуска требуются права суперпользователя${NC}"
        echo ""
        echo -e "    ${CYAN}Используйте:${NC} ${GREEN}sudo glider${NC}"
        echo ""
        exit 1
    fi
}

# Проверка установки Glider
check_glider_installed() {
    if [ -f "$BINARY_PATH" ]; then
        return 0
    else
        return 1
    fi
}

# Получение текущей версии
get_current_version() {
    if check_glider_installed; then
        $BINARY_PATH -help 2>&1 | grep -o "glider [0-9.]*" | awk '{print $2}' || echo "0.16.4"
    else
        echo "не установлен"
    fi
}

# Красивое отображение списка пользователей
list_users() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo ""
        echo -e "    ${YELLOW}${DIM}Пользователей не найдено${NC}"
        echo ""
        return
    fi

    local count=1
    local found=0

    echo ""
    while IFS= read -r line; do
        if [[ $line =~ ^listen=mixed://([^:]+):([^@]+)@:([0-9]+) ]]; then
            username="${BASH_REMATCH[1]}"
            password="${BASH_REMATCH[2]}"
            port="${BASH_REMATCH[3]}"

            echo -e "    ${LIGHT_CYAN}╭─────────────────────────────────────────────────────────╮${NC}"
            echo -e "    ${LIGHT_CYAN}│${NC} ${BOLD}${ICON_USER} Пользователь #${count}${NC}                                      ${LIGHT_CYAN}│${NC}"
            echo -e "    ${LIGHT_CYAN}├─────────────────────────────────────────────────────────┤${NC}"
            echo -e "    ${LIGHT_CYAN}│${NC}  ${GRAY}Логин:${NC}    ${GREEN}${username}${NC}"
            echo -e "    ${LIGHT_CYAN}│${NC}  ${GRAY}Пароль:${NC}   ${GREEN}${password}${NC}"
            echo -e "    ${LIGHT_CYAN}│${NC}  ${GRAY}Порт:${NC}     ${GREEN}${port}${NC}"
            echo -e "    ${LIGHT_CYAN}│${NC}"
            echo -e "    ${LIGHT_CYAN}│${NC}  ${GRAY}HTTP:${NC}     ${BLUE}http://${username}:${password}@$(hostname -I | awk '{print $1}'):${port}${NC}"
            echo -e "    ${LIGHT_CYAN}│${NC}  ${GRAY}SOCKS5:${NC}   ${BLUE}socks5://${username}:${password}@$(hostname -I | awk '{print $1}'):${port}${NC}"
            echo -e "    ${LIGHT_CYAN}╰─────────────────────────────────────────────────────────╯${NC}"
            echo ""
            ((count++))
            found=1
        elif [[ $line =~ ^listen=mixed://:([0-9]+) ]]; then
            port="${BASH_REMATCH[1]}"

            echo -e "    ${LIGHT_CYAN}╭─────────────────────────────────────────────────────────╮${NC}"
            echo -e "    ${LIGHT_CYAN}│${NC} ${BOLD}Порт без аутентификации #${count}${NC}                          ${LIGHT_CYAN}│${NC}"
            echo -e "    ${LIGHT_CYAN}├─────────────────────────────────────────────────────────┤${NC}"
            echo -e "    ${LIGHT_CYAN}│${NC}  ${GRAY}Порт:${NC} ${GREEN}${port}${NC}"
            echo -e "    ${LIGHT_CYAN}╰─────────────────────────────────────────────────────────╯${NC}"
            echo ""
            ((count++))
            found=1
        fi
    done < "$CONFIG_FILE"

    if [ $found -eq 0 ]; then
        echo -e "    ${YELLOW}${DIM}Пользователей не найдено${NC}"
        echo ""
    fi
}

# Проверка занятости порта
check_port_used() {
    local port=$1
    if [ -f "$CONFIG_FILE" ] && grep -q ":${port}\$" "$CONFIG_FILE" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Обновление скрипта
update_script() {
    print_header
    echo ""
    echo -e "    ${LIGHT_BLUE}${BOLD}${ICON_UPDATE} ОБНОВЛЕНИЕ СКРИПТА${NC}"
    echo ""
    draw_line "─" 60
    echo ""

    echo -e "    ${YELLOW}${ICON_WARNING} Будет загружена последняя версия скрипта${NC}"
    echo ""
    read -p "    Продолжить обновление? (y/n): " CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        return
    fi

    echo ""
    draw_line "─" 60
    echo ""

    # Скачиваем новую версию во временный файл
    TEMP_SCRIPT=$(mktemp)

    printf "    ${CYAN}Скачивание новой версии...${NC}"
    if wget -q "$SCRIPT_URL" -O "$TEMP_SCRIPT" 2>/dev/null; then
        echo -e " ${GREEN}${ICON_CHECK}${NC}"
    else
        echo -e " ${RED}${ICON_CROSS}${NC}"
        echo ""
        echo -e "    ${RED}Ошибка скачивания новой версии${NC}"
        rm -f "$TEMP_SCRIPT"
        echo ""
        read -p "    Нажмите Enter для продолжения..."
        return
    fi

    # Проверяем что файл не пустой
    if [ ! -s "$TEMP_SCRIPT" ]; then
        echo -e "    ${RED}Скачанный файл пуст!${NC}"
        rm -f "$TEMP_SCRIPT"
        echo ""
        read -p "    Нажмите Enter для продолжения..."
        return
    fi

    # Создаём резервную копию
    printf "    ${CYAN}Создание резервной копии...${NC}"
    cp "$SCRIPT_PATH" "${SCRIPT_PATH}.backup"
    echo -e " ${GREEN}${ICON_CHECK}${NC}"

    # Устанавливаем новую версию
    printf "    ${CYAN}Установка новой версии...${NC}"
    cp "$TEMP_SCRIPT" "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"
    rm -f "$TEMP_SCRIPT"
    echo -e " ${GREEN}${ICON_CHECK}${NC}"

    echo ""
    draw_line "─" 60
    echo ""
    echo -e "    ${GREEN}${BOLD}${ICON_CHECK} Скрипт успешно обновлён!${NC}"
    echo ""
    echo -e "    ${YELLOW}Перезапуск скрипта через 2 секунды...${NC}"
    echo ""
    sleep 2

    # Перезапускаем скрипт с помощью exec
    exec "$SCRIPT_PATH" "$@"
}

# Установка Glider
install_glider() {
    print_header
    echo ""
    echo -e "    ${GREEN}${BOLD}${ICON_GEAR} УСТАНОВКА GLIDER${NC}"
    echo ""
    draw_line "─" 60
    echo ""

    if check_glider_installed; then
        echo -e "    ${YELLOW}${ICON_WARNING} Glider уже установлен${NC}"
        echo -e "    ${CYAN}Используйте 'Обновить' для переустановки${NC}"
        echo ""
        read -p "    Нажмите Enter для продолжения..."
        return
    fi

    # Запрос параметров для первого пользователя
    echo -e "    ${CYAN}${ICON_ARROW} Настройка первого пользователя${NC}"
    echo ""
    read -p "    Введите порт для прокси [18443]: " PROXY_PORT
    PROXY_PORT=${PROXY_PORT:-18443}

    read -p "    Добавить аутентификацию? (y/n) [n]: " ADD_AUTH
    ADD_AUTH=${ADD_AUTH:-n}

    if [[ "$ADD_AUTH" == "y" || "$ADD_AUTH" == "Y" ]]; then
        read -p "    Введите логин: " PROXY_USER
        read -sp "    Введите пароль: " PROXY_PASS
        echo
        LISTEN_STRING="listen=mixed://${PROXY_USER}:${PROXY_PASS}@:${PROXY_PORT}"
    else
        LISTEN_STRING="listen=mixed://:${PROXY_PORT}"
    fi

    echo ""
    draw_line "─" 60
    echo ""
    echo -e "    ${CYAN}Начинается установка...${NC}"
    echo ""

    # Установка зависимостей
    run_with_spinner "    Обновление списка пакетов..." apt update
    run_with_spinner "    Установка зависимостей..." apt install curl wget tar -y

    # Скачивание Glider
    cd /tmp
    rm -rf glider_* glider.tar.gz glider.deb 2>/dev/null || true

    run_with_spinner "    Скачивание Glider v${VERSION}..." wget -q "https://github.com/nadoo/glider/releases/download/v${VERSION}/glider_${VERSION}_linux_amd64.tar.gz" -O glider.tar.gz

    if [ $? -ne 0 ]; then
        echo -e "    ${YELLOW}Попытка альтернативного метода...${NC}"
        run_with_spinner "    Скачивание deb пакета..." wget -q "https://github.com/nadoo/glider/releases/download/v${VERSION}/glider_${VERSION}_linux_amd64.deb" -O glider.deb
        run_with_spinner "    Установка deb пакета..." bash -c "dpkg -i glider.deb && mv /usr/bin/glider $BINARY_PATH 2>/dev/null || true"
        run_with_spinner "    Исправление зависимостей..." apt --fix-broken install -y
    else
        run_with_spinner "    Распаковка архива..." tar -xzf glider.tar.gz
        run_with_spinner "    Установка бинарного файла..." bash -c "find . -name 'glider' -type f -exec cp {} $BINARY_PATH \; && chmod +x $BINARY_PATH"
    fi

    # Проверка установки
    if ! check_glider_installed; then
        echo -e "    ${RED}${ICON_CROSS} Ошибка установки бинарного файла${NC}"
        read -p "    Нажмите Enter для продолжения..."
        return
    fi

    # Создание конфигурации
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

    run_with_spinner "    Создание конфигурации..." sleep 0.5

    # Создание systemd службы
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

    run_with_spinner "    Создание systemd службы..." sleep 0.5

    # Запуск службы
    run_with_spinner "    Перезагрузка systemd..." systemctl daemon-reload
    run_with_spinner "    Включение автозапуска..." systemctl enable glider
    run_with_spinner "    Запуск службы..." systemctl start glider

    sleep 2

    echo ""
    draw_line "─" 60
    echo ""

    if systemctl is-active --quiet glider; then
        echo -e "${GREEN}${BOLD}"
        echo "    ╔══════════════════════════════════════════════════════════╗"
        echo "    ║                                                          ║"
        echo "    ║         ${ICON_CHECK} УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО! ${ICON_CHECK}              ║"
        echo "    ║                                                          ║"
        echo "    ╚══════════════════════════════════════════════════════════╝"
        echo -e "${NC}"
        echo ""
        echo -e "    ${GRAY}Порт:${NC}    ${GREEN}$PROXY_PORT${NC}"
        echo -e "    ${GRAY}IP:${NC}      ${GREEN}$(hostname -I | awk '{print $1}')${NC}"

        if [[ "$ADD_AUTH" == "y" || "$ADD_AUTH" == "Y" ]]; then
            echo ""
            echo -e "    ${GRAY}Логин:${NC}   ${GREEN}$PROXY_USER${NC}"
            echo -e "    ${GRAY}Пароль:${NC}  ${GREEN}$PROXY_PASS${NC}"
            echo ""
            echo -e "    ${CYAN}HTTP прокси:${NC}"
            echo -e "    ${BLUE}http://${PROXY_USER}:${PROXY_PASS}@$(hostname -I | awk '{print $1}'):${PROXY_PORT}${NC}"
            echo ""
            echo -e "    ${CYAN}SOCKS5 прокси:${NC}"
            echo -e "    ${BLUE}socks5://${PROXY_USER}:${PROXY_PASS}@$(hostname -I | awk '{print $1}'):${PROXY_PORT}${NC}"
            echo ""
            echo -e "    ${CYAN}Пример использования:${NC}"
            echo -e "    ${DIM}curl -x http://${PROXY_USER}:${PROXY_PASS}@$(hostname -I | awk '{print $1}'):${PROXY_PORT} https://ifconfig.me${NC}"
        else
            echo ""
            echo -e "    ${CYAN}HTTP прокси:${NC}  ${BLUE}http://$(hostname -I | awk '{print $1}'):${PROXY_PORT}${NC}"
            echo -e "    ${CYAN}SOCKS5 прокси:${NC} ${BLUE}socks5://$(hostname -I | awk '{print $1}'):${PROXY_PORT}${NC}"
            echo ""
            echo -e "    ${CYAN}Пример использования:${NC}"
            echo -e "    ${DIM}curl -x http://$(hostname -I | awk '{print $1}'):${PROXY_PORT} https://ifconfig.me${NC}"
        fi

        echo ""
        echo -e "    ${GRAY}Управление:${NC} ${DIM}systemctl {start|stop|restart|status} glider${NC}"
    else
        echo -e "${RED}${BOLD}"
        echo "    ╔══════════════════════════════════════════════════════════╗"
        echo "    ║                                                          ║"
        echo "    ║         ${ICON_CROSS} ОШИБКА: СЛУЖБА НЕ ЗАПУСТИЛАСЬ ${ICON_CROSS}           ║"
        echo "    ║                                                          ║"
        echo "    ╚══════════════════════════════════════════════════════════╝"
        echo -e "${NC}"
        echo ""
        echo -e "    ${YELLOW}Проверьте логи:${NC} ${DIM}journalctl -u glider -n 50${NC}"
    fi

    echo ""
    read -p "    Нажмите Enter для продолжения..."
}

# Обновление Glider
update_glider() {
    print_header
    echo ""
    echo -e "    ${GREEN}${BOLD}${ICON_UPDATE} ОБНОВЛЕНИЕ GLIDER${NC}"
    echo ""
    draw_line "─" 60
    echo ""

    if ! check_glider_installed; then
        echo -e "    ${YELLOW}${ICON_WARNING} Glider не установлен${NC}"
        echo -e "    ${CYAN}Используйте 'Установить'${NC}"
        echo ""
        read -p "    Нажмите Enter для продолжения..."
        return
    fi

    CURRENT_VERSION=$(get_current_version)
    echo -e "    ${GRAY}Текущая версия:${NC} ${GREEN}$CURRENT_VERSION${NC}"
    echo -e "    ${GRAY}Новая версия:${NC}   ${GREEN}$VERSION${NC}"
    echo ""

    read -p "    Продолжить обновление? (y/n): " CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        return
    fi

    echo ""
    draw_line "─" 60
    echo ""

    run_with_spinner "    Остановка службы..." systemctl stop glider
    run_with_spinner "    Резервное копирование конфигурации..." cp $CONFIG_FILE /tmp/glider.conf.backup

    cd /tmp
    rm -rf glider_* glider.tar.gz 2>/dev/null || true

    run_with_spinner "    Скачивание Glider v${VERSION}..." wget -q "https://github.com/nadoo/glider/releases/download/v${VERSION}/glider_${VERSION}_linux_amd64.tar.gz" -O glider.tar.gz

    if [ $? -eq 0 ]; then
        run_with_spinner "    Распаковка архива..." tar -xzf glider.tar.gz
        run_with_spinner "    Установка бинарного файла..." bash -c "find . -name 'glider' -type f -exec cp {} $BINARY_PATH \; && chmod +x $BINARY_PATH"
    else
        echo -e "    ${RED}${ICON_CROSS} Ошибка скачивания${NC}"
        systemctl start glider > /dev/null 2>&1
        read -p "    Нажмите Enter для продолжения..."
        return
    fi

    run_with_spinner "    Восстановление конфигурации..." cp /tmp/glider.conf.backup $CONFIG_FILE
    run_with_spinner "    Запуск службы..." systemctl start glider

    sleep 2

    echo ""
    draw_line "─" 60
    echo ""

    if systemctl is-active --quiet glider; then
        echo -e "    ${GREEN}${BOLD}${ICON_CHECK} Обновление завершено успешно!${NC}"
        echo -e "    ${GRAY}Новая версия:${NC} ${GREEN}$(get_current_version)${NC}"
    else
        echo -e "    ${RED}${ICON_CROSS} Ошибка запуска после обновления${NC}"
    fi

    echo ""
    read -p "    Нажмите Enter для продолжения..."
}

# Управление пользователями
manage_users() {
    while true; do
        print_header
        echo ""
        echo -e "    ${BLUE}${BOLD}${ICON_USER} УПРАВЛЕНИЕ ПОЛЬЗОВАТЕЛЯМИ${NC}"
        echo ""
        draw_line "─" 60

        if ! check_glider_installed; then
            echo ""
            echo -e "    ${YELLOW}${ICON_WARNING} Glider не установлен${NC}"
            echo ""
            read -p "    Нажмите Enter для продолжения..."
            return
        fi

        # Показываем список пользователей
        list_users

        # Подсчёт пользователей
        local user_count=0
        if [ -f "$CONFIG_FILE" ]; then
            user_count=$(grep -c "^listen=" "$CONFIG_FILE" 2>/dev/null || echo "0")
        fi

        echo -e "    ${LIGHT_CYAN}╭─────────────────────────────────────────────────────────╮${NC}"
        echo -e "    ${LIGHT_CYAN}│${NC}                                                         ${LIGHT_CYAN}│${NC}"
        echo -e "    ${LIGHT_CYAN}│${NC}   ${GREEN}1.${NC} Добавить пользователя                             ${LIGHT_CYAN}│${NC}"
        echo -e "    ${LIGHT_CYAN}│${NC}   ${YELLOW}2.${NC} Изменить пользователя                             ${LIGHT_CYAN}│${NC}"
        echo -e "    ${LIGHT_CYAN}│${NC}   ${RED}3.${NC} Удалить пользователя                              ${LIGHT_CYAN}│${NC}"
        echo -e "    ${LIGHT_CYAN}│${NC}   ${MAGENTA}4.${NC} Назад                                             ${LIGHT_CYAN}│${NC}"
        echo -e "    ${LIGHT_CYAN}│${NC}                                                         ${LIGHT_CYAN}│${NC}"
        echo -e "    ${LIGHT_CYAN}╰─────────────────────────────────────────────────────────╯${NC}"
        echo ""
        read -p "    $(echo -e ${CYAN}Выберите действие ${GREEN}[1-4]${CYAN}: ${NC})" action

        case $action in
            1)
                # Добавление пользователя
                echo ""
                echo -e "    ${CYAN}${ICON_ARROW} Создание нового пользователя${NC}"
                echo ""
                read -p "    Введите новый логин: " NEW_USER

                if [ -z "$NEW_USER" ]; then
                    echo -e "    ${RED}${ICON_CROSS} Логин не может быть пустым${NC}"
                    sleep 2
                    continue
                fi

                read -sp "    Введите новый пароль: " NEW_PASS
                echo

                if [ -z "$NEW_PASS" ]; then
                    echo -e "    ${RED}${ICON_CROSS} Пароль не может быть пустым${NC}"
                    sleep 2
                    continue
                fi

                read -p "    Введите порт для этого пользователя: " NEW_PORT

                if [ -z "$NEW_PORT" ]; then
                    echo -e "    ${RED}${ICON_CROSS} Порт не может быть пустым${NC}"
                    sleep 2
                    continue
                fi

                # Проверка занятости порта
                if check_port_used "$NEW_PORT"; then
                    echo ""
                    echo -e "    ${RED}${ICON_CROSS} Порт $NEW_PORT уже используется!${NC}"
                    sleep 2
                    continue
                fi

                echo ""
                run_with_spinner "    Добавление пользователя..." sed -i "/^# HTTP + SOCKS5 прокси/a listen=mixed://${NEW_USER}:${NEW_PASS}@:${NEW_PORT}" $CONFIG_FILE
                run_with_spinner "    Перезапуск службы..." systemctl restart glider

                sleep 2

                echo ""
                if systemctl is-active --quiet glider; then
                    echo -e "    ${GREEN}${BOLD}${ICON_CHECK} Пользователь добавлен успешно!${NC}"
                    echo ""
                    echo -e "    ${GRAY}Логин:${NC}   ${GREEN}$NEW_USER${NC}"
                    echo -e "    ${GRAY}Пароль:${NC}  ${GREEN}$NEW_PASS${NC}"
                    echo -e "    ${GRAY}Порт:${NC}    ${GREEN}$NEW_PORT${NC}"
                else
                    echo -e "    ${RED}${ICON_CROSS} Ошибка при добавлении пользователя${NC}"
                fi

                echo ""
                read -p "    Нажмите Enter для продолжения..."
                ;;

            2)
                # Изменение пользователя
                if [ "$user_count" -eq 0 ]; then
                    echo ""
                    echo -e "    ${YELLOW}Нет пользователей для изменения${NC}"
                    sleep 2
                    continue
                fi

                echo ""
                read -p "    Введите номер пользователя для изменения: " user_num

                if ! [[ "$user_num" =~ ^[0-9]+$ ]] || [ "$user_num" -lt 1 ] || [ "$user_num" -gt "$user_count" ]; then
                    echo -e "    ${RED}${ICON_CROSS} Неверный номер${NC}"
                    sleep 2
                    continue
                fi

                # Получаем данные пользователя
                local line=$(grep "^listen=" "$CONFIG_FILE" | sed -n "${user_num}p")

                if [[ $line =~ ^listen=mixed://([^:]+):([^@]+)@:([0-9]+) ]]; then
                    old_username="${BASH_REMATCH[1]}"
                    old_password="${BASH_REMATCH[2]}"
                    old_port="${BASH_REMATCH[3]}"
                else
                    echo -e "    ${RED}${ICON_CROSS} Ошибка чтения данных пользователя${NC}"
                    sleep 2
                    continue
                fi

                echo ""
                echo -e "    ${CYAN}${ICON_ARROW} Изменение пользователя${NC}"
                echo ""
                read -p "    Новый логин [$old_username]: " new_username
                new_username=${new_username:-$old_username}
                read -sp "    Новый пароль [оставить текущий]: " new_password
                echo
                new_password=${new_password:-$old_password}
                read -p "    Новый порт [$old_port]: " new_port
                new_port=${new_port:-$old_port}

                if [ "$new_port" != "$old_port" ] && check_port_used "$new_port"; then
                    echo ""
                    echo -e "    ${RED}${ICON_CROSS} Порт $new_port уже используется!${NC}"
                    sleep 2
                    continue
                fi

                echo ""
                run_with_spinner "    Изменение пользователя..." sed -i "s|^listen=.*:${old_port}\$|listen=mixed://${new_username}:${new_password}@:${new_port}|" $CONFIG_FILE
                run_with_spinner "    Перезапуск службы..." systemctl restart glider

                sleep 2

                if systemctl is-active --quiet glider; then
                    echo ""
                    echo -e "    ${GREEN}${BOLD}${ICON_CHECK} Пользователь изменён успешно!${NC}"
                else
                    echo ""
                    echo -e "    ${RED}${ICON_CROSS} Ошибка при изменении${NC}"
                fi

                echo ""
                read -p "    Нажмите Enter для продолжения..."
                ;;

            3)
                # Удаление пользователя
                if [ "$user_count" -eq 0 ]; then
                    echo ""
                    echo -e "    ${YELLOW}Нет пользователей для удаления${NC}"
                    sleep 2
                    continue
                fi

                if [ "$user_count" -le 1 ]; then
                    echo ""
                    echo -e "    ${RED}${ICON_CROSS} Нельзя удалить последнего пользователя!${NC}"
                    echo -e "    ${YELLOW}Используйте 'Удалить Glider' для полного удаления${NC}"
                    sleep 2
                    continue
                fi

                echo ""
                read -p "    Введите номер пользователя для удаления: " user_num

                if ! [[ "$user_num" =~ ^[0-9]+$ ]] || [ "$user_num" -lt 1 ] || [ "$user_num" -gt "$user_count" ]; then
                    echo -e "    ${RED}${ICON_CROSS} Неверный номер${NC}"
                    sleep 2
                    continue
                fi

                # Получаем данные пользователя
                local line=$(grep "^listen=" "$CONFIG_FILE" | sed -n "${user_num}p")

                if [[ $line =~ :([0-9]+)$ ]]; then
                    port="${BASH_REMATCH[1]}"
                else
                    echo -e "    ${RED}${ICON_CROSS} Ошибка чтения порта${NC}"
                    sleep 2
                    continue
                fi

                if [[ $line =~ ^listen=mixed://([^:]+): ]]; then
                    username="${BASH_REMATCH[1]}"
                else
                    username="noauth"
                fi

                echo ""
                read -p "    Удалить пользователя '$username' на порту $port? (y/n): " CONFIRM
                if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
                    continue
                fi

                echo ""
                run_with_spinner "    Удаление пользователя..." sed -i "/^listen=.*:${port}\$/d" $CONFIG_FILE
                run_with_spinner "    Перезапуск службы..." systemctl restart glider

                sleep 2

                if systemctl is-active --quiet glider; then
                    echo ""
                    echo -e "    ${GREEN}${BOLD}${ICON_CHECK} Пользователь удалён!${NC}"
                else
                    echo ""
                    echo -e "    ${RED}${ICON_CROSS} Ошибка при удалении${NC}"
                fi

                echo ""
                read -p "    Нажмите Enter для продолжения..."
                ;;

            4)
                # Назад
                return
                ;;

            *)
                echo -e "    ${RED}${ICON_CROSS} Неверный выбор${NC}"
                sleep 1
                ;;
        esac
    done
}

# Полное удаление Glider
remove_glider() {
    print_header
    echo ""
    echo -e "    ${RED}${BOLD}${ICON_TRASH} УДАЛЕНИЕ GLIDER${NC}"
    echo ""
    draw_line "─" 60
    echo ""

    if ! check_glider_installed; then
        echo -e "    ${YELLOW}${ICON_WARNING} Glider не установлен${NC}"
        echo ""
        read -p "    Нажмите Enter для продолжения..."
        return
    fi

    echo -e "    ${YELLOW}${ICON_WARNING} ВНИМАНИЕ: Все данные и пользователи будут удалены!${NC}"
    echo ""
    read -p "    Вы уверены, что хотите удалить Glider? (y/n): " CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        return
    fi

    echo ""
    draw_line "─" 60
    echo ""

    # Остановка службы
    run_with_spinner "    Остановка службы Glider..." systemctl stop glider 2>/dev/null || true
    
    # Отключение автозапуска
    run_with_spinner "    Отключение автозапуска..." systemctl disable glider 2>/dev/null || true
    
    # Удаление unit файла systemd
    run_with_spinner "    Удаление systemd unit файла..." rm -f "$SERVICE_FILE"
    
    # Удаление символических ссылок
    run_with_spinner "    Удаление символических ссылок..." bash -c "rm -f /etc/systemd/system/multi-user.target.wants/glider.service 2>/dev/null || true"
    
    # Удаление бинарного файла
    run_with_spinner "    Удаление исполняемого файла..." rm -f "$BINARY_PATH"
    
    # Удаление конфигурационных файлов
    run_with_spinner "    Удаление конфигурации..." rm -rf /etc/glider
    
    # Удаление временных файлов
    run_with_spinner "    Очистка временных файлов..." bash -c "rm -f /tmp/glider* 2>/dev/null || true"
    
    # Перезагрузка systemd для применения изменений
    run_with_spinner "    Перезагрузка systemd..." systemctl daemon-reload
    
    # Сброс состояния failed служб
    run_with_spinner "    Сброс состояния служб..." systemctl reset-failed 2>/dev/null || true

    echo ""
    draw_line "─" 60
    echo ""
    echo -e "    ${GREEN}${BOLD}${ICON_CHECK} Glider полностью удалён из системы!${NC}"
    echo ""
    echo -e "    ${CYAN}${ICON_INFO} Удалённые компоненты:${NC}"
    echo -e "      ${DIM}• Служба systemd (glider.service)${NC}"
    echo -e "      ${DIM}• Исполняемый файл ($BINARY_PATH)${NC}"
    echo -e "      ${DIM}• Конфигурационные файлы (/etc/glider/)${NC}"
    echo -e "      ${DIM}• Символические ссылки служб${NC}"
    echo -e "      ${DIM}• Временные файлы${NC}"
    echo ""
    read -p "    Нажмите Enter для продолжения..."
}

# Главное меню
show_menu() {
    print_header
    
    echo ""
    if check_glider_installed; then
        CURRENT_VERSION=$(get_current_version)
        STATUS=$(systemctl is-active glider 2>/dev/null || echo "остановлена")
        
        echo -e "    ${LIGHT_CYAN}╭─────────────────────────────────────────────────────────╮${NC}"
        echo -e "    ${LIGHT_CYAN}│${NC} ${BOLD}Информация о системе${NC}                                    ${LIGHT_CYAN}│${NC}"
        echo -e "    ${LIGHT_CYAN}├─────────────────────────────────────────────────────────┤${NC}"
        echo -e "    ${LIGHT_CYAN}│${NC}  ${GRAY}Статус:${NC}  $([ "$STATUS" == "active" ] && echo -e "${GREEN}● Установлен${NC} ${DIM}(v$CURRENT_VERSION)${NC}" || echo -e "${RED}● Установлен${NC} ${DIM}(v$CURRENT_VERSION)${NC}")            ${LIGHT_CYAN}│${NC}"
        echo -e "    ${LIGHT_CYAN}│${NC}  ${GRAY}Служба:${NC}  $([ "$STATUS" == "active" ] && echo -e "${GREEN}● Запущена${NC}" || echo -e "${RED}● Остановлена${NC}")                            ${LIGHT_CYAN}│${NC}"
        echo -e "    ${LIGHT_CYAN}╰─────────────────────────────────────────────────────────╯${NC}"
    else
        echo -e "    ${LIGHT_CYAN}╭─────────────────────────────────────────────────────────╮${NC}"
        echo -e "    ${LIGHT_CYAN}│${NC} ${BOLD}Информация о системе${NC}                                    ${LIGHT_CYAN}│${NC}"
        echo -e "    ${LIGHT_CYAN}├─────────────────────────────────────────────────────────┤${NC}"
        echo -e "    ${LIGHT_CYAN}│${NC}  ${GRAY}Статус:${NC}  ${YELLOW}● Не установлен${NC}                             ${LIGHT_CYAN}│${NC}"
        echo -e "    ${LIGHT_CYAN}╰─────────────────────────────────────────────────────────╯${NC}"
    fi

    echo ""
    echo -e "    ${LIGHT_CYAN}╭─────────────────────────────────────────────────────────╮${NC}"
    echo -e "    ${LIGHT_CYAN}│${NC} ${BOLD}Доступные действия${NC}                                      ${LIGHT_CYAN}│${NC}"
    echo -e "    ${LIGHT_CYAN}├─────────────────────────────────────────────────────────┤${NC}"
    echo -e "    ${LIGHT_CYAN}│${NC}                                                         ${LIGHT_CYAN}│${NC}"
    echo -e "    ${LIGHT_CYAN}│${NC}   ${GREEN}1.${NC} ${ICON_GEAR}  Установить Glider                              ${LIGHT_CYAN}│${NC}"
    echo -e "    ${LIGHT_CYAN}│${NC}   ${BLUE}2.${NC} ${ICON_UPDATE}  Обновить Glider                                ${LIGHT_CYAN}│${NC}"
    echo -e "    ${LIGHT_CYAN}│${NC}   ${YELLOW}3.${NC} ${ICON_USER}  Управление пользователями                      ${LIGHT_CYAN}│${NC}"
    echo -e "    ${LIGHT_CYAN}│${NC}   ${BLUE}4.${NC} ${ICON_UPDATE}  Обновить скрипт                                ${LIGHT_CYAN}│${NC}"
    echo -e "    ${LIGHT_CYAN}│${NC}   ${RED}5.${NC} ${ICON_TRASH}  Удалить Glider                                 ${LIGHT_CYAN}│${NC}"
    echo -e "    ${LIGHT_CYAN}│${NC}   ${MAGENTA}6.${NC} 🚪  Выход                                          ${LIGHT_CYAN}│${NC}"
    echo -e "    ${LIGHT_CYAN}│${NC}                                                         ${LIGHT_CYAN}│${NC}"
    echo -e "    ${LIGHT_CYAN}╰─────────────────────────────────────────────────────────╯${NC}"
    echo ""
    read -p "    $(echo -e ${CYAN}Выберите действие ${GREEN}[1-6]${CYAN}: ${NC})" choice

    case $choice in
        1) install_glider ;;
        2) update_glider ;;
        3) manage_users ;;
        4) update_script ;;
        5) remove_glider ;;
        6) clear; echo ""; echo -e "    ${GREEN}${BOLD}Спасибо за использование Glider Manager! ${ICON_ROCKET}${NC}"; echo ""; exit 0 ;;
        *) echo -e "    ${RED}${ICON_CROSS} Неверный выбор${NC}"; sleep 1 ;;
    esac
}

# Основной цикл
check_root

while true; do
    show_menu
done
