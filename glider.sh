#!/bin/bash

# ============================================================================
# GLIDER PROXY MANAGER - Interactive Terminal UI
# ============================================================================
# Современный интерактивный менеджер Glider для Ubuntu/Linux
# Использование: sudo ./glider-manager.sh
# ============================================================================

set -e

# Переменные конфигурации
CONFIG_FILE="/etc/glider/glider.conf"
SERVICE_FILE="/etc/systemd/system/glider.service"
BINARY_PATH="/usr/local/bin/glider-bin"
SCRIPT_PATH="/usr/local/bin/glider-manager"
SCRIPT_URL="https://raw.githubusercontent.com/thekhabaroff/GliderProxy/main/glider.sh"
VERSION="0.16.4"

# ============================================================================
# ОПРЕДЕЛЕНИЕ ПОДДЕРЖКИ UTF-8
# ============================================================================

detect_utf8_support() {
    if [[ "$LANG" =~ [Uu][Tt][Ff]-?8 ]] || [[ "$LC_ALL" =~ [Uu][Tt][Ff]-?8 ]]; then
        return 0
    else
        return 1
    fi
}

if detect_utf8_support; then
    USE_UTF8=true
else
    USE_UTF8=false
fi

# ============================================================================
# ЦВЕТА И СТИЛИ
# ============================================================================

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

LIGHT_BLUE='\033[1;34m'
LIGHT_CYAN='\033[1;36m'
LIGHT_GREEN='\033[1;32m'
LIGHT_RED='\033[1;31m'
LIGHT_MAGENTA='\033[1;35m'
LIGHT_YELLOW='\033[1;33m'
DARK_GRAY='\033[1;30m'
GRAY='\033[0;37m'
PURPLE='\033[0;35m'
ORANGE='\033[38;5;208m'

# Выбор символов в зависимости от поддержки UTF-8
if $USE_UTF8; then
    # UTF-8 символы
    BOX_TL="╔"; BOX_TR="╗"; BOX_BL="╚"; BOX_BR="╝"
    BOX_H="═"; BOX_V="║"
    BOX_VR="╠"; BOX_VL="╣"; BOX_HU="╩"; BOX_HD="╦"
    
    SBOX_TL="┌"; SBOX_TR="┐"; SBOX_BL="└"; SBOX_BR="┘"
    SBOX_H="─"; SBOX_V="│"
    SBOX_VR="├"; SBOX_VL="┤"
    
    ARROW_RIGHT="→"
    BULLET="●"
    CHECK="✓"
    CROSS="✗"
    FIRE="🔥"
    HEART="♥"
else
    # ASCII символы (для терминалов без UTF-8)
    BOX_TL="+"; BOX_TR="+"; BOX_BL="+"; BOX_BR="+"
    BOX_H="="; BOX_V="|"
    BOX_VR="+"; BOX_VL="+"; BOX_HU="+"; BOX_HD="+"
    
    SBOX_TL="+"; SBOX_TR="+"; SBOX_BL="+"; SBOX_BR="+"
    SBOX_H="-"; SBOX_V="|"
    SBOX_VR="+"; SBOX_VL="+"
    
    ARROW_RIGHT=">"
    BULLET="*"
    CHECK="+"
    CROSS="x"
    FIRE="*"
    HEART="<3"
fi

# Иконки
ICON_CHECK="$CHECK"
ICON_CROSS="$CROSS"
ICON_ARROW="$ARROW_RIGHT"
ICON_ROCKET="$FIRE"
ICON_GEAR="@"
ICON_USER="U"
ICON_TRASH="X"
ICON_UPDATE="^"
ICON_WARNING="!"
ICON_INFO="i"
ICON_DOOR=">"

# ============================================================================
# ФУНКЦИИ ВЫВОДА
# ============================================================================

draw_line() {
    local width="${1:-70}"
    local char="${2:-$BOX_H}"
    echo -ne " ${LIGHT_CYAN}"
    printf "%${width}s" | tr ' ' "${char}"
    echo -e "${NC}"
}

