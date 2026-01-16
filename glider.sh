#!/bin/bash

# Скрипт управления Glider Proxy Server
# Использование: glider-menu

set -e

CONFIG_FILE="/etc/glider/glider.conf"
SERVICE_FILE="/etc/systemd/system/glider.service"
BINARY_PATH="/usr/local/bin/glider"
VERSION="0.16.4"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Проверка root прав
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${RED}Пожалуйста, запустите скрипт от root (sudo glider-menu)${NC}"
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
        $BINARY_PATH -help 2>&1 | grep -o "glider [0-9.]*" | awk '{print $2}'
    else
        echo "не установлен"
    fi
}

# Получение списка пользователей
list_users() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Нет пользователей"
        return
    fi
    
    echo -e "${GREEN}=== Текущие пользователи ===${NC}"
    echo ""
    
    grep "^listen=mixed://" $CONFIG_FILE | while read line; do
        if [[ $line =~ mixed://([^:]+):([^@]+)@:([0-9]+) ]]; then
            username="${BASH_REMATCH[1]}"
            password="${BASH_REMATCH[2]}"
            port="${BASH_REMATCH[3]}"
            echo -e "${BLUE}Пользователь:${NC} $username"
            echo -e "${BLUE}Пароль:${NC} $password"
            echo -e "${BLUE}Порт:${NC} $port"
            echo "---"
        elif [[ $line =~ mixed://:([0-9]+) ]]; then
            port="${BASH_REMATCH[1]}"
            echo -e "${BLUE}Порт без аутентификации:${NC} $port"
            echo "---"
        fi
    done
}

# Проверка занятости порта
check_port_used() {
    local port=$1
    if grep -q ":${port}" $CONFIG_FILE 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Установка Glider
install_glider() {
    echo -e "${GREEN}=== Установка Glider ===${NC}"
    
    if check_glider_installed; then
        echo -e "${YELLOW}Glider уже установлен. Используйте 'Обновить' для переустановки.${NC}"
        read -p "Нажмите Enter для продолжения..."
        return
    fi
    
    # Запрос параметров для первого пользователя
    read -p "Введите порт для прокси (по умолчанию 18443): " PROXY_PORT
    PROXY_PORT=${PROXY_PORT:-18443}
    
    read -p "Добавить аутентификацию? (y/n, по умолчанию n): " ADD_AUTH
    ADD_AUTH=${ADD_AUTH:-n}
    
    if [[ "$ADD_AUTH" == "y" || "$ADD_AUTH" == "Y" ]]; then
        read -p "Введите логин: " PROXY_USER
        read -sp "Введите пароль: " PROXY_PASS
        echo
        LISTEN_STRING="listen=mixed://${PROXY_USER}:${PROXY_PASS}@:${PROXY_PORT}"
    else
        LISTEN_STRING="listen=mixed://:${PROXY_PORT}"
    fi
    
    # Установка зависимостей
    echo -e "${GREEN}Установка зависимостей...${NC}"
    apt update > /dev/null 2>&1
    apt install curl wget tar -y > /dev/null 2>&1
    
    # Скачивание Glider
    echo -e "${GREEN}Скачивание Glider v${VERSION}...${NC}"
    cd /tmp
    rm -rf glider_* glider.tar.gz 2>/dev/null || true
    
    wget -q "https://github.com/nadoo/glider/releases/download/v${VERSION}/glider_${VERSION}_linux_amd64.tar.gz" -O glider.tar.gz
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Ошибка скачивания. Попытка скачать deb пакет...${NC}"
        wget -q "https://github.com/nadoo/glider/releases/download/v${VERSION}/glider_${VERSION}_linux_amd64.deb" -O glider.deb
        dpkg -i glider.deb > /dev/null 2>&1
        apt --fix-broken install -y > /dev/null 2>&1
    else
        tar -xzf glider.tar.gz
        find . -name "glider" -type f -exec cp {} $BINARY_PATH \;
        chmod +x $BINARY_PATH
    fi
    
    # Проверка установки
    if ! check_glider_installed; then
        echo -e "${RED}Ошибка установки бинарного файла${NC}"
        exit 1
    fi
    
    # Создание конфигурации
    echo -e "${GREEN}Создание конфигурации...${NC}"
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
    
    # Создание systemd службы
    echo -e "${GREEN}Создание systemd службы...${NC}"
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
    
    # Запуск службы
    echo -e "${GREEN}Запуск службы...${NC}"
    systemctl daemon-reload > /dev/null 2>&1
    systemctl enable glider > /dev/null 2>&1
    systemctl start glider > /dev/null 2>&1
    
    sleep 2
    
    if systemctl is-active --quiet glider; then
        echo -e "${GREEN}=== Установка завершена успешно! ===${NC}"
        echo ""
        echo "Порт: $PROXY_PORT"
        echo "HTTP прокси: http://$(hostname -I | awk '{print $1}'):${PROXY_PORT}"
        echo "SOCKS5 прокси: socks5://$(hostname -I | awk '{print $1}'):${PROXY_PORT}"
        
        if [[ "$ADD_AUTH" == "y" || "$ADD_AUTH" == "Y" ]]; then
            echo ""
            echo "Логин: $PROXY_USER"
            echo "Пароль: $PROXY_PASS"
            echo ""
            echo "Пример использования:"
            echo "curl -x http://${PROXY_USER}:${PROXY_PASS}@$(hostname -I | awk '{print $1}'):${PROXY_PORT} https://ifconfig.me"
        else
            echo ""
            echo "Пример использования:"
            echo "curl -x http://$(hostname -I | awk '{print $1}'):${PROXY_PORT} https://ifconfig.me"
        fi
        
        echo ""
        echo "Управление: systemctl {start|stop|restart|status} glider"
    else
        echo -e "${RED}=== ОШИБКА: служба не запустилась ===${NC}"
        echo "Проверьте логи: journalctl -u glider -n 50"
    fi
    
    read -p "Нажмите Enter для продолжения..."
}

# Обновление Glider
update_glider() {
    echo -e "${GREEN}=== Обновление Glider ===${NC}"
    
    if ! check_glider_installed; then
        echo -e "${YELLOW}Glider не установлен. Используйте 'Установить'.${NC}"
        read -p "Нажмите Enter для продолжения..."
        return
    fi
    
    CURRENT_VERSION=$(get_current_version)
    echo "Текущая версия: $CURRENT_VERSION"
    echo "Новая версия: $VERSION"
    
    read -p "Продолжить обновление? (y/n): " CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        return
    fi
    
    # Остановка службы
    echo -e "${GREEN}Остановка службы...${NC}"
    systemctl stop glider > /dev/null 2>&1
    
    # Резервная копия конфигурации
    cp $CONFIG_FILE /tmp/glider.conf.backup
    
    # Скачивание новой версии
    echo -e "${GREEN}Скачивание Glider v${VERSION}...${NC}"
    cd /tmp
    rm -rf glider_* glider.tar.gz 2>/dev/null || true
    
    wget -q "https://github.com/nadoo/glider/releases/download/v${VERSION}/glider_${VERSION}_linux_amd64.tar.gz" -O glider.tar.gz
    
    if [ $? -eq 0 ]; then
        tar -xzf glider.tar.gz
        find . -name "glider" -type f -exec cp {} $BINARY_PATH \;
        chmod +x $BINARY_PATH
    else
        echo -e "${RED}Ошибка скачивания${NC}"
        systemctl start glider > /dev/null 2>&1
        read -p "Нажмите Enter для продолжения..."
        return
    fi
    
    # Восстановление конфигурации
    cp /tmp/glider.conf.backup $CONFIG_FILE
    
    # Запуск службы
    systemctl start glider > /dev/null 2>&1
    
    if systemctl is-active --quiet glider; then
        echo -e "${GREEN}Обновление завершено успешно!${NC}"
        echo "Новая версия: $(get_current_version)"
    else
        echo -e "${RED}Ошибка запуска после обновления${NC}"
    fi
    
    read -p "Нажмите Enter для продолжения..."
}

# Добавление пользователя
add_user() {
    echo -e "${GREEN}=== Добавление пользователя ===${NC}"
    
    if ! check_glider_installed; then
        echo -e "${YELLOW}Glider не установлен.${NC}"
        read -p "Нажмите Enter для продолжения..."
        return
    fi
    
    echo ""
    list_users
    echo ""
    
    read -p "Введите новый логин: " NEW_USER
    read -sp "Введите новый пароль: " NEW_PASS
    echo
    read -p "Введите порт для этого пользователя: " NEW_PORT
    
    # Проверка занятости порта
    if check_port_used "$NEW_PORT"; then
        echo -e "${RED}Порт $NEW_PORT уже используется!${NC}"
        read -p "Нажмите Enter для продолжения..."
        return
    fi
    
    # Добавление новой строки listen в конфигурацию
    sed -i "/^# HTTP + SOCKS5 прокси/a listen=mixed://${NEW_USER}:${NEW_PASS}@:${NEW_PORT}" $CONFIG_FILE
    
    systemctl restart glider > /dev/null 2>&1
    
    sleep 2
    
    if systemctl is-active --quiet glider; then
        echo -e "${GREEN}Пользователь добавлен успешно!${NC}"
        echo ""
        echo "Логин: $NEW_USER"
        echo "Пароль: $NEW_PASS"
        echo "Порт: $NEW_PORT"
        echo ""
        echo "HTTP прокси: http://${NEW_USER}:${NEW_PASS}@$(hostname -I | awk '{print $1}'):${NEW_PORT}"
        echo "SOCKS5 прокси: socks5://${NEW_USER}:${NEW_PASS}@$(hostname -I | awk '{print $1}'):${NEW_PORT}"
    else
        echo -e "${RED}Ошибка при добавлении пользователя${NC}"
        echo "Проверьте логи: journalctl -u glider -n 20"
    fi
    
    read -p "Нажмите Enter для продолжения..."
}

# Удаление пользователя
remove_user() {
    echo -e "${YELLOW}=== Удаление пользователя ===${NC}"
    
    if ! check_glider_installed; then
        echo -e "${YELLOW}Glider не установлен.${NC}"
        read -p "Нажмите Enter для продолжения..."
        return
    fi
    
    echo ""
    list_users
    echo ""
    
    read -p "Введите порт пользователя для удаления: " REMOVE_PORT
    
    if ! check_port_used "$REMOVE_PORT"; then
        echo -e "${RED}Порт $REMOVE_PORT не найден в конфигурации!${NC}"
        read -p "Нажмите Enter для продолжения..."
        return
    fi
    
    # Подсчёт количества listen строк
    LISTEN_COUNT=$(grep -c "^listen=" $CONFIG_FILE)
    
    if [ "$LISTEN_COUNT" -le 1 ]; then
        echo -e "${RED}Нельзя удалить последнего пользователя! Используйте 'Удалить Glider' для полного удаления.${NC}"
        read -p "Нажмите Enter для продолжения..."
        return
    fi
    
    read -p "Вы уверены, что хотите удалить пользователя на порту $REMOVE_PORT? (y/n): " CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        return
    fi
    
    # Удаление строки с портом
    sed -i "/^listen=.*:${REMOVE_PORT}$/d" $CONFIG_FILE
    
    systemctl restart glider > /dev/null 2>&1
    
    sleep 2
    
    if systemctl is-active --quiet glider; then
        echo -e "${GREEN}Пользователь на порту $REMOVE_PORT удалён!${NC}"
    else
        echo -e "${RED}Ошибка при удалении пользователя${NC}"
    fi
    
    read -p "Нажмите Enter для продолжения..."
}

# Удаление Glider
remove_glider() {
    echo -e "${RED}=== Удаление Glider ===${NC}"
    
    if ! check_glider_installed; then
        echo -e "${YELLOW}Glider не установлен.${NC}"
        read -p "Нажмите Enter для продолжения..."
        return
    fi
    
    read -p "Вы уверены, что хотите удалить Glider? (y/n): " CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        return
    fi
    
    echo -e "${GREEN}Остановка службы...${NC}"
    systemctl stop glider > /dev/null 2>&1
    systemctl disable glider > /dev/null 2>&1
    
    echo -e "${GREEN}Удаление файлов...${NC}"
    rm -f $BINARY_PATH
    rm -f $SERVICE_FILE
    rm -rf /etc/glider
    
    systemctl daemon-reload > /dev/null 2>&1
    
    echo -e "${GREEN}Glider успешно удалён!${NC}"
    read -p "Нажмите Enter для продолжения..."
}

# Главное меню
show_menu() {
    clear
    echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   Управление Glider Proxy Server      ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
    echo ""
    
    if check_glider_installed; then
        CURRENT_VERSION=$(get_current_version)
        STATUS=$(systemctl is-active glider 2>/dev/null || echo "не запущен")
        echo -e "Статус: ${GREEN}Установлен${NC} (версия: $CURRENT_VERSION)"
        echo -e "Служба: $([ "$STATUS" == "active" ] && echo -e "${GREEN}Запущена${NC}" || echo -e "${RED}Остановлена${NC}")"
    else
        echo -e "Статус: ${YELLOW}Не установлен${NC}"
    fi
    
    echo ""
    echo "1. Установить Glider"
    echo "2. Обновить Glider"
    echo "3. Добавить пользователя"
    echo "4. Удалить пользователя"
    echo "5. Список пользователей"
    echo "6. Удалить Glider"
    echo "7. Выход"
    echo ""
    read -p "Выберите действие (1-7): " choice
    
    case $choice in
        1) install_glider ;;
        2) update_glider ;;
        3) add_user ;;
        4) remove_user ;;
        5) list_users; echo ""; read -p "Нажмите Enter для продолжения..." ;;
        6) remove_glider ;;
        7) echo "Выход..."; exit 0 ;;
        *) echo -e "${RED}Неверный выбор${NC}"; sleep 1 ;;
    esac
}

# Основной цикл
check_root

while true; do
    show_menu
done
