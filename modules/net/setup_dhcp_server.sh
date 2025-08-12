#!/usr/bin/env bash
# === MENU: Настроить и запустить DHCP сервер
# === FUNC: setup_dhcp_server
# Автор: Diz A Torr
# Версия: 1.0
# Лицензия: MIT
# Описание: Настройка IP и запуск DHCP сервера (dnsmasq)

setup_dhcp_server() {
    local config_file="${1:-$DNSMASQ_CONF}"
    
    # Проверка существования конфига
    if ! load_config "$config_file" true false ; then
        echo -e "${RED}Создайте файл: $config_file${NC}"
        return 1
    fi
    
    log_debug "Чтение конфига: $config_file"
    
    
    # Получаем интерфейс из конфига
    local interface
    interface=$(grep -E "^[[:space:]]*interface=" "$config_file" | head -n1 | cut -d'=' -f2 | xargs)
    
    if [[ -z "$interface" ]]; then
        log_error "Интерфейс не найден в конфиге: $config_file"
        echo -e "${RED}Добавьте строку: interface=имя_интерфейса${NC}"
        return 1
    fi
    
    log_debug "Найден интерфейс в конфиге: $interface"
    
    # Проверка существования интерфейса
    if ! ip link show "$interface" &>/dev/null; then
        log_error "Интерфейс $interface не найден в системе"
        return 1
    fi
    
    # Получаем IP из конфига
    local listen_ip
    # Ищем listen-address
    listen_ip=$(grep -E "^[[:space:]]*listen-address=" "$config_file" | head -n1 | cut -d'=' -f2 | xargs)

    # Если не найдено — ищем шлюз (dhcp-option=3,)
    if [[ -z "$listen_ip" ]]; then
        listen_ip=$(grep -E "^[[:space:]]*dhcp-option=3," "$config_file" | head -n1 | cut -d',' -f2 | xargs)
    fi

    # Проверка формата IP
    if [[ ! "$listen_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_warn "Не удалось определить IP из конфига. Используется 192.168.1.1"
        listen_ip="192.168.1.1"
    else
        log_debug "Найден IP в конфиге: $listen_ip"
    fi

    local ip_cidr
    read -p "Введите IP/маску (Enter = $listen_ip/24): " ip_cidr
    ip_cidr="${ip_cidr:-$listen_ip/24}"

    # Настраиваем статический IP
    # Отключаем управление от NetworkManager
    if ! nmcli dev set "$interface" managed no 2>/dev/null; then
        log_warn "Не удалось отключить управление NetworkManager для $interface"
    fi

    # Очищаем и поднимаем интерфейс
    ip addr flush dev "$interface" scope global
    ip link set "$interface" up

    # Назначаем IP
    if ! ip addr add "$ip_cidr" dev "$interface"; then
        log_error "Не удалось назначить IP: $ip_cidr"
        return 1
    fi

    log_info "Назначен IP: $ip_cidr на интерфейсе $interface"

    # Проверяем, занят ли порт 53
    check_and_kill_port_53

    # Запускаем dnsmasq
    local dnsmasq_pidfile="/tmp/dnsmasq-diag.pid"

    log_info "Запуск dnsmasq с конфигом: $config_file"

    # Останавливаем старый процесс, если он существует
    if [[ -f "$dnsmasq_pidfile" ]]; then
        local old_pid
        old_pid=$(cat "$dnsmasq_pidfile" 2>/dev/null)
        if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
            log_warn "Останавливаем старый dnsmasq (PID: $old_pid)"
            kill "$old_pid" || true
        fi
        rm -f "$dnsmasq_pidfile"
    fi

    # Запускаем dnsmasq в фоне
    if sudo /usr/sbin/dnsmasq --conf-file="$config_file" --pid-file="$dnsmasq_pidfile"; then
        log_info "dnsmasq успешно запущен в фоне (PID файл: $dnsmasq_pidfile)"
        echo "$dnsmasq_pidfile" # Возвращаем путь к PID файлу
        return 0
    else
        log_error "Ошибка при запуске dnsmasq"
        return 1
    fi
}

# Функция для проверки и освобождения порта 53
check_and_kill_port_53() {
    # Проверяем, кто занимает порт 53
    local port_users
    systemctl stop systemd-resolved    # Отключаем systemd-resolved
    systemctl disable systemd-resolved # Отключаем автозапуск systemd-resolved

    port_users=$(netstat -tulnp 2>/dev/null | grep ":53 " | awk '{print $7}' | cut -d'/' -f1 | sort -u)
    
    if [[ -n "$port_users" ]]; then
        log_warn "Порт 53 занят процессами: $port_users"
        
        # Спрашиваем пользователя, убивать ли процессы
        local answer
        read -p "Остановить процессы, использующие порт 53? (y/N): " answer
        if [[ "${answer,,}" =~ ^(y|yes)$ ]]; then

            for pid in $port_users; do
                if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
                    log_info "Останавливаем процесс PID: $pid"
                    kill "$pid" || log_error "Не удалось остановить процесс $pid"
                fi
            done
            
            # Ждем немного, пока процессы остановятся
            sleep 2
        else
            log_info "Порт 53 останется занятым. Запуск dnsmasq может завершиться ошибкой."
        fi
    else
        log_debug "Порт 53 свободен"
    fi
}