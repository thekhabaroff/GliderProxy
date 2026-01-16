#!/bin/bash

# Скрипт управления Glider Proxy Server
# Использование: glider

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
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Анимация загрузки
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [${CYAN}%c${NC}]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
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
        echo -e " ${GREEN}✓${NC}"
    else
        echo -e " ${RED}✗${NC}"
        return $status
    fi
}

# Проверка root прав
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${RED}╔════════════════════════════════════════╗${NC}"
        echo -e "${RED}║         ОШИБКА ДОСТУПА                 ║${NC}"
        echo -e "${RED}╚════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}Пожалуйста, запустите скрипт от root${NC}"
        echo -e "${CYAN}Используйте: ${GREEN}sudo glider${NC}"
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

# Получение списка пользователей в виде массива
get_users_array() {
    local -n arr=$1
    local index=0
    
    if [ ! -f "$CONFIG_FILE" ]; then
        return
    fi
    
    while IFS= read -r line; do
        if [[ $line =~ ^listen=mixed://([^:]+):([^@]+)@:([0-9]+) ]]; then
            username="${BASH_REMATCH[1]}"
            password="${BASH_REMATCH[2]}"
            port="${BASH_REMATCH[3]}"
            arr[$index]="$username|$password|$port"
            ((index++))
        elif [[ $line =~ ^listen=mixed://:([0-9]+) ]]; then
            port="${BASH_REMATCH[1]}"
            arr[$index]="noauth||$port"
            ((index++))
        fi
    done < "$CONFIG_FILE"
}

# Красивое отображение списка пользователей
list_users() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}Нет пользователей${NC}"
        return
    fi
    
    echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║        СПИСОК ПОЛЬЗОВАТЕЛЕЙ            ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
    echo ""
    
    local count=1
    declare -a users
    get_users_array users
    
    if [ ${#users[@]} -eq 0 ]; then
        echo -e "${YELLOW}Пользователей не найдено${NC}"
        return
    fi
    
    for user_data in "${users[@]}"; do
        IFS='|' read -r username password port <<< "$user_data"
        
        echo -e "${CYAN}[$count]${NC} ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        if [ "$username" = "noauth" ]; then
            echo -e "  ${BLUE}Порт без аутентификации:${NC} ${GREEN}$port${NC}"
        else
            echo -e "  ${BLUE}Логин:${NC}   ${GREEN}$username${NC}"
            echo -e "  ${BLUE}Пароль:${NC}  ${GREEN}$password${NC}"
            echo -e "  ${BLUE}Порт:${NC}    ${GREEN}$port${NC}"
            echo -e "  ${BLUE}HTTP:${NC}    http://${username}:${password}@$(hostname -I | awk '{print $1}'):${port}"
            echo -e "  ${BLUE}SOCKS5:${NC}  socks5://${username}:${password}@$(hostname -I | awk '{print $1}'):${port}"
        fi
        ((count++))
    done
    echo ""
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
    clear
    echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         УСТАНОВКА GLIDER               ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
    echo ""
    
    if check_glider_installed; then
        echo -e "${YELLOW}⚠ Glider уже установлен${NC}"
        echo -e "${CYAN}Используйте 'Обновить' для переустановки${NC}"
        echo ""
        read -p "Нажмите Enter для продолжения..."
        return
    fi
    
    # Запрос параметров для первого пользователя
    echo -e "${CYAN}➤ Настройка первого пользователя${NC}"
    echo ""
    read -p "Введите порт для прокси [18443]: " PROXY_PORT
    PROXY_PORT=${PROXY_PORT:-18443}
    
    read -p "Добавить аутентификацию? (y/n) [n]: " ADD_AUTH
    ADD_AUTH=${ADD_AUTH:-n}
    
    if [[ "$ADD_AUTH" == "y" || "$ADD_AUTH" == "Y" ]]; then
        read -p "Введите логин: " PROXY_USER
        read -sp "Введите пароль: " PROXY_PASS
        echo
        LISTEN_STRING="listen=mixed://${PROXY_USER}:${PROXY_PASS}@:${PROXY_PORT}"
    else
        LISTEN_STRING="listen=mixed://:${PROXY_PORT}"
    fi
    
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Начинается установка...${NC}"
    echo ""
    
    # Установка зависимостей
    run_with_spinner "Обновление списка пакетов..." apt update
    run_with_spinner "Установка зависимостей..." apt install curl wget tar -y
    
    # Скачивание Glider
    cd /tmp
    rm -rf glider_* glider.tar.gz 2>/dev/null || true
    
    run_with_spinner "Скачивание Glider v${VERSION}..." wget -q "https://github.com/nadoo/glider/releases/download/v${VERSION}/glider_${VERSION}_linux_amd64.tar.gz" -O glider.tar.gz
    
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}Попытка альтернативного метода...${NC}"
        run_with_spinner "Скачивание deb пакета..." wget -q "https://github.com/nadoo/glider/releases/download/v${VERSION}/glider_${VERSION}_linux_amd64.deb" -O glider.deb
        run_with_spinner "Установка deb пакета..." dpkg -i glider.deb
        run_with_spinner "Исправление зависимостей..." apt --fix-broken install -y
    else
        run_with_spinner "Распаковка архива..." tar -xzf glider.tar.gz
        run_with_spinner "Установка бинарного файла..." bash -c 'find . -name "glider" -type f -exec cp {} /usr/local/bin/glider \; && chmod +x /usr/local/bin/glider'
    fi
    
    # Проверка установки
    if ! check_glider_installed; then
        echo -e "${RED}✗ Ошибка установки бинарного файла${NC}"
        read -p "Нажмите Enter для продолжения..."
        exit 1
    fi
    
    # Создание конфигурации
    run_with_spinner "Создание конфигурации..." bash -c "mkdir -p /etc/glider && cat > $CONFIG_FILE <<EOF
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
EOF"
    
    # Создание systemd службы
    run_with_spinner "Создание systemd службы..." bash -c "cat > $SERVICE_FILE <<EOF
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
EOF"
    
    # Запуск службы
    run_with_spinner "Перезагрузка systemd..." systemctl daemon-reload
    run_with_spinner "Включение автозапуска..." systemctl enable glider
    run_with_spinner "Запуск службы..." systemctl start glider
    
    sleep 2
    
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if systemctl is-active --quiet glider; then
        echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║    ✓ УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО!     ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${BLUE}Порт:${NC}    ${GREEN}$PROXY_PORT${NC}"
        echo -e "${BLUE}IP:${NC}      ${GREEN}$(hostname -I | awk '{print $1}')${NC}"
        
        if [[ "$ADD_AUTH" == "y" || "$ADD_AUTH" == "Y" ]]; then
            echo ""
            echo -e "${BLUE}Логин:${NC}   ${GREEN}$PROXY_USER${NC}"
            echo -e "${BLUE}Пароль:${NC}  ${GREEN}$PROXY_PASS${NC}"
            echo ""
            echo -e "${CYAN}HTTP прокси:${NC}"
            echo -e "  http://${PROXY_USER}:${PROXY_PASS}@$(hostname -I | awk '{print $1}'):${PROXY_PORT}"
            echo ""
            echo -e "${CYAN}SOCKS5 прокси:${NC}"
            echo -e "  socks5://${PROXY_USER}:${PROXY_PASS}@$(hostname -I | awk '{print $1}'):${PROXY_PORT}"
            echo ""
            echo -e "${CYAN}Пример использования:${NC}"
            echo -e "  ${GREEN}curl -x http://${PROXY_USER}:${PROXY_PASS}@$(hostname -I | awk '{print $1}'):${PROXY_PORT} https://ifconfig.me${NC}"
        else
            echo ""
            echo -e "${CYAN}HTTP прокси:${NC}  http://$(hostname -I | awk '{print $1}'):${PROXY_PORT}"
            echo -e "${CYAN}SOCKS5 прокси:${NC} socks5://$(hostname -I | awk '{print $1}'):${PROXY_PORT}"
            echo ""
            echo -e "${CYAN}Пример использования:${NC}"
            echo -e "  ${GREEN}curl -x http://$(hostname -I | awk '{print $1}'):${PROXY_PORT} https://ifconfig.me${NC}"
        fi
        
        echo ""
        echo -e "${CYAN}Управление:${NC} systemctl {start|stop|restart|status} glider"
    else
        echo -e "${RED}╔════════════════════════════════════════╗${NC}"
        echo -e "${RED}║    ✗ ОШИБКА: СЛУЖБА НЕ ЗАПУСТИЛАСЬ    ║${NC}"
        echo -e "${RED}╚════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}Проверьте логи:${NC} journalctl -u glider -n 50"
    fi
    
    echo ""
    read -p "Нажмите Enter для продолжения..."
}

# Обновление Glider
update_glider() {
    clear
    echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         ОБНОВЛЕНИЕ GLIDER              ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
    echo ""
    
    if ! check_glider_installed; then
        echo -e "${YELLOW}⚠ Glider не установлен${NC}"
        echo -e "${CYAN}Используйте 'Установить'${NC}"
        echo ""
        read -p "Нажмите Enter для продолжения..."
        return
    fi
    
    CURRENT_VERSION=$(get_current_version)
    echo -e "${BLUE}Текущая версия:${NC} ${GREEN}$CURRENT_VERSION${NC}"
    echo -e "${BLUE}Новая версия:${NC}   ${GREEN}$VERSION${NC}"
    echo ""
    
    read -p "Продолжить обновление? (y/n): " CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        return
    fi
    
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    run_with_spinner "Остановка службы..." systemctl stop glider
    run_with_spinner "Резервное копирование конфигурации..." cp $CONFIG_FILE /tmp/glider.conf.backup
    
    cd /tmp
    rm -rf glider_* glider.tar.gz 2>/dev/null || true
    
    run_with_spinner "Скачивание Glider v${VERSION}..." wget -q "https://github.com/nadoo/glider/releases/download/v${VERSION}/glider_${VERSION}_linux_amd64.tar.gz" -O glider.tar.gz
    
    if [ $? -eq 0 ]; then
        run_with_spinner "Распаковка архива..." tar -xzf glider.tar.gz
        run_with_spinner "Установка бинарного файла..." bash -c 'find . -name "glider" -type f -exec cp {} /usr/local/bin/glider \; && chmod +x /usr/local/bin/glider'
    else
        echo -e "${RED}✗ Ошибка скачивания${NC}"
        systemctl start glider > /dev/null 2>&1
        read -p "Нажмите Enter для продолжения..."
        return
    fi
    
    run_with_spinner "Восстановление конфигурации..." cp /tmp/glider.conf.backup $CONFIG_FILE
    run_with_spinner "Запуск службы..." systemctl start glider
    
    sleep 2
    
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if systemctl is-active --quiet glider; then
        echo -e "${GREEN}✓ Обновление завершено успешно!${NC}"
        echo -e "${BLUE}Новая версия:${NC} ${GREEN}$(get_current_version)${NC}"
    else
        echo -e "${RED}✗ Ошибка запуска после обновления${NC}"
    fi
    
    echo ""
    read -p "Нажмите Enter для продолжения..."
}

# Добавление пользователя
add_user() {
    clear
    echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║        ДОБАВЛЕНИЕ ПОЛЬЗОВАТЕЛЯ         ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
    echo ""
    
    if ! check_glider_installed; then
        echo -e "${YELLOW}⚠ Glider не установлен${NC}"
        echo ""
        read -p "Нажмите Enter для продолжения..."
        return
    fi
    
    list_users
    
    echo -e "${CYAN}➤ Создание нового пользователя${NC}"
    echo ""
    read -p "Введите новый логин: " NEW_USER
    read -sp "Введите новый пароль: " NEW_PASS
    echo
    read -p "Введите порт для этого пользователя: " NEW_PORT
    
    # Проверка занятости порта
    if check_port_used "$NEW_PORT"; then
        echo ""
        echo -e "${RED}✗ Порт $NEW_PORT уже используется!${NC}"
        echo ""
        read -p "Нажмите Enter для продолжения..."
        return
    fi
    
    echo ""
    run_with_spinner "Добавление пользователя..." sed -i "/^# HTTP + SOCKS5 прокси/a listen=mixed://${NEW_USER}:${NEW_PASS}@:${NEW_PORT}" $CONFIG_FILE
    run_with_spinner "Перезапуск службы..." systemctl restart glider
    
    sleep 2
    
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if systemctl is-active --quiet glider; then
        echo -e "${GREEN}✓ Пользователь добавлен успешно!${NC}"
        echo ""
        echo -e "${BLUE}Логин:${NC}   ${GREEN}$NEW_USER${NC}"
        echo -e "${BLUE}Пароль:${NC}  ${GREEN}$NEW_PASS${NC}"
        echo -e "${BLUE}Порт:${NC}    ${GREEN}$NEW_PORT${NC}"
        echo ""
        echo -e "${CYAN}HTTP прокси:${NC}"
        echo -e "  http://${NEW_USER}:${NEW_PASS}@$(hostname -I | awk '{print $1}'):${NEW_PORT}"
        echo ""
        echo -e "${CYAN}SOCKS5 прокси:${NC}"
        echo -e "  socks5://${NEW_USER}:${NEW_PASS}@$(hostname -I | awk '{print $1}'):${NEW_PORT}"
    else
        echo -e "${RED}✗ Ошибка при добавлении пользователя${NC}"
        echo -e "${YELLOW}Проверьте логи:${NC} journalctl -u glider -n 20"
    fi
    
    echo ""
    read -p "Нажмите Enter для продолжения..."
}

# Управление пользователями
manage_users() {
    clear
    echo -e "${YELLOW}╔════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║       УПРАВЛЕНИЕ ПОЛЬЗОВАТЕЛЯМИ        ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════╝${NC}"
    echo ""
    
    if ! check_glider_installed; then
        echo -e "${YELLOW}⚠ Glider не установлен${NC}"
        echo ""
        read -p "Нажмите Enter для продолжения..."
        return
    fi
    
    list_users
    
    declare -a users
    get_users_array users
    
    if [ ${#users[@]} -eq 0 ]; then
        echo ""
        read -p "Нажмите Enter для продолжения..."
        return
    fi
    
    echo -e "${CYAN}Выберите действие:${NC}"
    echo "1. Изменить пользователя"
    echo "2. Удалить пользователя"
    echo "3. Назад"
    echo ""
    read -p "Выберите действие (1-3): " action
    
    case $action in
        1)
            echo ""
            read -p "Введите номер пользователя для изменения: " user_num
            
            if [ "$user_num" -lt 1 ] || [ "$user_num" -gt ${#users[@]} ]; then
                echo -e "${RED}✗ Неверный номер${NC}"
                sleep 1
                return
            fi
            
            user_data="${users[$((user_num-1))]}"
            IFS='|' read -r old_username old_password old_port <<< "$user_data"
            
            echo ""
            echo -e "${CYAN}➤ Изменение пользователя${NC}"
            echo ""
            read -p "Новый логин [$old_username]: " new_username
            new_username=${new_username:-$old_username}
            read -sp "Новый пароль: " new_password
            echo
            new_password=${new_password:-$old_password}
            read -p "Новый порт [$old_port]: " new_port
            new_port=${new_port:-$old_port}
            
            if [ "$new_port" != "$old_port" ] && check_port_used "$new_port"; then
                echo ""
                echo -e "${RED}✗ Порт $new_port уже используется!${NC}"
                sleep 2
                return
            fi
            
            echo ""
            run_with_spinner "Изменение пользователя..." sed -i "s|^listen=.*:${old_port}$|listen=mixed://${new_username}:${new_password}@:${new_port}|" $CONFIG_FILE
            run_with_spinner "Перезапуск службы..." systemctl restart glider
            
            sleep 2
            
            if systemctl is-active --quiet glider; then
                echo ""
                echo -e "${GREEN}✓ Пользователь изменён успешно!${NC}"
            else
                echo ""
                echo -e "${RED}✗ Ошибка при изменении${NC}"
            fi
            ;;
            
        2)
            echo ""
            read -p "Введите номер пользователя для удаления: " user_num
            
            if [ "$user_num" -lt 1 ] || [ "$user_num" -gt ${#users[@]} ]; then
                echo -e "${RED}✗ Неверный номер${NC}"
                sleep 1
                return
            fi
            
            # Подсчёт количества listen строк
            LISTEN_COUNT=$(grep -c "^listen=" $CONFIG_FILE)
            
            if [ "$LISTEN_COUNT" -le 1 ]; then
                echo ""
                echo -e "${RED}✗ Нельзя удалить последнего пользователя!${NC}"
                echo -e "${YELLOW}Используйте 'Удалить Glider' для полного удаления${NC}"
                sleep 2
                return
            fi
            
            user_data="${users[$((user_num-1))]}"
            IFS='|' read -r username password port <<< "$user_data"
            
            echo ""
            read -p "Удалить пользователя '$username' на порту $port? (y/n): " CONFIRM
            if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
                return
            fi
            
            echo ""
            run_with_spinner "Удаление пользователя..." sed -i "/^listen=.*:${port}$/d" $CONFIG_FILE
            run_with_spinner "Перезапуск службы..." systemctl restart glider
            
            sleep 2
            
            if systemctl is-active --quiet glider; then
                echo ""
                echo -e "${GREEN}✓ Пользователь удалён!${NC}"
            else
                echo ""
                echo -e "${RED}✗ Ошибка при удалении${NC}"
            fi
            ;;
            
        3)
            return
            ;;
    esac
    
    echo ""
    read -p "Нажмите Enter для продолжения..."
}

# Удаление Glider
remove_glider() {
    clear
    echo -e "${RED}╔════════════════════════════════════════╗${NC}"
    echo -e "${RED}║          УДАЛЕНИЕ GLIDER               ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════╝${NC}"
    echo ""
    
    if ! check_glider_installed; then
        echo -e "${YELLOW}⚠ Glider не установлен${NC}"
        echo ""
        read -p "Нажмите Enter для продолжения..."
        return
    fi
    
    echo -e "${YELLOW}⚠ ВНИМАНИЕ: Все данные и пользователи будут удалены!${NC}"
    echo ""
    read -p "Вы уверены, что хотите удалить Glider? (y/n): " CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        return
    fi
    
    echo ""
    run_with_spinner "Остановка службы..." systemctl stop glider
    run_with_spinner "Отключение автозапуска..." systemctl disable glider
    run_with_spinner "Удаление файлов..." bash -c "rm -f $BINARY_PATH $SERVICE_FILE && rm -rf /etc/glider"
    run_with_spinner "Перезагрузка systemd..." systemctl daemon-reload
    
    echo ""
    echo -e "${GREEN}✓ Glider успешно удалён!${NC}"
    echo ""
    read -p "Нажмите Enter для продолжения..."
}

# Главное меню
show_menu() {
    clear
    echo -e "${MAGENTA}╔════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║                                        ║${NC}"
    echo -e "${MAGENTA}║   ${GREEN}🚀 GLIDER PROXY MANAGER 🚀${MAGENTA}          ║${NC}"
    echo -e "${MAGENTA}║                                        ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════╝${NC}"
    echo ""
    
    if check_glider_installed; then
        CURRENT_VERSION=$(get_current_version)
        STATUS=$(systemctl is-active glider 2>/dev/null || echo "остановлена")
        echo -e "  ${BLUE}Статус:${NC}  $([ "$STATUS" == "active" ] && echo -e "${GREEN}●${NC} Установлен (v$CURRENT_VERSION)" || echo -e "${RED}●${NC} Установлен (v$CURRENT_VERSION)")"
        echo -e "  ${BLUE}Служба:${NC}  $([ "$STATUS" == "active" ] && echo -e "${GREEN}●${NC} Запущена" || echo -e "${RED}●${NC} Остановлена")"
    else
        echo -e "  ${BLUE}Статус:${NC}  ${YELLOW}●${NC} Не установлен"
    fi
    
    echo ""
    echo -e "${CYAN}┌────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}  1. ${GREEN}Установить Glider${NC}"
    echo -e "${CYAN}│${NC}  2. ${BLUE}Обновить Glider${NC}"
    echo -e "${CYAN}│${NC}  3. ${GREEN}Добавить пользователя${NC}"
    echo -e "${CYAN}│${NC}  4. ${YELLOW}Управление пользователями${NC}"
    echo -e "${CYAN}│${NC}  5. ${BLUE}Список пользователей${NC}"
    echo -e "${CYAN}│${NC}  6. ${RED}Удалить Glider${NC}"
    echo -e "${CYAN}│${NC}  7. ${MAGENTA}Выход${NC}"
    echo -e "${CYAN}└────────────────────────────────────────┘${NC}"
    echo ""
    read -p "$(echo -e ${CYAN}Выберите действие ${GREEN}[1-7]${CYAN}: ${NC})" choice
    
    case $choice in
        1) install_glider ;;
        2) update_glider ;;
        3) add_user ;;
        4) manage_users ;;
        5) clear; list_users; echo ""; read -p "Нажмите Enter для продолжения..." ;;
        6) remove_glider ;;
        7) clear; echo -e "${GREEN}Спасибо за использование Glider Manager!${NC}"; echo ""; exit 0 ;;
        *) echo -e "${RED}✗ Неверный выбор${NC}"; sleep 1 ;;
    esac
}

# Основной цикл
check_root

while true; do
    show_menu
done
