#!/bin/bash

# Скрипт управления Glider Proxy Server
# Использование: sudo bash glider_manager.sh

set -e

CONFIG_FILE="/etc/glider/glider.conf"
SERVICE_FILE="/etc/systemd/system/glider.service"
BINARY_PATH="/usr/local/bin/glider"
VERSION="0.16.4"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Проверка root прав
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${RED}Пожалуйста, запустите скрипт от root (sudo)${NC}"
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

# Установка Glider
install_glider() {
    echo -e "${GREEN}=== Установка Glider ===${NC}"
    
    if check_glider_installed; then
        echo -e "${YELLOW}Glider уже установлен. Используйте 'Обновить' для переустановки.${NC}"
        read -p "Нажмите Enter для продолжения..."
        return
    fi
    
    # Запрос параметров
    read -p "Введите порт для прокси (по умолчанию 18443): " PROXY_PORT
    PROXY_PORT=${PROXY_PORT:-18443}
    
    read -p "Добавить аутентификацию? (y/n, по умолчанию n): " ADD_AUTH
    ADD_AUTH=${ADD_AUTH:-n}
    
    if [[ "$ADD_AUTH" == "y" || "$ADD_AUTH" == "Y" ]]; then
        read -p "Введите логин: " PROXY_USER
        read -sp "Введите пароль: " PROXY_PASS
        echo
        LISTEN_STRING="mixed://${PROXY_USER}:${PROXY_PASS}@:${PROXY_PORT}"
    else
        LISTEN_STRING="mixed://:${PROXY_PORT}"
    fi
    
    # Установка зависимостей
    echo -e "${GREEN}Установка зависимостей...${NC}"
    apt update
    apt install curl wget tar -y
    
    # Скачивание Glider
    echo -e "${GREEN}Скачивание Glider v${VERSION}...${NC}"
    cd /tmp
    rm -rf glider_* 2>/dev/null || true
    
    wget "https://github.com/nadoo/glider/releases/download/v${VERSION}/glider_${VERSION}_linux_amd64.tar.gz" -O glider.tar.gz
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Ошибка скачивания. Попытка скачать deb пакет...${NC}"
        wget "https://github.com/nadoo/glider/releases/download/v${VERSION}/glider_${VERSION}_linux_amd64.deb" -O glider.deb
        dpkg -i glider.deb
        apt --fix-broken install -y
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
verbose=True

# HTTP + SOCKS5 на одном порту
listen=${LISTEN_STRING}

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

[Install]
WantedBy=multi-user.target
EOF
    
    # Запуск службы
    echo -e "${GREEN}Запуск службы...${NC}"
    systemctl daemon-reload
    systemctl enable glider
    systemctl start glider
    
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
        echo "Логи: journalctl -u glider -f"
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
    systemctl stop glider
    
    # Резервная копия конфигурации
    cp $CONFIG_FILE /tmp/glider.conf.backup
    
    # Скачивание новой версии
    echo -e "${GREEN}Скачивание Glider v${VERSION}...${NC}"
    cd /tmp
    rm -rf glider_* glider.tar.gz 2>/dev/null || true
    
    wget "https://github.com/nadoo/glider/releases/download/v${VERSION}/glider_${VERSION}_linux_amd64.tar.gz" -O glider.tar.gz
    
    if [ $? -eq 0 ]; then
        tar -xzf glider.tar.gz
        find . -name "glider" -type f -exec cp {} $BINARY_PATH \;
        chmod +x $BINARY_PATH
    else
        echo -e "${RED}Ошибка скачивания${NC}"
        systemctl start glider
        read -p "Нажмите Enter для продолжения..."
        return
    fi
    
    # Восстановление конфигурации
    cp /tmp/glider.conf.backup $CONFIG_FILE
    
    # Запуск службы
    systemctl start glider
    
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
    
    read -p "Введите новый логин: " NEW_USER
    read -sp "Введите новый пароль: " NEW_PASS
    echo
    
    # Получение текущего порта
    CURRENT_PORT=$(grep "listen=" $CONFIG_FILE | grep -oP ':\K[0-9]+')
    
    # Проверка, есть ли уже аутентификация
    if grep -q "listen=mixed://.*:.*@" $CONFIG_FILE; then
        echo -e "${YELLOW}Внимание: в Glider можно использовать только одного пользователя одновременно.${NC}"
        read -p "Заменить текущего пользователя на нового? (y/n): " REPLACE
        if [[ "$REPLACE" != "y" && "$REPLACE" != "Y" ]]; then
            return
        fi
    fi
    
    # Обновление конфигурации
    sed -i "s|listen=mixed://.*|listen=mixed://${NEW_USER}:${NEW_PASS}@:${CURRENT_PORT}|" $CONFIG_FILE
    
    # Если аутентификации не было
    if ! grep -q "listen=mixed://.*:.*@" $CONFIG_FILE; then
        sed -i "s|listen=mixed://:${CURRENT_PORT}|listen=mixed://${NEW_USER}:${NEW_PASS}@:${CURRENT_PORT}|" $CONFIG_FILE
    fi
    
    systemctl restart glider
    
    if systemctl is-active --quiet glider; then
        echo -e "${GREEN}Пользователь добавлен успешно!${NC}"
        echo ""
        echo "Логин: $NEW_USER"
        echo "Пароль: $NEW_PASS"
        echo "Порт: $CURRENT_PORT"
    else
        echo -e "${RED}Ошибка при добавлении пользователя${NC}"
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
    systemctl stop glider
    systemctl disable glider
    
    echo -e "${GREEN}Удаление файлов...${NC}"
    rm -f $BINARY_PATH
    rm -f $SERVICE_FILE
    rm -rf /etc/glider
    
    systemctl daemon-reload
    
    echo -e "${GREEN}Glider успешно удалён!${NC}"
    read -p "Нажмите Enter для продолжения..."
}

# Главное меню
show_menu() {
    clear
    echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   Управление Glider Proxy Server       ║${NC}"
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
    echo "3. Добавить/изменить пользователя"
    echo "4. Удалить Glider"
    echo "5. Выход"
    echo ""
    read -p "Выберите действие (1-5): " choice
    
    case $choice in
        1) install_glider ;;
        2) update_glider ;;
        3) add_user ;;
        4) remove_glider ;;
        5) echo "Выход..."; exit 0 ;;
        *) echo -e "${RED}Неверный выбор${NC}"; sleep 1 ;;
    esac
}

# Основной цикл
check_root

while true; do
    show_menu
done