print_header() {
    clear
    local width=70
    echo ""
    
    # Верхняя рамка
    echo -ne " ${LIGHT_CYAN}${BOLD}${BOX_TL}"
    printf "%${width}s" | tr ' ' "${BOX_H}"
    echo -e "${BOX_TR}${NC}"
    
    # Пустая строка
    echo -e " ${LIGHT_CYAN}${BOX_V}$(printf "%${width}s")${BOX_V}${NC}"
    
    # Название
    local title="${FIRE} G L I D E R   P R O X Y   M A N A G E R ${FIRE}"
    local title_len=${#title}
    local padding=$(( (width - title_len) / 2 ))
    
    echo -ne " ${LIGHT_CYAN}${BOX_V}${NC}"
    printf "%${padding}s" ""
    echo -ne "${BOLD}${WHITE}${title}${NC}"
    printf "%$(( width - padding - title_len ))s" ""
    echo -e "${LIGHT_CYAN}${BOX_V}${NC}"
    
    # Версия
    local ver_text="version ${VERSION}"
    local ver_len=${#ver_text}
    local ver_padding=$(( (width - ver_len) / 2 ))
    
    echo -ne " ${LIGHT_CYAN}${BOX_V}${NC}"
    printf "%${ver_padding}s" ""
    echo -ne "${DIM}${GRAY}${ver_text}${NC}"
    printf "%$(( width - ver_padding - ver_len ))s" ""
    echo -e "${LIGHT_CYAN}${BOX_V}${NC}"
    
    # Пустая строка
    echo -e " ${LIGHT_CYAN}${BOX_V}$(printf "%${width}s")${BOX_V}${NC}"
    
    # Нижняя рамка
    echo -ne " ${LIGHT_CYAN}${BOX_BL}"
    printf "%${width}s" | tr ' ' "${BOX_H}"
    echo -e "${BOX_BR}${NC}"
    
    echo ""
}

show_status() {
    local width=70
    
    echo -ne " ${LIGHT_BLUE}${BOX_TL}${BOX_H}${BOX_H} "
    echo -ne "${NC}${BOLD}${WHITE}СТАТУС СИСТЕМЫ${NC} ${LIGHT_BLUE}"
    printf "%52s" | tr ' ' "${BOX_H}"
    echo -e "${BOX_TR}${NC}"
    
    if check_glider_installed; then
        local version=$(get_current_version)
        local status=$(systemctl is-active glider 2>/dev/null || echo "stopped")
        
        if [ "$status" == "active" ]; then
            echo -e " ${LIGHT_BLUE}${BOX_V}${NC}  ${LIGHT_GREEN}${ICON_CHECK}${NC} Версия       ${LIGHT_GREEN}${BOLD}${version}${NC}$(printf "%$((53-${#version}))s")${LIGHT_BLUE}${BOX_V}${NC}"
            echo -e " ${LIGHT_BLUE}${BOX_V}${NC}  ${LIGHT_GREEN}${ICON_CHECK}${NC} Статус       ${LIGHT_GREEN}${BOLD}ЗАПУЩЕН${NC}$(printf "%44s")${LIGHT_BLUE}${BOX_V}${NC}"
            echo -e " ${LIGHT_BLUE}${BOX_V}${NC}  ${LIGHT_GREEN}${ICON_CHECK}${NC} Автозапуск   ${LIGHT_GREEN}${BOLD}ВКЛЮЧЕН${NC}$(printf "%44s")${LIGHT_BLUE}${BOX_V}${NC}"
        else
            echo -e " ${LIGHT_BLUE}${BOX_V}${NC}  ${YELLOW}${ICON_WARNING}${NC} Версия       ${YELLOW}${BOLD}${version}${NC}$(printf "%$((53-${#version}))s")${LIGHT_BLUE}${BOX_V}${NC}"
            echo -e " ${LIGHT_BLUE}${BOX_V}${NC}  ${RED}${ICON_CROSS}${NC} Статус       ${RED}${BOLD}ОСТАНОВЛЕН${NC}$(printf "%41s")${LIGHT_BLUE}${BOX_V}${NC}"
            echo -e " ${LIGHT_BLUE}${BOX_V}${NC}  ${YELLOW}${ICON_WARNING}${NC} Автозапуск   ${YELLOW}${BOLD}ВКЛЮЧЕН${NC}$(printf "%44s")${LIGHT_BLUE}${BOX_V}${NC}"
        fi
    else
        echo -e " ${LIGHT_BLUE}${BOX_V}${NC}  ${YELLOW}${ICON_WARNING}${NC} Glider       ${YELLOW}${BOLD}НЕ УСТАНОВЛЕН${NC}$(printf "%38s")${LIGHT_BLUE}${BOX_V}${NC}"
        echo -e " ${LIGHT_BLUE}${BOX_V}${NC}  ${DIM}${GRAY}Используйте пункт 1 для установки${NC}$(printf "%20s")${LIGHT_BLUE}${BOX_V}${NC}"
    fi
    
    echo -ne " ${LIGHT_BLUE}${BOX_BL}"
    printf "%70s" | tr ' ' "${BOX_H}"
    echo -e "${BOX_BR}${NC}"
    echo ""
}

success_message() {
    echo ""
    echo -ne " ${LIGHT_GREEN}${BOX_TL}${BOX_H} "
    echo -ne "${NC}${BOLD}${WHITE}$1${NC} ${LIGHT_GREEN}"
    local msg_len=${#1}
    printf "%$((67-msg_len))s" | tr ' ' "${BOX_H}"
    echo -e "${BOX_TR}${NC}"
    echo -ne " ${LIGHT_GREEN}${BOX_BL}"
    printf "%70s" | tr ' ' "${BOX_H}"
    echo -e "${BOX_BR}${NC}"
    echo ""
}

error_message() {
    echo ""
    echo -ne " ${RED}${BOX_TL}${BOX_H} "
    echo -ne "${NC}${BOLD}${WHITE}ОШИБКА: $1${NC} ${RED}"
    local msg_len=$((${#1} + 8))
    printf "%$((67-msg_len))s" | tr ' ' "${BOX_H}"
    echo -e "${BOX_TR}${NC}"
    echo -ne " ${RED}${BOX_BL}"
    printf "%70s" | tr ' ' "${BOX_H}"
    echo -e "${BOX_BR}${NC}"
    echo ""
}

warning_message() {
    echo ""
    echo -ne " ${YELLOW}${BOX_TL}${BOX_H} "
    echo -ne "${NC}${BOLD}${WHITE}$1${NC} ${YELLOW}"
    local msg_len=${#1}
    printf "%$((67-msg_len))s" | tr ' ' "${BOX_H}"
    echo -e "${BOX_TR}${NC}"
    echo -ne " ${YELLOW}${BOX_BL}"
    printf "%70s" | tr ' ' "${BOX_H}"
    echo -e "${BOX_BR}${NC}"
    echo ""
}

spinner() {
    local pid=$1
    local delay=0.075
    
    if $USE_UTF8; then
        local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    else
        local spinstr='|/-\'
    fi
    
    while kill -0 $pid 2>/dev/null; do
        local temp=${spinstr#?}
        printf " ${LIGHT_CYAN}[${LIGHT_BLUE}%c${LIGHT_CYAN}]${NC} " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

run_with_spinner() {
    local message=$1
    shift
    printf " ${CYAN}${ARROW_RIGHT}${NC} ${message}"
    ("$@") > /dev/null 2>&1 &
    spinner $!
    wait $!
    local status=$?
    if [ $status -eq 0 ]; then
        echo -e " ${LIGHT_GREEN}${BOLD}${ICON_CHECK}${NC}"
    else
        echo -e " ${RED}${BOLD}${ICON_CROSS}${NC}"
        return $status
    fi
}

draw_separator() {
    local width="${1:-70}"
    echo -ne " ${DARK_GRAY}"
    printf "%${width}s" | tr ' ' "${SBOX_H}"
    echo -e "${NC}"
}

# ============================================================================
# ПРОВЕРКИ И УТИЛИТЫ
# ============================================================================

check_root() {
    if [ "$EUID" -ne 0 ]; then
        clear
        echo ""
        echo -ne " ${RED}${BOLD}${BOX_TL}"
        printf "%70s" | tr ' ' "${BOX_H}"
        echo -e "${BOX_TR}${NC}"
        echo -ne " ${RED}${BOX_V}${NC}"
        printf "%26s" ""
        echo -ne "${BOLD}${WHITE}ОШИБКА ДОСТУПА${NC}"
        printf "%30s" ""
        echo -e "${RED}${BOX_V}${NC}"
        echo -ne " ${RED}${BOX_BL}"
        printf "%70s" | tr ' ' "${BOX_H}"
        echo -e "${BOX_BR}${NC}"
        echo ""
        echo -e " ${YELLOW}${ICON_WARNING}${NC} ${GRAY}Для запуска требуются права суперпользователя${NC}"
        echo ""
        echo -e " ${LIGHT_CYAN}${ARROW_RIGHT}${NC} Используйте: ${LIGHT_GREEN}${BOLD}sudo ./glider-manager.sh${NC}"
        echo ""
        exit 1
    fi
}

check_glider_installed() {
    [ -f "$BINARY_PATH" ]
}

get_current_version() {
    if check_glider_installed; then
        $BINARY_PATH -help 2>&1 | grep -o "glider [0-9.]*" | awk '{print $2}' || echo "$VERSION"
    else
        echo "не установлен"
    fi
}

check_port_used() {
    local port=$1
    grep -q ":${port}\$" "$CONFIG_FILE" 2>/dev/null
}

# ============================================================================
# УСТАНОВКА GLIDER
# ============================================================================

install_glider() {
    print_header
    show_status
    
    if check_glider_installed; then
        warning_message "Glider уже установлен"
        echo -e " ${DIM}${GRAY}Используйте пункт 2 для обновления${NC}\n"
        read -p " Нажмите Enter для продолжения..."
        return
    fi
    
    echo -ne " ${LIGHT_MAGENTA}${BOX_TL}${BOX_H} "
    echo -ne "${NC}${BOLD}${WHITE}НАСТРОЙКА ПЕРВОГО ПОЛЬЗОВАТЕЛЯ${NC} ${LIGHT_MAGENTA}"
    printf "%36s" | tr ' ' "${BOX_H}"
    echo -e "${BOX_TR}${NC}"
    echo -ne " ${LIGHT_MAGENTA}${BOX_BL}"
    printf "%70s" | tr ' ' "${BOX_H}"
    echo -e "${BOX_BR}${NC}"
    echo ""
    
    read -p " ${LIGHT_CYAN}${BULLET}${NC} Введите порт для прокси [18443]: " PROXY_PORT
    PROXY_PORT=${PROXY_PORT:-18443}
    
    read -p " ${LIGHT_CYAN}${BULLET}${NC} Добавить аутентификацию? (y/n) [n]: " ADD_AUTH
    
    if [[ "$ADD_AUTH" == "y" || "$ADD_AUTH" == "Y" ]]; then
        read -p " ${LIGHT_CYAN}${BULLET}${NC} Введите логин: " PROXY_USER
        read -sp " ${LIGHT_CYAN}${BULLET}${NC} Введите пароль: " PROXY_PASS
        echo
        LISTEN_STRING="mixed://${PROXY_USER}:${PROXY_PASS}@:${PROXY_PORT}"
    else
        LISTEN_STRING="mixed://:${PROXY_PORT}"
    fi
    
    echo ""
    draw_separator
    echo ""
    echo -e " ${LIGHT_BLUE}${BOLD}${FIRE} Начинается установка...${NC}"
    echo ""
    
    run_with_spinner "Обновление списка пакетов" apt update
    run_with_spinner "Установка зависимостей" apt install -y curl wget tar
    
    cd /tmp
    rm -rf glider_* glider.tar.gz 2>/dev/null || true
    
    run_with_spinner "Скачивание Glider v${VERSION}" \
        wget -q "https://github.com/nadoo/glider/releases/download/v${VERSION}/glider_${VERSION}_linux_amd64.tar.gz" -O glider.tar.gz
    
    run_with_spinner "Распаковка архива" tar -xzf glider.tar.gz
    run_with_spinner "Установка бинарного файла" \
        bash -c "find . -name 'glider' -type f -exec cp {} $BINARY_PATH \; && chmod +x $BINARY_PATH"
    
    mkdir -p /etc/glider
    
    cat > $CONFIG_FILE <<EOF
# ============================================================================
# Glider Configuration
# Generated by Glider Manager v${VERSION}
# ============================================================================

# HTTP + SOCKS5 Proxy
listen=$LISTEN_STRING

# Forward через локальный прокси (измените при необходимости)
# forward=http://127.0.0.1:8080

# Документация: https://github.com/nadoo/glider
EOF
    
    cat > $SERVICE_FILE <<EOF
[Unit]
Description=Glider Proxy Server
After=network.target

[Service]
Type=simple
User=root
ExecStart=$BINARY_PATH -config $CONFIG_FILE
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    run_with_spinner "Регистрация systemd службы" systemctl daemon-reload
    run_with_spinner "Включение автозапуска" systemctl enable glider
    run_with_spinner "Запуск Glider" systemctl start glider
    
    sleep 2
    
    echo ""
    draw_separator
    echo ""
    
    if systemctl is-active --quiet glider; then
        success_message "Glider успешно установлен!"
        echo -e " ${SBOX_TL}${SBOX_H} ${BOLD}Информация о прокси${NC}"
        echo -e " ${SBOX_V}"
        echo -e " ${SBOX_V} ${GRAY}Версия:${NC}  ${LIGHT_GREEN}${BOLD}$(get_current_version)${NC}"
        echo -e " ${SBOX_V} ${GRAY}Порт:${NC}    ${LIGHT_GREEN}${BOLD}${PROXY_PORT}${NC}"
        if [[ "$ADD_AUTH" == "y" || "$ADD_AUTH" == "Y" ]]; then
            echo -e " ${SBOX_V} ${GRAY}Логин:${NC}   ${LIGHT_GREEN}${BOLD}${PROXY_USER}${NC}"
            echo -e " ${SBOX_V} ${GRAY}Пароль:${NC}  ${LIGHT_GREEN}${BOLD}${PROXY_PASS}${NC}"
        fi
        echo -e " ${SBOX_V}"
        echo -e " ${SBOX_BL}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}"
    else
        error_message "Ошибка установки"
        echo -e " ${RED}${ICON_WARNING}${NC} Проверьте логи: ${LIGHT_CYAN}systemctl status glider${NC}"
    fi
    
    echo ""
    read -p " Нажмите Enter для продолжения..."
}

# ============================================================================
# ОБНОВЛЕНИЕ GLIDER
# ============================================================================

update_glider() {
    print_header
    show_status
    
    if ! check_glider_installed; then
        warning_message "Glider не установлен"
        read -p " Нажмите Enter для продолжения..."
        return
    fi
    
    echo -ne " ${ORANGE}${BOX_TL}${BOX_H} "
    echo -ne "${NC}${BOLD}${WHITE}ОБНОВЛЕНИЕ GLIDER${NC} ${ORANGE}"
    printf "%50s" | tr ' ' "${BOX_H}"
    echo -e "${BOX_TR}${NC}"
    echo -ne " ${ORANGE}${BOX_BL}"
    printf "%70s" | tr ' ' "${BOX_H}"
    echo -e "${BOX_BR}${NC}"
    echo ""
    
    echo -e " ${YELLOW}${ICON_WARNING}${NC} ${GRAY}Будет загружена версия${NC} ${LIGHT_GREEN}${BOLD}${VERSION}${NC}"
    echo ""
    read -p " Продолжить обновление? (y/n): " CONFIRM
    
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        return
    fi
    
    echo ""
    draw_separator
    echo ""
    echo -e " ${LIGHT_BLUE}${BOLD}${FIRE} Обновление...${NC}"
    echo ""
    
    cd /tmp
    rm -rf glider_* glider.tar.gz 2>/dev/null || true
    
    run_with_spinner "Скачивание Glider v${VERSION}" \
        wget -q "https://github.com/nadoo/glider/releases/download/v${VERSION}/glider_${VERSION}_linux_amd64.tar.gz" -O glider.tar.gz
    
    run_with_spinner "Создание резервной копии" cp $CONFIG_FILE ${CONFIG_FILE}.backup
    run_with_spinner "Остановка сервиса" systemctl stop glider
    run_with_spinner "Распаковка архива" tar -xzf glider.tar.gz
    run_with_spinner "Установка новой версии" \
        bash -c "find . -name 'glider' -type f -exec cp {} $BINARY_PATH \; && chmod +x $BINARY_PATH"
    run_with_spinner "Запуск сервиса" systemctl start glider
    
    sleep 2
    
    echo ""
    draw_separator
    echo ""
    
    if systemctl is-active --quiet glider; then
        success_message "Обновление завершено!"
        echo -e " ${GRAY}Новая версия:${NC} ${LIGHT_GREEN}${BOLD}$(get_current_version)${NC}"
    else
        error_message "Ошибка после обновления"
    fi
    
    echo ""
    read -p " Нажмите Enter для продолжения..."
}

# ============================================================================
# УПРАВЛЕНИЕ ПОЛЬЗОВАТЕЛЯМИ
# ============================================================================

list_users() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e " ${DIM}${GRAY}  Пользователей не найдено${NC}"
        echo ""
        return
    fi
    
    local count=1
    local found=0
    
    while IFS= read -r line; do
        if [[ $line =~ ^listen=mixed://([^:]+):([^@]+)@:([0-9]+) ]]; then
            username="${BASH_REMATCH[1]}"
            password="${BASH_REMATCH[2]}"
            port="${BASH_REMATCH[3]}"
            
            echo -ne " ${DARK_GRAY}${SBOX_TL}"
            printf "%68s" | tr ' ' "${SBOX_H}"
            echo -e "${SBOX_TR}${NC}"
            echo -e " ${DARK_GRAY}${SBOX_V}${NC} ${BOLD}${LIGHT_CYAN}${ICON_USER} Пользователь #${count}${NC}$(printf "%$((53-${#count}))s")${DARK_GRAY}${SBOX_V}${NC}"
            echo -ne " ${DARK_GRAY}${SBOX_VR}"
            printf "%68s" | tr ' ' "${SBOX_H}"
            echo -e "${SBOX_VL}${NC}"
            echo -e " ${DARK_GRAY}${SBOX_V}${NC} ${GRAY}Логин:${NC}   ${LIGHT_GREEN}${username}${NC}$(printf "%$((57-${#username}))s")${DARK_GRAY}${SBOX_V}${NC}"
            echo -e " ${DARK_GRAY}${SBOX_V}${NC} ${GRAY}Пароль:${NC}  ${LIGHT_GREEN}${password}${NC}$(printf "%$((56-${#password}))s")${DARK_GRAY}${SBOX_V}${NC}"
            echo -e " ${DARK_GRAY}${SBOX_V}${NC} ${GRAY}Порт:${NC}    ${LIGHT_GREEN}${port}${NC}$(printf "%$((59-${#port}))s")${DARK_GRAY}${SBOX_V}${NC}"
            echo -ne " ${DARK_GRAY}${SBOX_VR}"
            printf "%68s" | tr ' ' "${SBOX_H}"
            echo -e "${SBOX_VL}${NC}"
            
            local ip=$(hostname -I | awk '{print $1}')
            echo -e " ${DARK_GRAY}${SBOX_V}${NC} ${DIM}HTTP:${NC}"
            echo -e " ${DARK_GRAY}${SBOX_V}${NC} ${LIGHT_BLUE}http://${username}:${password}@${ip}:${port}${NC}"
            echo -e " ${DARK_GRAY}${SBOX_V}${NC}"
            echo -e " ${DARK_GRAY}${SBOX_V}${NC} ${DIM}SOCKS5:${NC}"
            echo -e " ${DARK_GRAY}${SBOX_V}${NC} ${LIGHT_BLUE}socks5://${username}:${password}@${ip}:${port}${NC}"
            echo -ne " ${DARK_GRAY}${SBOX_BL}"
            printf "%68s" | tr ' ' "${SBOX_H}"
            echo -e "${SBOX_BR}${NC}"
            echo ""
            ((count++))
            found=1
        elif [[ $line =~ ^listen=mixed://:([0-9]+) ]]; then
            port="${BASH_REMATCH[1]}"
            
            echo -ne " ${DARK_GRAY}${SBOX_TL}"
            printf "%68s" | tr ' ' "${SBOX_H}"
            echo -e "${SBOX_TR}${NC}"
            echo -e " ${DARK_GRAY}${SBOX_V}${NC} ${BOLD}${YELLOW}${ICON_WARNING} Порт без аутентификации #${count}${NC}$(printf "%$((35-${#count}))s")${DARK_GRAY}${SBOX_V}${NC}"
            echo -ne " ${DARK_GRAY}${SBOX_VR}"
            printf "%68s" | tr ' ' "${SBOX_H}"
            echo -e "${SBOX_VL}${NC}"
            echo -e " ${DARK_GRAY}${SBOX_V}${NC} ${GRAY}Порт:${NC} ${LIGHT_GREEN}${port}${NC}$(printf "%$((59-${#port}))s")${DARK_GRAY}${SBOX_V}${NC}"
            echo -ne " ${DARK_GRAY}${SBOX_BL}"
            printf "%68s" | tr ' ' "${SBOX_H}"
            echo -e "${SBOX_BR}${NC}"
            echo ""
            ((count++))
            found=1
        fi
    done < "$CONFIG_FILE"
    
    if [ $found -eq 0 ]; then
        echo -e " ${DIM}${GRAY}  Пользователей не найдено${NC}"
        echo ""
    fi
}

add_user() {
    print_header
    
    echo -ne " ${LIGHT_GREEN}${BOX_TL}${BOX_H} "
    echo -ne "${NC}${BOLD}${WHITE}ДОБАВЛЕНИЕ ПОЛЬЗОВАТЕЛЯ${NC} ${LIGHT_GREEN}"
    printf "%44s" | tr ' ' "${BOX_H}"
    echo -e "${BOX_TR}${NC}"
    echo -ne " ${LIGHT_GREEN}${BOX_BL}"
    printf "%70s" | tr ' ' "${BOX_H}"
    echo -e "${BOX_BR}${NC}"
    echo ""
    
    if ! check_glider_installed; then
        warning_message "Glider не установлен"
        read -p " Нажмите Enter для продолжения..."
        return
    fi
    
    read -p " ${LIGHT_CYAN}${BULLET}${NC} Введите новый логин: " NEW_USER
    if [ -z "$NEW_USER" ]; then
        error_message "Логин не может быть пустым"
        sleep 2
        return
    fi
    
    read -sp " ${LIGHT_CYAN}${BULLET}${NC} Введите новый пароль: " NEW_PASS
    echo
    if [ -z "$NEW_PASS" ]; then
        error_message "Пароль не может быть пустым"
        sleep 2
        return
    fi
    
    read -p " ${LIGHT_CYAN}${BULLET}${NC} Введите порт для этого пользователя: " NEW_PORT
    if [ -z "$NEW_PORT" ]; then
        error_message "Порт не может быть пустым"
        sleep 2
        return
    fi
    
    if check_port_used "$NEW_PORT"; then
        error_message "Порт $NEW_PORT уже используется!"
        sleep 2
        return
    fi
    
    echo ""
    draw_separator
    echo ""
    
    echo "listen=mixed://${NEW_USER}:${NEW_PASS}@:${NEW_PORT}" >> $CONFIG_FILE
    
    run_with_spinner "Добавление пользователя" echo "OK"
    run_with_spinner "Перезапуск сервиса" systemctl restart glider
    
    sleep 2
    echo ""
    
    if systemctl is-active --quiet glider; then
        success_message "Пользователь добавлен успешно!"
        echo -e " ${SBOX_TL}${SBOX_H} ${BOLD}Данные пользователя${NC}"
        echo -e " ${SBOX_V}"
        echo -e " ${SBOX_V} ${GRAY}Логин:${NC}   ${LIGHT_GREEN}${BOLD}${NEW_USER}${NC}"
        echo -e " ${SBOX_V} ${GRAY}Пароль:${NC}  ${LIGHT_GREEN}${BOLD}${NEW_PASS}${NC}"
        echo -e " ${SBOX_V} ${GRAY}Порт:${NC}    ${LIGHT_GREEN}${BOLD}${NEW_PORT}${NC}"
        echo -e " ${SBOX_V}"
        echo -e " ${SBOX_BL}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}"
    else
        error_message "Ошибка при добавлении пользователя"
    fi
    
    echo ""
    read -p " Нажмите Enter для продолжения..."
}

edit_user() {
    print_header
    
    echo -ne " ${YELLOW}${BOX_TL}${BOX_H} "
    echo -ne "${NC}${BOLD}${WHITE}ИЗМЕНЕНИЕ ПОЛЬЗОВАТЕЛЯ${NC} ${YELLOW}"
    printf "%45s" | tr ' ' "${BOX_H}"
    echo -e "${BOX_TR}${NC}"
    echo -ne " ${YELLOW}${BOX_BL}"
    printf "%70s" | tr ' ' "${BOX_H}"
    echo -e "${BOX_BR}${NC}"
    echo ""
    
    if ! check_glider_installed; then
        warning_message "Glider не установлен"
        read -p " Нажмите Enter для продолжения..."
        return
    fi
    
    local user_count=0
    if [ -f "$CONFIG_FILE" ]; then
        user_count=$(grep -c "^listen=" "$CONFIG_FILE" 2>/dev/null || echo "0")
    fi
    
    if [ "$user_count" -eq 0 ]; then
        warning_message "Нет пользователей для изменения"
        sleep 2
        return
    fi
    
    list_users
    
    read -p " ${LIGHT_CYAN}${ARROW_RIGHT}${NC} Введите номер пользователя: " user_num
    
    if ! [[ "$user_num" =~ ^[0-9]+$ ]] || [ "$user_num" -lt 1 ] || [ "$user_num" -gt "$user_count" ]; then
        error_message "Неверный номер"
        sleep 2
        return
    fi
    
    local line=$(grep "^listen=" "$CONFIG_FILE" | sed -n "${user_num}p")
    
    if [[ $line =~ ^listen=mixed://([^:]+):([^@]+)@:([0-9]+) ]]; then
        old_username="${BASH_REMATCH[1]}"
        old_password="${BASH_REMATCH[2]}"
        old_port="${BASH_REMATCH[3]}"
    else
        error_message "Ошибка чтения данных пользователя"
        sleep 2
        return
    fi
    
    echo ""
    draw_separator
    echo ""
    
    read -p " ${LIGHT_CYAN}${BULLET}${NC} Новый логин [$old_username]: " new_username
    new_username=${new_username:-$old_username}
    read -sp " ${LIGHT_CYAN}${BULLET}${NC} Новый пароль [оставить текущий]: " new_password
    echo
    new_password=${new_password:-$old_password}
    read -p " ${LIGHT_CYAN}${BULLET}${NC} Новый порт [$old_port]: " new_port
    new_port=${new_port:-$old_port}
    
    if [ "$new_port" != "$old_port" ] && check_port_used "$new_port"; then
        error_message "Порт $new_port уже используется!"
        sleep 2
        return
    fi
    
    echo ""
    draw_separator
    echo ""
    
    run_with_spinner "Изменение пользователя" \
        sed -i "s|^listen=.*:${old_port}\$|listen=mixed://${new_username}:${new_password}@:${new_port}|" $CONFIG_FILE
    
    run_with_spinner "Перезапуск сервиса" systemctl restart glider
    
    sleep 2
    
    if systemctl is-active --quiet glider; then
        success_message "Пользователь изменён успешно!"
    else
        error_message "Ошибка при изменении"
    fi
    
    echo ""
    read -p " Нажмите Enter для продолжения..."
}

delete_user() {
    print_header
    
    echo -ne " ${RED}${BOX_TL}${BOX_H} "
    echo -ne "${NC}${BOLD}${WHITE}УДАЛЕНИЕ ПОЛЬЗОВАТЕЛЯ${NC} ${RED}"
    printf "%46s" | tr ' ' "${BOX_H}"
    echo -e "${BOX_TR}${NC}"
    echo -ne " ${RED}${BOX_BL}"
    printf "%70s" | tr ' ' "${BOX_H}"
    echo -e "${BOX_BR}${NC}"
    echo ""
    
    if ! check_glider_installed; then
        warning_message "Glider не установлен"
        read -p " Нажмите Enter для продолжения..."
        return
    fi
    
    local user_count=0
    if [ -f "$CONFIG_FILE" ]; then
        user_count=$(grep -c "^listen=" "$CONFIG_FILE" 2>/dev/null || echo "0")
    fi
    
    if [ "$user_count" -le 1 ]; then
        error_message "Нельзя удалить последнего пользователя!"
        echo -e " ${YELLOW}${ICON_WARNING}${NC} ${GRAY}Используйте 'Удалить Glider' для полного удаления${NC}"
        echo ""
        sleep 3
        return
    fi
    
    list_users
    
    read -p " ${LIGHT_CYAN}${ARROW_RIGHT}${NC} Введите номер пользователя: " user_num
    
    if ! [[ "$user_num" =~ ^[0-9]+$ ]] || [ "$user_num" -lt 1 ] || [ "$user_num" -gt "$user_count" ]; then
        error_message "Неверный номер"
        sleep 2
        return
    fi
    
    local line=$(grep "^listen=" "$CONFIG_FILE" | sed -n "${user_num}p")
    
    if [[ $line =~ :([0-9]+)$ ]]; then
        port="${BASH_REMATCH[1]}"
    else
        error_message "Ошибка чтения порта"
        sleep 2
        return
    fi
    
    if [[ $line =~ ^listen=mixed://([^:]+): ]]; then
        username="${BASH_REMATCH[1]}"
    else
        username="noauth"
    fi
    
    echo ""
    echo -e " ${YELLOW}${ICON_WARNING}${NC} Удалить пользователя ${BOLD}'${username}'${NC} на порту ${BOLD}${port}${NC}?"
    echo ""
    read -p " Подтвердите (y/n): " CONFIRM
    
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        return
    fi
    
    echo ""
    draw_separator
    echo ""
    
    run_with_spinner "Удаление пользователя" \
        sed -i "/^listen=.*:${port}\$/d" $CONFIG_FILE
    
    run_with_spinner "Перезапуск сервиса" systemctl restart glider
    
    sleep 2
    
    if systemctl is-active --quiet glider; then
        success_message "Пользователь удалён!"
    else
        error_message "Ошибка при удалении"
    fi
    
    echo ""
    read -p " Нажмите Enter для продолжения..."
}

manage_users() {
    while true; do
        print_header
        
        echo -ne " ${LIGHT_MAGENTA}${BOX_TL}${BOX_H} "
        echo -ne "${NC}${BOLD}${WHITE}УПРАВЛЕНИЕ ПОЛЬЗОВАТЕЛЯМИ${NC} ${LIGHT_MAGENTA}"
        printf "%42s" | tr ' ' "${BOX_H}"
        echo -e "${BOX_TR}${NC}"
        echo -ne " ${LIGHT_MAGENTA}${BOX_BL}"
        printf "%70s" | tr ' ' "${BOX_H}"
        echo -e "${BOX_BR}${NC}"
        echo ""
        
        if ! check_glider_installed; then
            warning_message "Glider не установлен"
            read -p " Нажмите Enter для продолжения..."
            return
        fi
        
        list_users
        
        # Меню действий
        echo -ne " ${DARK_GRAY}${BOX_TL}"
        printf "%68s" | tr ' ' "${BOX_H}"
        echo -e "${BOX_TR}${NC}"
        echo -e " ${DARK_GRAY}${BOX_V}${NC}  ${BOLD}ДОСТУПНЫЕ ДЕЙСТВИЯ${NC}$(printf "%49s")${DARK_GRAY}${BOX_V}${NC}"
        echo -ne " ${DARK_GRAY}${BOX_VR}"
        printf "%68s" | tr ' ' "${BOX_H}"
        echo -e "${BOX_VL}${NC}"
        echo -e " ${DARK_GRAY}${BOX_V}${NC}                                                                    ${DARK_GRAY}${BOX_V}${NC}"
        echo -e " ${DARK_GRAY}${BOX_V}${NC}   ${LIGHT_GREEN}${BOLD}1${NC}  ${ICON_USER}  Добавить пользователя$(printf "%32s")${DARK_GRAY}${BOX_V}${NC}"
        echo -e " ${DARK_GRAY}${BOX_V}${NC}   ${YELLOW}${BOLD}2${NC}  @  Изменить пользователя$(printf "%33s")${DARK_GRAY}${BOX_V}${NC}"
        echo -e " ${DARK_GRAY}${BOX_V}${NC}   ${RED}${BOLD}3${NC}  ${ICON_TRASH}  Удалить пользователя$(printf "%33s")${DARK_GRAY}${BOX_V}${NC}"
        echo -e " ${DARK_GRAY}${BOX_V}${NC}   ${MAGENTA}${BOLD}4${NC}  ${ICON_DOOR}  Назад$(printf "%46s")${DARK_GRAY}${BOX_V}${NC}"
        echo -e " ${DARK_GRAY}${BOX_V}${NC}                                                                    ${DARK_GRAY}${BOX_V}${NC}"
        echo -ne " ${DARK_GRAY}${BOX_BL}"
        printf "%68s" | tr ' ' "${BOX_H}"
        echo -e "${BOX_BR}${NC}"
        echo ""
        
        read -p " ${LIGHT_CYAN}${ARROW_RIGHT}${NC} Выберите действие ${LIGHT_GREEN}[1-4]${NC}: " action
        
        case $action in
            1) add_user ;;
            2) edit_user ;;
            3) delete_user ;;
            4) return ;;
            *) error_message "Неверный выбор"; sleep 1 ;;
        esac
    done
}

# ============================================================================
# ОБНОВЛЕНИЕ СКРИПТА
# ============================================================================

update_script() {
    print_header
    
    echo -ne " ${LIGHT_BLUE}${BOX_TL}${BOX_H} "
    echo -ne "${NC}${BOLD}${WHITE}ОБНОВЛЕНИЕ СКРИПТА${NC} ${LIGHT_BLUE}"
    printf "%49s" | tr ' ' "${BOX_H}"
    echo -e "${BOX_TR}${NC}"
    echo -ne " ${LIGHT_BLUE}${BOX_BL}"
    printf "%70s" | tr ' ' "${BOX_H}"
    echo -e "${BOX_BR}${NC}"
    echo ""
    
    echo -e " ${YELLOW}${ICON_WARNING}${NC} ${GRAY}Будет загружена последняя версия скрипта${NC}"
    echo ""
    read -p " Продолжить? (y/n): " CONFIRM
    
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        return
    fi
    
    echo ""
    draw_separator
    echo ""
    
    run_with_spinner "Скачивание новой версии" \
        wget -q "$SCRIPT_URL" -O /tmp/glider-manager-new.sh
    
    run_with_spinner "Установка скрипта" \
        bash -c "cp /tmp/glider-manager-new.sh $0 && chmod +x $0"
    
    echo ""
    success_message "Скрипт обновлён!"
    echo -e " ${GRAY}Перезапустите скрипт для применения изменений${NC}"
    echo ""
    
    read -p " Нажмите Enter для выхода..."
    exit 0
}

# ============================================================================
# УДАЛЕНИЕ GLIDER
# ============================================================================

remove_glider() {
    print_header
    
    echo -ne " ${RED}${BOX_TL}${BOX_H} "
    echo -ne "${NC}${BOLD}${WHITE}УДАЛЕНИЕ GLIDER${NC} ${RED}"
    printf "%52s" | tr ' ' "${BOX_H}"
    echo -e "${BOX_TR}${NC}"
    echo -ne " ${RED}${BOX_BL}"
    printf "%70s" | tr ' ' "${BOX_H}"
    echo -e "${BOX_BR}${NC}"
    echo ""
    
    if ! check_glider_installed; then
        warning_message "Glider не установлен"
        read -p " Нажмите Enter для продолжения..."
        return
    fi
    
    echo -e " ${RED}${BOLD}${ICON_WARNING} ВНИМАНИЕ!${NC}"
    echo -e " ${GRAY}Все данные и пользователи будут удалены безвозвратно!${NC}"
    echo ""
    read -p " Вы уверены, что хотите удалить Glider? (y/n): " CONFIRM
    
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        return
    fi
    
    echo ""
    draw_separator
    echo ""
    
    run_with_spinner "Остановка службы Glider" systemctl stop glider 2>/dev/null || true
    run_with_spinner "Отключение автозапуска" systemctl disable glider 2>/dev/null || true
    run_with_spinner "Удаление systemd unit файла" rm -f "$SERVICE_FILE"
    run_with_spinner "Удаление символических ссылок" bash -c "rm -f /etc/systemd/system/multi-user.target.wants/glider.service 2>/dev/null || true"
    run_with_spinner "Удаление исполняемого файла" rm -f "$BINARY_PATH"
    run_with_spinner "Удаление конфигурации" rm -rf /etc/glider
    run_with_spinner "Очистка временных файлов" bash -c "rm -f /tmp/glider* 2>/dev/null || true"
    run_with_spinner "Перезагрузка systemd" systemctl daemon-reload
    run_with_spinner "Сброс состояния служб" systemctl reset-failed 2>/dev/null || true
    
    echo ""
    draw_separator
    echo ""
    
    success_message "Glider полностью удалён из системы!"
    
    echo -e " ${SBOX_TL}${SBOX_H} ${BOLD}Удалённые компоненты${NC}"
    echo -e " ${SBOX_V}"
    echo -e " ${SBOX_V} ${ICON_CHECK} ${DIM}Служба systemd (glider.service)${NC}"
    echo -e " ${SBOX_V} ${ICON_CHECK} ${DIM}Исполняемый файл ($BINARY_PATH)${NC}"
    echo -e " ${SBOX_V} ${ICON_CHECK} ${DIM}Конфигурационные файлы (/etc/glider/)${NC}"
    echo -e " ${SBOX_V} ${ICON_CHECK} ${DIM}Символические ссылки служб${NC}"
    echo -e " ${SBOX_V} ${ICON_CHECK} ${DIM}Временные файлы${NC}"
    echo -e " ${SBOX_V}"
    echo -e " ${SBOX_BL}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}${SBOX_H}"
    echo ""
    
    read -p " Нажмите Enter для продолжения..."
}

# ============================================================================
# ГЛАВНОЕ МЕНЮ
# ============================================================================

show_menu() {
    print_header
    show_status
    
    # Главное меню
    echo -ne " ${DARK_GRAY}${BOX_TL}"
    printf "%68s" | tr ' ' "${BOX_H}"
    echo -e "${BOX_TR}${NC}"
    echo -e " ${DARK_GRAY}${BOX_V}${NC}  ${BOLD}${WHITE}ГЛАВНОЕ МЕНЮ${NC}$(printf "%55s")${DARK_GRAY}${BOX_V}${NC}"
    echo -ne " ${DARK_GRAY}${BOX_VR}"
    printf "%68s" | tr ' ' "${BOX_H}"
    echo -e "${BOX_VL}${NC}"
    echo -e " ${DARK_GRAY}${BOX_V}${NC}                                                                    ${DARK_GRAY}${BOX_V}${NC}"
    echo -e " ${DARK_GRAY}${BOX_V}${NC}   ${LIGHT_GREEN}${BOLD}1${NC}  ${ICON_ROCKET}  Установить Glider$(printf "%37s")${DARK_GRAY}${BOX_V}${NC}"
    echo -e " ${DARK_GRAY}${BOX_V}${NC}   ${LIGHT_BLUE}${BOLD}2${NC}  ${ICON_UPDATE}  Обновить Glider$(printf "%39s")${DARK_GRAY}${BOX_V}${NC}"
    echo -e " ${DARK_GRAY}${BOX_V}${NC}   ${LIGHT_MAGENTA}${BOLD}3${NC}  ${ICON_USER}  Управление пользователями$(printf "%29s")${DARK_GRAY}${BOX_V}${NC}"
    echo -e " ${DARK_GRAY}${BOX_V}${NC}   ${ORANGE}${BOLD}4${NC}  ${ICON_GEAR}  Обновить скрипт$(printf "%39s")${DARK_GRAY}${BOX_V}${NC}"
    echo -e " ${DARK_GRAY}${BOX_V}${NC}   ${RED}${BOLD}5${NC}  ${ICON_TRASH}  Удалить Glider$(printf "%40s")${DARK_GRAY}${BOX_V}${NC}"
    echo -e " ${DARK_GRAY}${BOX_V}${NC}   ${MAGENTA}${BOLD}6${NC}  ${ICON_DOOR}  Выход$(printf "%49s")${DARK_GRAY}${BOX_V}${NC}"
    echo -e " ${DARK_GRAY}${BOX_V}${NC}                                                                    ${DARK_GRAY}${BOX_V}${NC}"
    echo -ne " ${DARK_GRAY}${BOX_BL}"
    printf "%68s" | tr ' ' "${BOX_H}"
    echo -e "${BOX_BR}${NC}"
    echo ""
    
    read -p " ${LIGHT_CYAN}${ARROW_RIGHT}${NC} Выберите действие ${LIGHT_GREEN}[1-6]${NC}: " choice
    
    case $choice in
        1) install_glider ;;
        2) update_glider ;;
        3) manage_users ;;
        4) update_script ;;
        5) remove_glider ;;
        6) 
            clear
            echo ""
            echo -ne " ${LIGHT_GREEN}${BOX_TL}"
            printf "%68s" | tr ' ' "${BOX_H}"
            echo -e "${BOX_TR}${NC}"
            echo -e " ${LIGHT_GREEN}${BOX_V}${NC}                                                                    ${LIGHT_GREEN}${BOX_V}${NC}"
            echo -e " ${LIGHT_GREEN}${BOX_V}${NC}          ${BOLD}${WHITE}${HEART} Спасибо за использование Glider Manager! ${HEART}${NC}          ${LIGHT_GREEN}${BOX_V}${NC}"
            echo -e " ${LIGHT_GREEN}${BOX_V}${NC}                                                                    ${LIGHT_GREEN}${BOX_V}${NC}"
            echo -ne " ${LIGHT_GREEN}${BOX_BL}"
            printf "%68s" | tr ' ' "${BOX_H}"
            echo -e "${BOX_BR}${NC}"
            echo ""
            exit 0
            ;;
        *) 
            error_message "Неверный выбор"
            sleep 1
            ;;
    esac
}

# ============================================================================
# ОСНОВНОЙ ЦИКЛ
# ============================================================================

check_root

while true; do
    show_menu
done
