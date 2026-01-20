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

# Symbols
CHECK="✓"
CROSS="✗"
ARROW="→"
ROCKET="🚀"
GEAR="⚙"
USER="👤"
TRASH="🗑"
UPDATE="⬆"
WARNING="⚠"
INFO="ℹ"
DOOR="🚪"

# ============================================================================
# ФУНКЦИИ ВЫВОДА
# ============================================================================

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
        printf " ${CYAN}[%c]${NC} " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf " \b\b\b\b"
}

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

draw_line() {
    local width="${1:-60}"
    echo -e " ${CYAN}$(printf \"%${width}s\" | tr ' ' \"$BOX_H\")${NC}"
}

print_header() {
    clear
    echo ""
    echo -e "${PURPLE}${BOLD}"
    echo " ${BOX_TL}$(printf \"%58s\" | tr ' ' \"$BOX_H\")${BOX_TR}"
    echo " ${BOX_V}$(printf \"%58s\" \" \")${BOX_V}"
    if $USE_UTF8; then
        echo " ${BOX_V} ${ICON_ROCKET} ${LIGHT_CYAN}GLIDER PROXY MANAGER${PURPLE} ${ICON_ROCKET} ${BOX_V}"
    else
        echo " ${BOX_V} GLIDER PROXY MANAGER ${BOX_V}"
    fi
    echo " ${BOX_V}$(printf \"%58s\" \" \")${BOX_V}"
    echo " ${BOX_BL}$(printf \"%58s\" | tr ' ' \"$BOX_H\")${BOX_BR}"
    echo -e "${NC}"
}

show_status() {
    echo ""
    echo -e "${CYAN}${BOLD}${ICON_INFO} СТАТУС СИСТЕМЫ${NC}"
    draw_line 60
    
    if check_glider_installed; then
        local version=$(get_current_version)
        local status=$(systemctl is-active glider 2>/dev/null || echo "stopped")
        
        if [ "$status" == "active" ]; then
            echo -e " ${GREEN}${ICON_CHECK}${NC} Версия: ${GREEN}${version}${NC}"
            echo -e " ${GREEN}${ICON_CHECK}${NC} Установлен: ${GREEN}ДА${NC}"
            echo -e " ${GREEN}${ICON_CHECK}${NC} Служба: ${GREEN}ЗАПУЩЕНА${NC}"
        else
            echo -e " ${YELLOW}${ICON_WARNING}${NC} Версия: ${YELLOW}${version}${NC}"
            echo -e " ${YELLOW}${ICON_WARNING}${NC} Установлен: ${YELLOW}ДА${NC}"
            echo -e " ${RED}${ICON_CROSS}${NC} Служба: ${RED}ОСТАНОВЛЕНА${NC}"
        fi
    else
        echo -e " ${YELLOW}${ICON_WARNING}${NC} Glider: ${YELLOW}НЕ УСТАНОВЛЕН${NC}"
        echo -e " ${DIM}Используйте пункт 1 для установки${NC}"
    fi
    echo ""
}

success_message() {
    echo -e "\n${GREEN}${BOLD}${CHECK} $1${NC}\n"
}

error_message() {
    echo -e "\n${RED}${BOLD}${CROSS} $1${NC}\n"
}

warning_message() {
    echo -e "\n${YELLOW}${BOLD}${WARNING} $1${NC}\n"
}

# ============================================================================
# ПРОВЕРКИ И УТИЛИТЫ
# ============================================================================

