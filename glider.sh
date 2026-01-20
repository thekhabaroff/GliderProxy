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

# Цвета для вывода
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

# Проверка поддержки UTF-8
check_utf8_support() {
    local charset=$(locale charmap 2>/dev/null || echo "")
    if [[ "$charset" == "UTF-8" ]] && [[ "$LANG" == *"UTF-8"* || "$LANG" == *"utf8"* ]]; then
        return 0
    else
        return 1
    fi
}

# Определяем поддержку UTF-8
if check_utf8_support; then
    USE_UTF8=true
    # UTF-8 иконки и символы
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
    ICON_DOOR="🚪"
    
    # UTF-8 box drawing
    BOX_H="─"
    BOX_V="│"
    BOX_TL="╭"
    BOX_TR="╮"
    BOX_BL="╰"
    BOX_BR="╯"
    BOX_VR="├"
    BOX_VL="┤"
    BOX_HU="┴"
    BOX_HD="┬"
else
    USE_UTF8=false
    # ASCII иконки
    ICON_ROCKET="[*]"
    ICON_CHECK="[OK]"
    ICON_CROSS="[X]"
    ICON_ARROW=">"
    ICON_GEAR="[#]"
    ICON_USER="[@]"
    ICON_TRASH="[DEL]"
    ICON_UPDATE="[^]"
    ICON_WARNING="[!]"
    ICON_INFO="[i]"
    ICON_DOOR="[EXIT]"
    
    # ASCII box drawing
    BOX_H="-"
    BOX_V="|"
    BOX_TL="+"
    BOX_TR="+"
    BOX_BL="+"
    BOX_BR="+"
    BOX_VR="+"
    BOX_VL="+"
    BOX_HU="+"
    BOX_HD="+"
fi

# Улучшенная анимация загрузки
spinner() {
    local pid=$1
    local delay=0.1
    
    if $USE_UTF8; then
        local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    else
        local spinstr='|/-\'
    fi
    
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
    local char="${1:-$BOX_H}"
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
    printf "    %c" "$BOX_TL"
    printf "%58s" | tr ' ' "$BOX_H"
    printf "%c\n" "$BOX_TR"
    
    printf "    %c" "$BOX_V"
    printf "%58s" " "
    printf "%c\n" "$BOX_V"
    
    if $USE_UTF8; then
        printf "    %c       %s  GLIDER PROXY MANAGER  %s                    %c\n" "$BOX_V" "$ICON_ROCKET" "$ICON_ROCKET" "$BOX_V"
    else
        printf "    %c           GLIDER PROXY MANAGER                         %c\n" "$BOX_V" "$BOX_V"
    fi
    
    printf "    %c" "$BOX_V"
    printf "%58s" " "
    printf "%c\n" "$BOX_V"
    
    printf "    %c" "$BOX_BL"
    printf "%58s" | tr ' ' "$BOX_H"
    printf "%c\n" "$BOX_BR"
    echo -e "${NC}"
}

# Красивый бокс
print_box() {
    local title="$1"
    local width="${2:-60}"
    
    printf "    ${LIGHT_CYAN}%c" "$BOX_TL"
    printf "%${width}s" | tr ' ' "$BOX_H"
    printf "%c${NC}\n" "$BOX_TR"
    
    if [ -n "$title" ]; then
        printf "    ${LIGHT_CYAN}%c${NC} ${BOLD}%s${NC}\n" "$BOX_V" "$title"
        printf "    ${LIGHT_CYAN}%c" "$BOX_VR"
        printf "%${width}s" | tr ' ' "$BOX_H"
        printf "%c${NC}\n" "$BOX_VL"
    fi
}

# Закрыть бокс
close_box() {
    local width="${1:-60}"
    printf "    ${LIGHT_CYAN}%c" "$BOX_BL"
    printf "%${width}s" | tr ' ' "$BOX_H"
    printf "%c${NC}\n" "$BOX_BR"
}

# Строка бокса
box_line() {
    local content="$1"
    printf "    ${LIGHT_CYAN}%c${NC} %s\n" "$BOX_V" "$content"
}

