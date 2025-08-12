#!/usr/bin/env bash
# === MENU: Настроить и запустить DHCP сервер
# === FUNC: setup_dhcp_server
# Автор: Diz A Torr
# Версия: 1.0
# Лицензия: MIT
# Описание: Настройка IP и запуск DHCP сервера (dnsmasq)

setup_dhcp_server() {
    local config_file="${1:-$DNSMASQ_CONF}"
    local interface="${2:-$(select_network_interface "$config_file")}"
    
    log_debug "Чтение конфига: $config_file"

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

    # Валидация введенного IP/маски
    if ! validate_ip_cidr "$ip_cidr"; then
        log_error "Некорректный формат IP/маски: $ip_cidr"
        return 1
    fi

    # Настраиваем статический IP
    # Отключаем управление от NetworkManager
    if command -v nmcli &>/dev/null; then
        if ! nmcli dev set "$interface" managed no 2>/dev/null; then
            log_warn "Не удалось отключить управление NetworkManager для $interface"
        fi
    else
        log_debug "NetworkManager не найден, пропускаем отключение"
    fi

    # Очищаем и поднимаем интерфейс
    ip addr flush dev "$interface" scope global 2>/dev/null || true
    ip link set "$interface" up

    # Назначаем IP
    if ! ip addr add "$ip_cidr" dev "$interface"; then
        log_error "Не удалось назначить IP: $ip_cidr"
        return 1
    fi

    log_info "Назначен IP: $ip_cidr на интерфейсе $interface"

    # Проверяем, занят ли порт 53
    if ! check_and_kill_port_53; then
        log_warn "Не удалось освободить порт 53. Запуск dnsmasq может завершиться ошибкой."
    fi

    # Запускаем dnsmasq
    local dnsmasq_pidfile="/tmp/dnsmasq-diag.pid"

    log_info "Запуск dnsmasq с конфигом: $config_file"

    # Останавливаем старый процесс, если он существует
    if [[ -f "$dnsmasq_pidfile" ]]; then
        local old_pid
        old_pid=$(cat "$dnsmasq_pidfile" 2>/dev/null)
        if [[ -n "$old_pid" ]] && [[ "$old_pid" =~ ^[0-9]+$ ]] && kill -0 "$old_pid" 2>/dev/null; then
            log_warn "Останавливаем старый dnsmasq (PID: $old_pid)"
            kill "$old_pid" 2>/dev/null || true
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
    local max_attempts=3
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        # Останавливаем systemd-resolved если он есть
        if systemctl is-active systemd-resolved &>/dev/null; then
            log_info "Останавливаем systemd-resolved..."
            sudo systemctl stop systemd-resolved 2>/dev/null || true
        fi

        # Проверяем, кто занимает порт 53
        local port_users
        port_users=$(sudo netstat -tulnp 2>/dev/null | grep ":53 " | awk '{print $7}' | cut -d'/' -f1,2 | sort -u)

        if [[ -z "$port_users" ]]; then
            log_debug "Порт 53 свободен"
            return 0
        fi

        log_warn "Порт 53 занят процессами: $port_users"
        
        # Автоматически останавливаем известные конфликтующие сервисы
        local stopped_something=false
        
        # Проверяем systemd-resolved
        if echo "$port_users" | grep -q "systemd-resolve"; then
            log_info "Отключение systemd-resolved..."
            sudo systemctl stop systemd-resolved 2>/dev/null || true
            sudo systemctl disable systemd-resolved 2>/dev/null || true
            stopped_something=true
        fi

        # Если остались другие процессы - спрашиваем пользователя
        local remaining_users
        remaining_users=$(echo "$port_users" | grep -v "systemd-resolve" | grep -v "^$")
        
        if [[ -n "$remaining_users" ]]; then
            local answer
            echo "Оставшиеся процессы, использующие порт 53: $remaining_users"
            read -p "Остановить эти процессы? (y/N): " answer
            if [[ "${answer,,}" =~ ^(y|yes)$ ]]; then
                for process in $remaining_users; do
                    local pid
                    pid=$(echo "$process" | cut -d'/' -f1)
                    if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
                        log_info "Останавливаем процесс PID: $pid"
                        sudo kill "$pid" 2>/dev/null || log_error "Не удалось остановить процесс $pid"
                    fi
                done
            else
                log_info "Порт 53 останется занятым."
                break
            fi
        elif [[ "$stopped_something" == true ]]; then
            # Если мы остановили только systemd-resolved, пробуем еще раз
            ((attempt++))
            sleep 1
            continue
        fi

        ((attempt++))
        sleep 1
    done

    # Финальная проверка
    if sudo netstat -tulnp 2>/dev/null | grep -q ":53 "; then
        log_error "Порт 53 все еще занят"
        return 1
    else
        log_info "Порт 53 успешно освобожден"
        return 0
    fi
}

# Вспомогательная функция для валидации IP/маски
validate_ip_cidr() {
    local ip_cidr="$1"
    local ip mask
    
    if [[ "$ip_cidr" =~ ^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)/([0-9]+)$ ]]; then
        ip="${BASH_REMATCH[1]}"
        mask="${BASH_REMATCH[2]}"
        
        # Проверка IP
        if ! [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            return 1
        fi
        
        # Проверка маски (0-32)
        if [[ ! "$mask" =~ ^[0-9]+$ ]] || (( mask < 0 )) || (( mask > 32 )); then
            return 1
        fi
        
        return 0
    else
        return 1
    fi
}