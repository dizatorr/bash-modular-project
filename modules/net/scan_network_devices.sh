#!/usr/bin/env bash
# === MENU: Сканировать сетевые устройства
# === FUNC: scan_network_devices
# Автор: Diz A Torr
# Версия: 1.0
# Лицензия: MIT
# Описание: Сканирование устройств в сети и создание отчета

scan_network_devices() {
    local config_file="$DNSMASQ_CONF"
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
    local ip_cidr
    # Ищем listen-address
    ip_cidr=$(grep -E "^[[:space:]]*listen-address=" "$config_file" | head -n1 | cut -d'=' -f2 | xargs)

    # Если не найдено — ищем шлюз (dhcp-option=3,)
    if [[ -z "$ip_cidr" ]]; then
        ip_cidr=$(grep -E "^[[:space:]]*dhcp-option=3," "$config_file" | head -n1 | cut -d',' -f2 | xargs)
    fi

    # Проверка формата IP
    if [[ ! "$ip_cidr" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_warn "Не удалось определить IP из конфига. Используется 192.168.1.1"
        ip_cidr="192.168.1.1"
    else
        log_debug "Найден IP в конфиге: $listen_ip"
    fi

    log_debug "Сканируем сеть... интерфейс: $interface, IP: $ip_cidr"
    local listen_ip
    listen_ip=$(echo "$ip_cidr" | cut -d/ -f1)
    local subnet
    subnet=$(echo "$listen_ip" | cut -d. -f1-3)
    local timestamp
    timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
    local report_file="$LOG_DIR/devices-$timestamp.txt"

    log_info "Сканируем сеть $subnet.0/24..."

    # Очищаем ARP-таблицу и запускаем пинг
    ip neigh flush nud all

    local i
    for i in {1..254}; do
        ping -c1 -W1 "$subnet.$i" &>/dev/null &
    done
    wait
    sleep 2

    # Собираем информацию об устройствах
    local devices=()
    local line ip mac hostname
    while IFS= read -r line; do
        ip=$(echo "$line" | awk '{print $1}')
        mac=$(echo "$line" | awk '{print $5}')
        if [[ "$ip" != "$listen_ip" && -n "$ip" && -n "$mac" ]]; then
            hostname=$(nslookup "$ip" 127.0.0.1 2>/dev/null | awk '/name =/ {gsub(/\.$/,"",$4); print $4; exit}' || echo "unknown")
            devices+=("$ip|$mac|$hostname")
        fi
    done < <(ip neigh show | grep -v "nud failed\|nud incomplete")

    # Создаем отчет
    {
        echo "=== СЕТЕВАЯ ДИАГНОСТИКА ==="
        echo "Дата: $(date)"
        echo "Интерфейс: $interface"
        echo "Сеть: $ip_cidr"
        echo "DHCP: диапазон из diag-dnsmasq.conf"
        echo ""
        echo "Найдено ${#devices[@]} устройств:"
        echo ""
        printf "%-15s %-17s %-20s\n" "IP" "MAC" "Hostname"
        printf "%-15s %-17s %-20s\n" "---------------" "-----------------" "--------"
        local dev
        for dev in "${devices[@]}"; do
            IFS='|' read -r ip mac host <<< "$dev"
            printf "%-15s %-17s %-20s\n" "$ip" "$mac" "$host"
        done
    } > "$report_file"

    log_info "Отчёт сохранён: $report_file"
    echo -e "${GREEN}Найдено устройств: ${#devices[@]}${NC}"
    cat "$report_file"
    
    return 0
}