# Пустая строка бокса
box_empty() {
    local width="${1:-60}"
    printf "    ${LIGHT_CYAN}%c${NC}%${width}s${LIGHT_CYAN}%c${NC}\n" "$BOX_V" " " "$BOX_V"
}

# Проверка root прав
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        clear
        echo ""
        echo -e "${RED}${BOLD}"
        printf "    %c" "$BOX_TL"
        printf "%58s" | tr ' ' "$BOX_H"
        printf "%c\n" "$BOX_TR"
        printf "    %c%58s%c\n" "$BOX_V" " " "$BOX_V"
        printf "    %c                  %s ОШИБКА ДОСТУПА %s                     %c\n" "$BOX_V" "$ICON_WARNING" "$ICON_WARNING" "$BOX_V"
        printf "    %c%58s%c\n" "$BOX_V" " " "$BOX_V"
        printf "    %c" "$BOX_BL"
        printf "%58s" | tr ' ' "$BOX_H"
        printf "%c\n" "$BOX_BR"
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

            print_box "${ICON_USER} Пользователь #${count}" 57
            box_line "  ${GRAY}Логин:${NC}    ${GREEN}${username}${NC}"
            box_line "  ${GRAY}Пароль:${NC}   ${GREEN}${password}${NC}"
            box_line "  ${GRAY}Порт:${NC}     ${GREEN}${port}${NC}"
            box_empty 57
            box_line "  ${GRAY}HTTP:${NC}     ${BLUE}http://${username}:${password}@$(hostname -I | awk '{print $1}'):${port}${NC}"
            box_line "  ${GRAY}SOCKS5:${NC}   ${BLUE}socks5://${username}:${password}@$(hostname -I | awk '{print $1}'):${port}${NC}"
            close_box 57
            echo ""
            ((count++))
            found=1
        elif [[ $line =~ ^listen=mixed://:([0-9]+) ]]; then
            port="${BASH_REMATCH[1]}"

            print_box "Порт без аутентификации #${count}" 57
            box_line "  ${GRAY}Порт:${NC} ${GREEN}${port}${NC}"
            close_box 57
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
    draw_line "$BOX_H" 60
    echo ""

    echo -e "    ${YELLOW}${ICON_WARNING} Будет загружена последняя версия скрипта${NC}"
    echo ""
    read -p "    Продолжить обновление? (y/n): " CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        return
    fi

    echo ""
    draw_line "$BOX_H" 60
    echo ""

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

    if [ ! -s "$TEMP_SCRIPT" ]; then
        echo -e "    ${RED}Скачанный файл пуст!${NC}"
        rm -f "$TEMP_SCRIPT"
        echo ""
        read -p "    Нажмите Enter для продолжения..."
        return
    fi

    printf "    ${CYAN}Создание резервной копии...${NC}"
    cp "$SCRIPT_PATH" "${SCRIPT_PATH}.backup"
    echo -e " ${GREEN}${ICON_CHECK}${NC}"

    printf "    ${CYAN}Установка новой версии...${NC}"
    cp "$TEMP_SCRIPT" "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"
    rm -f "$TEMP_SCRIPT"
    echo -e " ${GREEN}${ICON_CHECK}${NC}"

    echo ""
    draw_line "$BOX_H" 60
    echo ""
    echo -e "    ${GREEN}${BOLD}${ICON_CHECK} Скрипт успешно обновлён!${NC}"
    echo ""
    echo -e "    ${YELLOW}Перезапуск скрипта через 2 секунды...${NC}"
    echo ""
    sleep 2

    exec "$SCRIPT_PATH" "$@"
}

# Установка Glider
install_glider() {
    print_header
    echo ""
    echo -e "    ${GREEN}${BOLD}${ICON_GEAR} УСТАНОВКА GLIDER${NC}"
    echo ""
    draw_line "$BOX_H" 60
    echo ""

    if check_glider_installed; then
        echo -e "    ${YELLOW}${ICON_WARNING} Glider уже установлен${NC}"
        echo -e "    ${CYAN}Используйте 'Обновить' для переустановки${NC}"
        echo ""
        read -p "    Нажмите Enter для продолжения..."
        return
    fi

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
    draw_line "$BOX_H" 60
    echo ""
    echo -e "    ${CYAN}Начинается установка...${NC}"
    echo ""

    run_with_spinner "    Обновление списка пакетов..." apt update
    run_with_spinner "    Установка зависимостей..." apt install curl wget tar -y

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

    if ! check_glider_installed; then
        echo -e "    ${RED}${ICON_CROSS} Ошибка установки бинарного файла${NC}"
        read -p "    Нажмите Enter для продолжения..."
        return
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

    run_with_spinner "    Создание конфигурации..." sleep 0.5

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
    run_with_spinner "    Перезагрузка systemd..." systemctl daemon-reload
    run_with_spinner "    Включение автозапуска..." systemctl enable glider
    run_with_spinner "    Запуск службы..." systemctl start glider

    sleep 2

    echo ""
    draw_line "$BOX_H" 60
    echo ""

    if systemctl is-active --quiet glider; then
        echo -e "${GREEN}${BOLD}"
        printf "    %c" "$BOX_TL"
        printf "%58s" | tr ' ' "$BOX_H"
        printf "%c\n" "$BOX_TR"
        printf "    %c%58s%c\n" "$BOX_V" " " "$BOX_V"
        printf "    %c         ${ICON_CHECK} УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО! ${ICON_CHECK}              %c\n" "$BOX_V" "$BOX_V"
        printf "    %c%58s%c\n" "$BOX_V" " " "$BOX_V"
        printf "    %c" "$BOX_BL"
        printf "%58s" | tr ' ' "$BOX_H"
        printf "%c\n" "$BOX_BR"
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
        else
            echo ""
            echo -e "    ${CYAN}HTTP прокси:${NC}  ${BLUE}http://$(hostname -I | awk '{print $1}'):${PROXY_PORT}${NC}"
            echo -e "    ${CYAN}SOCKS5 прокси:${NC} ${BLUE}socks5://$(hostname -I | awk '{print $1}'):${PROXY_PORT}${NC}"
        fi

        echo ""
        echo -e "    ${GRAY}Управление:${NC} ${DIM}systemctl {start|stop|restart|status} glider${NC}"
    else
        echo -e "${RED}${BOLD}"
        printf "    %c" "$BOX_TL"
        printf "%58s" | tr ' ' "$BOX_H"
        printf "%c\n" "$BOX_TR"
        printf "    %c%58s%c\n" "$BOX_V" " " "$BOX_V"
        printf "    %c         ${ICON_CROSS} ОШИБКА: СЛУЖБА НЕ ЗАПУСТИЛАСЬ ${ICON_CROSS}           %c\n" "$BOX_V" "$BOX_V"
        printf "    %c%58s%c\n" "$BOX_V" " " "$BOX_V"
        printf "    %c" "$BOX_BL"
        printf "%58s" | tr ' ' "$BOX_H"
        printf "%c\n" "$BOX_BR"
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
    draw_line "$BOX_H" 60
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
    draw_line "$BOX_H" 60
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
    draw_line "$BOX_H" 60
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
        draw_line "$BOX_H" 60

        if ! check_glider_installed; then
            echo ""
            echo -e "    ${YELLOW}${ICON_WARNING} Glider не установлен${NC}"
            echo ""
            read -p "    Нажмите Enter для продолжения..."
            return
        fi

        list_users

        local user_count=0
        if [ -f "$CONFIG_FILE" ]; then
            user_count=$(grep -c "^listen=" "$CONFIG_FILE" 2>/dev/null || echo "0")
        fi

        print_box "" 57
        box_empty 57
        box_line "   ${GREEN}1.${NC} Добавить пользователя"
        box_line "   ${YELLOW}2.${NC} Изменить пользователя"
        box_line "   ${RED}3.${NC} Удалить пользователя"
        box_line "   ${MAGENTA}4.${NC} Назад"
        box_empty 57
        close_box 57
        echo ""
        read -p "    $(echo -e ${CYAN}Выберите действие ${GREEN}[1-4]${CYAN}: ${NC})" action

        case $action in
            1)
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
    draw_line "$BOX_H" 60
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
    draw_line "$BOX_H" 60
    echo ""

    run_with_spinner "    Остановка службы Glider..." systemctl stop glider 2>/dev/null || true
    run_with_spinner "    Отключение автозапуска..." systemctl disable glider 2>/dev/null || true
    run_with_spinner "    Удаление systemd unit файла..." rm -f "$SERVICE_FILE"
    run_with_spinner "    Удаление символических ссылок..." bash -c "rm -f /etc/systemd/system/multi-user.target.wants/glider.service 2>/dev/null || true"
    run_with_spinner "    Удаление исполняемого файла..." rm -f "$BINARY_PATH"
    run_with_spinner "    Удаление конфигурации..." rm -rf /etc/glider
    run_with_spinner "    Очистка временных файлов..." bash -c "rm -f /tmp/glider* 2>/dev/null || true"
    run_with_spinner "    Перезагрузка systemd..." systemctl daemon-reload
    run_with_spinner "    Сброс состояния служб..." systemctl reset-failed 2>/dev/null || true

    echo ""
    draw_line "$BOX_H" 60
    echo ""
    echo -e "    ${GREEN}${BOLD}${ICON_CHECK} Glider полностью удалён из системы!${NC}"
    echo ""
    echo -e "    ${CYAN}${ICON_INFO} Удалённые компоненты:${NC}"
    echo -e "      ${DIM}Служба systemd (glider.service)${NC}"
    echo -e "      ${DIM}Исполняемый файл ($BINARY_PATH)${NC}"
    echo -e "      ${DIM}Конфигурационные файлы (/etc/glider/)${NC}"
    echo -e "      ${DIM}Символические ссылки служб${NC}"
    echo -e "      ${DIM}Временные файлы${NC}"
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
        
        print_box "Информация о системе" 57
        if [ "$STATUS" == "active" ]; then
            box_line "  ${GRAY}Статус:${NC}  ${GREEN}[*] Установлен${NC} ${DIM}(v$CURRENT_VERSION)${NC}"
            box_line "  ${GRAY}Служба:${NC}  ${GREEN}[*] Запущена${NC}"
        else
            box_line "  ${GRAY}Статус:${NC}  ${RED}[X] Установлен${NC} ${DIM}(v$CURRENT_VERSION)${NC}"
            box_line "  ${GRAY}Служба:${NC}  ${RED}[X] Остановлена${NC}"
        fi
        close_box 57
    else
        print_box "Информация о системе" 57
        box_line "  ${GRAY}Статус:${NC}  ${YELLOW}[!] Не установлен${NC}"
        close_box 57
    fi

    echo ""
    print_box "Доступные действия" 57
    box_empty 57
    box_line "   ${GREEN}1.${NC} ${ICON_GEAR}  Установить Glider"
    box_line "   ${BLUE}2.${NC} ${ICON_UPDATE}  Обновить Glider"
    box_line "   ${YELLOW}3.${NC} ${ICON_USER}  Управление пользователями"
    box_line "   ${BLUE}4.${NC} ${ICON_UPDATE}  Обновить скрипт"
    box_line "   ${RED}5.${NC} ${ICON_TRASH}  Удалить Glider"
    box_line "   ${MAGENTA}6.${NC} ${ICON_DOOR}  Выход"
    box_empty 57
    close_box 57
    echo ""
    read -p "    $(echo -e ${CYAN}Выберите действие ${GREEN}[1-6]${CYAN}: ${NC})" choice

    case $choice in
        1) install_glider ;;
        2) update_glider ;;
        3) manage_users ;;
        4) update_script ;;
        5) remove_glider ;;
        6) clear; echo ""; echo -e "    ${GREEN}${BOLD}Спасибо за использование Glider Manager!${NC}"; echo ""; exit 0 ;;
        *) echo -e "    ${RED}${ICON_CROSS} Неверный выбор${NC}"; sleep 1 ;;
    esac
}

# Основной цикл
check_root

while true; do
    show_menu
done