check_root() {
    if [ "$EUID" -ne 0 ]; then
        clear
        echo -e "${RED}${BOLD}"
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║                       ОШИБКА ДОСТУПА                         ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo -e "${NC}"
        echo -e " ${YELLOW}${WARNING} Для запуска требуются права суперпользователя${NC}"
        echo ""
        echo -e " ${CYAN}Используйте:${NC} ${GREEN}sudo ./glider-manager.sh${NC}"
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

spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    
    while kill -0 $pid 2>/dev/null; do
        local temp=${spinstr#?}
        printf " ${CYAN}[%c]${NC} " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf " \b\b\b\b"
}

run_with_spinner() {
    local message=$1
    shift
    printf "${CYAN}${message}${NC}"
    ("$@") > /dev/null 2>&1 &
    spinner $!
    wait $!
    local status=$?
    if [ $status -eq 0 ]; then
        echo -e " ${GREEN}${CHECK}${NC}"
    else
        echo -e " ${RED}${CROSS}${NC}"
        return $status
    fi
}

# ============================================================================
# УСТАНОВКА GLIDER
# ============================================================================

install_glider() {
    print_header
    show_status
    
    if check_glider_installed; then
        warning_message "Glider уже установлен"
        echo -e " ${CYAN}Используйте 'Обновить' для переустановки${NC}\n"
        read -p " Нажмите Enter..."
        return
    fi
    
    echo -e " ${CYAN}${ARROW} Настройка первого пользователя${NC}\n"
    
    read -p " Введите порт для прокси [18443]: " PROXY_PORT
    PROXY_PORT=${PROXY_PORT:-18443}
    
    read -p " Добавить аутентификацию? (y/n) [n]: " ADD_AUTH
    
    if [[ "$ADD_AUTH" == "y" || "$ADD_AUTH" == "Y" ]]; then
        read -p " Введите логин: " PROXY_USER
        read -sp " Введите пароль: " PROXY_PASS
        echo
        LISTEN_STRING="listen=mixed://${PROXY_USER}:${PROXY_PASS}@:${PROXY_PORT}"
    else
        LISTEN_STRING="listen=mixed://:${PROXY_PORT}"
    fi
    
    echo ""
    draw_line
    echo -e "\n ${CYAN}Начинается установка...${NC}\n"
    
    run_with_spinner " Обновление списка пакетов..." apt update
    run_with_spinner " Установка зависимостей..." apt install -y curl wget tar
    
    cd /tmp
    rm -rf glider_* glider.tar.gz 2>/dev/null || true
    
    run_with_spinner " Скачивание Glider v${VERSION}..." \
        wget -q "https://github.com/nadoo/glider/releases/download/v${VERSION}/glider_${VERSION}_linux_amd64.tar.gz" -O glider.tar.gz
    
    run_with_spinner " Распаковка архива..." tar -xzf glider.tar.gz
    run_with_spinner " Установка бинарного файла..." \
        bash -c "find . -name 'glider' -type f -exec cp {} $BINARY_PATH \; && chmod +x $BINARY_PATH"
    
    mkdir -p /etc/glider
    
    cat > $CONFIG_FILE <<EOF
# Glider Configuration
# Generated by Glider Manager v${VERSION}

listen=$LISTEN_STRING

forward=http://127.0.0.1:8080
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

[Install]
WantedBy=multi-user.target
EOF
    
    run_with_spinner " Регистрация systemd служба..." systemctl daemon-reload
    run_with_spinner " Включение автозапуска..." systemctl enable glider
    run_with_spinner " Запуск Glider..." systemctl start glider
    
    sleep 2
    
    echo ""
    draw_line
    echo ""
    
    if systemctl is-active --quiet glider; then
        success_message "Glider успешно установлен!"
        echo -e " ${GRAY}Версия:${NC} ${GREEN}$(get_current_version)${NC}"
        echo -e " ${GRAY}Порт:${NC} ${GREEN}${PROXY_PORT}${NC}"
        if [[ "$ADD_AUTH" == "y" || "$ADD_AUTH" == "Y" ]]; then
            echo -e " ${GRAY}Логин:${NC} ${GREEN}${PROXY_USER}${NC}"
            echo -e " ${GRAY}Пароль:${NC} ${GREEN}${PROXY_PASS}${NC}"
        fi
    else
        error_message "Ошибка установки. Проверьте логи:"
        systemctl status glider || true
    fi
    
    read -p " Нажмите Enter..."
}

# ============================================================================
# ОБНОВЛЕНИЕ GLIDER
# ============================================================================

update_glider() {
    print_header
    show_status
    
    if ! check_glider_installed; then
        warning_message "Glider не установлен"
        read -p " Нажмите Enter..."
        return
    fi
    
    echo ""
    echo -e " ${WARNING} Будет загружена новая версия"
    read -p " Продолжить обновление? (y/n): " CONFIRM
    
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        return
    fi
    
    echo ""
    draw_line
    echo ""
    
    cd /tmp
    rm -rf glider_* glider.tar.gz 2>/dev/null || true
    
    run_with_spinner " Скачивание Glider v${VERSION}..." \
        wget -q "https://github.com/nadoo/glider/releases/download/v${VERSION}/glider_${VERSION}_linux_amd64.tar.gz" -O glider.tar.gz
    
    run_with_spinner " Создание резервной копии..." cp $CONFIG_FILE ${CONFIG_FILE}.backup
    run_with_spinner " Остановка сервиса..." systemctl stop glider
    run_with_spinner " Распаковка архива..." tar -xzf glider.tar.gz
    run_with_spinner " Установка новой версии..." \
        bash -c "find . -name 'glider' -type f -exec cp {} $BINARY_PATH \; && chmod +x $BINARY_PATH"
    run_with_spinner " Запуск сервиса..." systemctl start glider
    
    sleep 2
    
    echo ""
    draw_line
    echo ""
    
    if systemctl is-active --quiet glider; then
        success_message "Обновление завершено!"
        echo -e " ${GRAY}Новая версия:${NC} ${GREEN}$(get_current_version)${NC}"
    else
        error_message "Ошибка после обновления"
    fi
    
    read -p " Нажмите Enter..."
}

# ============================================================================
# УПРАВЛЕНИЕ ПОЛЬЗОВАТЕЛЯМИ
# ============================================================================

list_users() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo ""
        echo -e " ${YELLOW}${DIM}Пользователей не найдено${NC}"
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
            echo -e " ${LIGHT_CYAN}${BOX_TL}$(printf \"%57s\" | tr ' ' \"$BOX_H\")${BOX_TR}${NC}"
            echo -e " ${LIGHT_CYAN}${BOX_V}${NC} ${BOLD}${ICON_USER} Пользователь #${count}${NC}"
            echo -e " ${LIGHT_CYAN}${BOX_V}${NC}"
            echo -e " ${LIGHT_CYAN}${BOX_V}${NC} ${GRAY}Логин:${NC} ${GREEN}${username}${NC}"
            echo -e " ${LIGHT_CYAN}${BOX_V}${NC} ${GRAY}Пароль:${NC} ${GREEN}${password}${NC}"
            echo -e " ${LIGHT_CYAN}${BOX_V}${NC} ${GRAY}Порт:${NC} ${GREEN}${port}${NC}"
            echo -e " ${LIGHT_CYAN}${BOX_V}${NC}"
            echo -e " ${LIGHT_CYAN}${BOX_V}${NC} ${GRAY}HTTP:${NC}"
            echo -e " ${LIGHT_CYAN}${BOX_V}${NC} ${BLUE}http://${username}:${password}@\$(hostname -I | awk '{print \$1}'):${port}${NC}"
            echo -e " ${LIGHT_CYAN}${BOX_V}${NC}"
            echo -e " ${LIGHT_CYAN}${BOX_V}${NC} ${GRAY}SOCKS5:${NC}"
            echo -e " ${LIGHT_CYAN}${BOX_V}${NC} ${BLUE}socks5://${username}:${password}@\$(hostname -I | awk '{print \$1}'):${port}${NC}"
            echo -e " ${LIGHT_CYAN}${BOX_BL}$(printf \"%57s\" | tr ' ' \"$BOX_H\")${BOX_BR}${NC}"
            echo ""
            ((count++))
            found=1
        elif [[ $line =~ ^listen=mixed://:([0-9]+) ]]; then
            port="${BASH_REMATCH[1]}"
            echo -e " ${LIGHT_CYAN}${BOX_TL}$(printf \"%57s\" | tr ' ' \"$BOX_H\")${BOX_TR}${NC}"
            echo -e " ${LIGHT_CYAN}${BOX_V}${NC} ${BOLD}Порт без аутентификации #${count}${NC}"
            echo -e " ${LIGHT_CYAN}${BOX_V}${NC}"
            echo -e " ${LIGHT_CYAN}${BOX_V}${NC} ${GRAY}Порт:${NC} ${GREEN}${port}${NC}"
            echo -e " ${LIGHT_CYAN}${BOX_BL}$(printf \"%57s\" | tr ' ' \"$BOX_H\")${BOX_BR}${NC}"
            echo ""
            ((count++))
            found=1
        fi
    done < "$CONFIG_FILE"
    
    if [ $found -eq 0 ]; then
        echo -e " ${YELLOW}${DIM}Пользователей не найдено${NC}"
        echo ""
    fi
}

add_user() {
    print_header
    echo ""
    echo -e " ${GREEN}${BOLD}${ICON_USER} ДОБАВЛЕНИЕ ПОЛЬЗОВАТЕЛЯ${NC}"
    echo ""
    draw_line 60
    echo ""
    if ! check_glider_installed; then
        echo -e " ${YELLOW}${ICON_WARNING} Glider не установлен${NC}"
        echo ""
        read -p " Нажмите Enter..."
        return
    fi
    
    echo -e " ${CYAN}${ICON_ARROW} Создание нового пользователя${NC}"
    echo ""
    read -p " Введите новый логин: " NEW_USER
    if [ -z "$NEW_USER" ]; then
        error_message "Логин не может быть пустым"
        sleep 2
        return
    fi
    
    read -sp " Введите новый пароль: " NEW_PASS
    echo
    if [ -z "$NEW_PASS" ]; then
        error_message "Пароль не может быть пустым"
        sleep 2
        return
    fi
    
    read -p " Введите порт для этого пользователя: " NEW_PORT
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
    draw_line 60
    echo ""
    
    run_with_spinner " Добавление пользователя..." \
        sed -i "/^# HTTP + SOCKS5/a listen=mixed://${NEW_USER}:${NEW_PASS}@:${NEW_PORT}" $CONFIG_FILE
    
    run_with_spinner " Перезапуск сервиса..." systemctl restart glider
    
    sleep 2
    echo ""
    
    if systemctl is-active --quiet glider; then
        success_message "Пользователь добавлен успешно!"
        echo -e " ${GRAY}Логин:${NC} ${GREEN}${NEW_USER}${NC}"
        echo -e " ${GRAY}Пароль:${NC} ${GREEN}${NEW_PASS}${NC}"
        echo -e " ${GRAY}Порт:${NC} ${GREEN}${NEW_PORT}${NC}"
    else
        error_message "Ошибка при добавлении пользователя"
    fi
    
    read -p " Нажмите Enter для продолжения..."
}

edit_user() {
    print_header
    echo ""
    echo -e " ${YELLOW}${BOLD}${ICON_USER} ИЗМЕНЕНИЕ ПОЛЬЗОВАТЕЛЯ${NC}"
    echo ""
    draw_line 60
    
    if ! check_glider_installed; then
        echo -e " ${YELLOW}${ICON_WARNING} Glider не установлен${NC}"
        echo ""
        read -p " Нажмите Enter..."
        return
    fi
    
    local user_count=0
    if [ -f "$CONFIG_FILE" ]; then
        user_count=$(grep -c "^listen=" "$CONFIG_FILE" 2>/dev/null || echo "0")
    fi
    
    if [ "$user_count" -eq 0 ]; then
        echo ""
        echo -e " ${YELLOW}Нет пользователей для изменения${NC}"
        echo ""
        sleep 2
        return
    fi
    
    list_users
    
    echo -e " ${CYAN}${ICON_ARROW} Выберите пользователя для изменения${NC}"
    echo ""
    read -p " Введите номер пользователя: " user_num
    
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
    draw_line 60
    echo ""
    echo -e " ${CYAN}${ICON_ARROW} Изменение пользователя${NC}"
    echo ""
    read -p " Новый логин [$old_username]: " new_username
    new_username=${new_username:-$old_username}
    read -sp " Новый пароль [оставить текущий]: " new_password
    echo
    new_password=${new_password:-$old_password}
    read -p " Новый порт [$old_port]: " new_port
    new_port=${new_port:-$old_port}
    
    if [ "$new_port" != "$old_port" ] && check_port_used "$new_port"; then
        error_message "Порт $new_port уже используется!"
        sleep 2
        return
    fi
    
    echo ""
    draw_line 60
    echo ""
    
    run_with_spinner " Изменение пользователя..." \
        sed -i "s|^listen=.*:${old_port}\$|listen=mixed://${new_username}:${new_password}@:${new_port}|" $CONFIG_FILE
    
    run_with_spinner " Перезапуск сервиса..." systemctl restart glider
    
    sleep 2
    
    if systemctl is-active --quiet glider; then
        success_message "Пользователь изменён успешно!"
    else
        error_message "Ошибка при изменении"
    fi
    
    read -p " Нажмите Enter для продолжения..."
}

delete_user() {
    print_header
    echo ""
    echo -e " ${RED}${BOLD}${ICON_TRASH} УДАЛЕНИЕ ПОЛЬЗОВАТЕЛЯ${NC}"
    echo ""
    draw_line 60
    
    if ! check_glider_installed; then
        echo -e " ${YELLOW}${ICON_WARNING} Glider не установлен${NC}"
        echo ""
        read -p " Нажмите Enter..."
        return
    fi
    
    local user_count=0
    if [ -f "$CONFIG_FILE" ]; then
        user_count=$(grep -c "^listen=" "$CONFIG_FILE" 2>/dev/null || echo "0")
    fi
    
    if [ "$user_count" -le 1 ]; then
        echo ""
        echo -e " ${RED}${ICON_CROSS} Нельзя удалить последнего пользователя!${NC}"
        echo -e " ${YELLOW}Используйте 'Удалить Glider' для полного удаления${NC}"
        echo ""
        sleep 2
        return
    fi
    
    list_users
    
    echo -e " ${CYAN}${ICON_ARROW} Выберите пользователя для удаления${NC}"
    echo ""
    read -p " Введите номер пользователя: " user_num
    
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
    read -p " Удалить пользователя '$username' на порту $port? (y/n): " CONFIRM
    
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        return
    fi
    
    echo ""
    draw_line 60
    echo ""
    
    run_with_spinner " Удаление пользователя..." \
        sed -i "/^listen=.*:${port}\$/d" $CONFIG_FILE
    
    run_with_spinner " Перезапуск сервиса..." systemctl restart glider
    
    sleep 2
    
    if systemctl is-active --quiet glider; then
        success_message "Пользователь удалён!"
    else
        error_message "Ошибка при удалении"
    fi
    
    read -p " Нажмите Enter для продолжения..."
}

manage_users() {
    while true; do
        print_header
        echo ""
        echo -e " ${BLUE}${BOLD}${ICON_USER} УПРАВЛЕНИЕ ПОЛЬЗОВАТЕЛЯМИ${NC}"
        echo ""
        draw_line 60
        
        if ! check_glider_installed; then
            echo ""
            echo -e " ${YELLOW}${ICON_WARNING} Glider не установлен${NC}"
            echo ""
            read -p " Нажмите Enter для продолжения..."
            return
        fi
        
        list_users
        
        local user_count=0
        if [ -f "$CONFIG_FILE" ]; then
            user_count=$(grep -c "^listen=" "$CONFIG_FILE" 2>/dev/null || echo "0")
        fi
        
        echo -e " ${LIGHT_CYAN}${BOX_TL}$(printf \"%57s\" | tr ' ' \"$BOX_H\")${BOX_TR}${NC}"
        echo -e " ${LIGHT_CYAN}${BOX_V}${NC}"
        echo -e " ${LIGHT_CYAN}${BOX_V}${NC} ${GREEN}1.${NC} Добавить пользователя"
        echo -e " ${LIGHT_CYAN}${BOX_V}${NC} ${YELLOW}2.${NC} Изменить пользователя"
        echo -e " ${LIGHT_CYAN}${BOX_V}${NC} ${RED}3.${NC} Удалить пользователя"
        echo -e " ${LIGHT_CYAN}${BOX_V}${NC} ${MAGENTA}4.${NC} Назад"
        echo -e " ${LIGHT_CYAN}${BOX_V}${NC}"
        echo -e " ${LIGHT_CYAN}${BOX_BL}$(printf \"%57s\" | tr ' ' \"$BOX_H\")${BOX_BR}${NC}"
        echo ""
        
        read -p " $(echo -e ${CYAN}Выберите действие ${GREEN}[1-4]${CYAN}: ${NC})" action
        
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
# УДАЛЕНИЕ GLIDER
# ============================================================================

remove_glider() {
    print_header
    echo ""
    echo -e " ${RED}${BOLD}${ICON_TRASH} УДАЛЕНИЕ GLIDER${NC}"
    echo ""
    draw_line 60
    echo ""
    
    if ! check_glider_installed; then
        echo -e " ${YELLOW}${ICON_WARNING} Glider не установлен${NC}"
        echo ""
        read -p " Нажмите Enter для продолжения..."
        return
    fi
    
    echo -e " ${YELLOW}${ICON_WARNING} ВНИМАНИЕ: Все данные и пользователи будут удалены!${NC}"
    echo ""
    read -p " Вы уверены, что хотите удалить Glider? (y/n): " CONFIRM
    
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        return
    fi
    
    echo ""
    draw_line 60
    echo ""
    
    run_with_spinner " Остановка службы Glider..." systemctl stop glider 2>/dev/null || true
    run_with_spinner " Отключение автозапуска..." systemctl disable glider 2>/dev/null || true
    run_with_spinner " Удаление systemd unit файла..." rm -f "$SERVICE_FILE"
    run_with_spinner " Удаление символических ссылок..." bash -c "rm -f /etc/systemd/system/multi-user.target.wants/glider.service 2>/dev/null || true"
    run_with_spinner " Удаление исполняемого файла..." rm -f "$BINARY_PATH"
    run_with_spinner " Удаление конфигурации..." rm -rf /etc/glider
    run_with_spinner " Очистка временных файлов..." bash -c "rm -f /tmp/glider* 2>/dev/null || true"
    run_with_spinner " Перезагрузка systemd..." systemctl daemon-reload
    run_with_spinner " Сброс состояния служб..." systemctl reset-failed 2>/dev/null || true
    
    echo ""
    draw_line 60
    echo ""
    success_message "Glider полностью удалён из системы!"
    echo ""
    echo -e " ${CYAN}${ICON_INFO} Удалённые компоненты:${NC}"
    echo -e " ${DIM}• Служба systemd (glider.service)${NC}"
    echo -e " ${DIM}• Исполняемый файл ($BINARY_PATH)${NC}"
    echo -e " ${DIM}• Конфигурационные файлы (/etc/glider/)${NC}"
    echo -e " ${DIM}• Символические ссылки служб${NC}"
    echo -e " ${DIM}• Временные файлы${NC}"
    echo ""
    
    read -p " Нажмите Enter для продолжения..."
}

# ============================================================================
# ГЛАВНОЕ МЕНЮ
# ============================================================================

show_menu() {
    print_header
    show_status
    
    echo -e " ${CYAN}${BOLD}${ICON_GEAR} ДОСТУПНЫЕ ДЕЙСТВИЯ${NC}"
    echo ""
    draw_line 60
    echo ""
    echo -e " ${LIGHT_CYAN}${BOX_TL}$(printf \"%57s\" | tr ' ' \"$BOX_H\")${BOX_TR}${NC}"
    echo -e " ${LIGHT_CYAN}${BOX_V}${NC}"
    echo -e " ${LIGHT_CYAN}${BOX_V}${NC} ${GREEN}1.${NC} ${ICON_GEAR} Установить Glider"
    echo -e " ${LIGHT_CYAN}${BOX_V}${NC} ${BLUE}2.${NC} ${ICON_UPDATE} Обновить Glider"
    echo -e " ${LIGHT_CYAN}${BOX_V}${NC} ${YELLOW}3.${NC} ${ICON_USER} Управление пользователями"
    echo -e " ${LIGHT_CYAN}${BOX_V}${NC} ${LIGHT_BLUE}4.${NC} ${ICON_UPDATE} Обновить скрипт"
    echo -e " ${LIGHT_CYAN}${BOX_V}${NC} ${RED}5.${NC} ${ICON_TRASH} Удалить Glider"
    echo -e " ${LIGHT_CYAN}${BOX_V}${NC} ${MAGENTA}6.${NC} ${ICON_DOOR} Выход"
    echo -e " ${LIGHT_CYAN}${BOX_V}${NC}"
    echo -e " ${LIGHT_CYAN}${BOX_BL}$(printf \"%57s\" | tr ' ' \"$BOX_H\")${BOX_BR}${NC}"
    echo ""
    
    read -p " $(echo -e ${CYAN}Выберите действие ${GREEN}[1-6]${CYAN}: ${NC})" choice
    
    case $choice in
        1) install_glider ;;
        2) update_glider ;;
        3) manage_users ;;
        4) update_script ;;
        5) remove_glider ;;
        6) 
            clear
            echo ""
            echo -e " ${GREEN}${BOLD}Спасибо за использование Glider Manager!${NC}"
            echo ""
            exit 0
            ;;
        *) error_message "Неверный выбор"; sleep 1 ;;
    esac
}

# ============================================================================
# ОСНОВНОЙ ЦИКЛ
# ============================================================================

check_root

while true; do
    show_menu
done
