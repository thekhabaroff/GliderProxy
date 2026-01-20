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
NC='\033[0m'

# Анимация загрузки
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\\'
    while ps -p $pid > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "      \b\b\b\b\b\b"
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
        echo -e " ${GREEN}[OK]${NC}"
    else
        echo -e " ${RED}[ERROR]${NC}"
        return $status
    fi
}

# Проверка root прав
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${RED}========================================${NC}"
        echo -e "${RED}         OSHIBKA DOSTUPA                ${NC}"
        echo -e "${RED}========================================${NC}"
        echo ""
        echo -e "${YELLOW}Pozhalujsta, zapustite skript ot root${NC}"
        echo -e "${CYAN}Ispol'zujte: ${GREEN}sudo glider${NC}"
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
        echo "ne ustanovlen"
    fi
}

# Красивое отображение списка пользователей
list_users() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}Net pol'zovatelej${NC}"
        return
    fi
    
    local count=1
    local found=0
    
    while IFS= read -r line; do
        if [[ $line =~ ^listen=mixed://([^:]+):([^@]+)@:([0-9]+) ]]; then
            username="${BASH_REMATCH[1]}"
            password="${BASH_REMATCH[2]}"
            port="${BASH_REMATCH[3]}"
            
            echo -e "${CYAN}[$count]${NC} ----------------------------------------"
            echo -e "  ${BLUE}Login:${NC}   ${GREEN}$username${NC}"
            echo -e "  ${BLUE}Parol':${NC}  ${GREEN}$password${NC}"
            echo -e "  ${BLUE}Port:${NC}    ${GREEN}$port${NC}"
            echo -e "  ${BLUE}HTTP:${NC}    http://${username}:${password}@$(hostname -I | awk '{print $1}'):${port}"
            echo -e "  ${BLUE}SOCKS5:${NC}  socks5://${username}:${password}@$(hostname -I | awk '{print $1}'):${port}"
            echo ""
            ((count++))
            found=1
        elif [[ $line =~ ^listen=mixed://:([0-9]+) ]]; then
            port="${BASH_REMATCH[1]}"
            
            echo -e "${CYAN}[$count]${NC} ----------------------------------------"
            echo -e "  ${BLUE}Port bez autentifikacii:${NC} ${GREEN}$port${NC}"
            echo ""
            ((count++))
            found=1
        fi
    done < "$CONFIG_FILE"
    
    if [ $found -eq 0 ]; then
        echo -e "${YELLOW}Pol'zovatelej ne najdeno${NC}"
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
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}       OBNOVLENIE SKRIPTA              ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    echo -e "${YELLOW}! Budet zagruzhena poslednyaya versiya skripta${NC}"
    echo ""
    read -p "Prodolzhit' obnovlenie? (y/n): " CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        return
    fi
    
    echo ""
    echo -e "${GREEN}----------------------------------------${NC}"
    echo ""
    
    # Скачиваем новую версию во временный файл
    TEMP_SCRIPT=$(mktemp)
    
    printf "${CYAN}Skachivanie novoj versii...${NC}"
    if wget -q "$SCRIPT_URL" -O "$TEMP_SCRIPT" 2>/dev/null; then
        echo -e " ${GREEN}[OK]${NC}"
    else
        echo -e " ${RED}[ERROR]${NC}"
        echo ""
        echo -e "${RED}Oshibka skachivaniya novoj versii${NC}"
        rm -f "$TEMP_SCRIPT"
        echo ""
        read -p "Nazhmite Enter dlya prodolzheniya..."
        return
    fi
    
    # Проверяем что файл не пустой
    if [ ! -s "$TEMP_SCRIPT" ]; then
        echo -e "${RED}Skachannyj fajl pust!${NC}"
        rm -f "$TEMP_SCRIPT"
        echo ""
        read -p "Nazhmite Enter dlya prodolzheniya..."
        return
    fi
    
    # Создаём резервную копию
    printf "${CYAN}Sozdanie rezervnoj kopii...${NC}"
    cp "$SCRIPT_PATH" "${SCRIPT_PATH}.backup"
    echo -e " ${GREEN}[OK]${NC}"
    
    # Устанавливаем новую версию
    printf "${CYAN}Ustanovka novoj versii...${NC}"
    cp "$TEMP_SCRIPT" "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"
    rm -f "$TEMP_SCRIPT"
    echo -e " ${GREEN}[OK]${NC}"
    
    echo ""
    echo -e "${GREEN}----------------------------------------${NC}"
    echo -e "${GREEN}[+] Skript uspeshno obnovlen!${NC}"
    echo ""
    echo -e "${YELLOW}Perezapusk skripta cherez 2 sekundy...${NC}"
    sleep 2
    
    # Перезапускаем скрипт с помощью exec
    exec "$SCRIPT_PATH" "$@"
}

# Главное меню
show_menu() {
    clear
    echo -e "${MAGENTA}========================================${NC}"
    echo -e "${MAGENTA}                                        ${NC}"
    echo -e "${MAGENTA}     ${GREEN}GLIDER PROXY MANAGER${MAGENTA}              ${NC}"
    echo -e "${MAGENTA}                                        ${NC}"
    echo -e "${MAGENTA}========================================${NC}"
    echo ""
    
    if check_glider_installed; then
        CURRENT_VERSION=$(get_current_version)
        STATUS=$(systemctl is-active glider 2>/dev/null || echo "ostanovlena")
        echo -e "  ${BLUE}Status:${NC}  $([ "$STATUS" == "active" ] && echo -e "${GREEN}[+]${NC} Ustanovlen (v$CURRENT_VERSION)" || echo -e "${RED}[-]${NC} Ustanovlen (v$CURRENT_VERSION)")"
        echo -e "  ${BLUE}Sluzhba:${NC}  $([ "$STATUS" == "active" ] && echo -e "${GREEN}[+]${NC} Zapushhena" || echo -e "${RED}[-]${NC} Ostanovlena")"
    else
        echo -e "  ${BLUE}Status:${NC}  ${YELLOW}[-]${NC} Ne ustanovlen"
    fi
    
    echo ""
    echo -e "${CYAN}----------------------------------------${NC}"
    echo -e "${CYAN}  1. ${GREEN}Ustanovit' Glider${NC}"
    echo -e "${CYAN}  2. ${BLUE}Obnovit' Glider${NC}"
    echo -e "${CYAN}  3. ${YELLOW}Upravlenie pol'zovatelyami${NC}"
    echo -e "${CYAN}  4. ${BLUE}Obnovit' skript${NC}"
    echo -e "${CYAN}  5. ${RED}Udalit' Glider${NC}"
    echo -e "${CYAN}  6. ${MAGENTA}Vyxod${NC}"
    echo -e "${CYAN}----------------------------------------${NC}"
    echo ""
    read -p "$(echo -e ${CYAN}Vyberite dejstvie ${GREEN}[1-6]${CYAN}: ${NC})" choice
    
    case $choice in
        1) install_glider ;;
        2) update_glider ;;
        3) manage_users ;;
        4) update_script ;;
        5) remove_glider ;;
        6) clear; echo -e "${GREEN}Spasibo za ispol'zovanie Glider Manager!${NC}"; echo ""; exit 0 ;;
        *) echo -e "${RED}[!] Nevernyj vybor${NC}"; sleep 1 ;;
    esac
}

# Основной цикл
check_root

while true; do
    show_menu
done
