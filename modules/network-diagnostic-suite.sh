#!/usr/bin/env bash
# === MENU: Диагностика сети (Полный пакет)
# === FUNC: network_diagnostic_suite

# Автор: Diz A Torr
# Версия: 1.6 (исправлено: загрязнение stdout логами)
# Лицензия: MIT

# Путь к проекту
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." &>/dev/null && pwd)
source "$SCRIPT_DIR/lib.sh" || {
    echo "FATAL: Не удалось загрузить lib.sh"
    exit 1
}

# === Константы ===
DNSMASQ_CONFIG="$SCRIPT_DIR/config/diag-dnsmasq.conf"
DNSMASQ_PIDFILE="/tmp/dnsmasq-diag.pid"

# === Переменные ===
INTERFACE=""
NM_ACTIVE_CONNECTION=""
DIAG_IN_PROGRESS=false


# === Проверка зависимостей ===
check_dependencies() {
    local deps=("dnsmasq" "ip" "nmcli" "ping" "nslookup" "ipcalc")
    local missing=()

    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Не хватает зависимостей: ${missing[*]}"
        echo -e "${RED}Установите: sudo apt install ${missing[*]}${NC}"
        return 1
    fi
    return 0
}

# === Получение IP из конфига dnsmasq ===
get_listen_ip_from_config() {
    local config_file="$DNSMASQ_CONFIG"

    if [[ ! -f "$config_file" ]]; then
        log_warn "Конфиг не найден: $config_file"
        echo "192.168.1.1"  # только IP в stdout
        return
    fi

    # Ищем listen-address
    local ip=$(grep -E "^[[:space:]]*listen-address=" "$config_file" | head -n1 | cut -d'=' -f2 | xargs)

    # Если не найдено — ищем шлюз (dhcp-option=3,)
    if [[ -z "$ip" ]]; then
        ip=$(grep -E "^[[:space:]]*dhcp-option=3," "$config_file" | head -n1 | cut -d',' -f2 | xargs)
    fi

    # Проверка формата IP
    if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        log_debug "Найден IP в конфиге: $ip"
        echo "$ip"  # только IP в stdout
    else
        log_warn "Не удалось определить IP из конфига, используем 192.168.1.1"
        echo "192.168.1.1"  # только IP
    fi
}

# === Выбор интерфейса ===
choose_interface() {
    local interfaces=()
    mapfile -t interfaces < <(ip -br link show | awk '$2 == "UP" {print $1}' | grep -v "^lo$")

    if [[ ${#interfaces[@]} -eq 0 ]]; then
        log_error "Нет активных интерфейсов"
        return 1
    fi

    if [[ ${#interfaces[@]} -eq 1 ]]; then
        INTERFACE="${interfaces[0]}"
        log_info "Выбран интерфейс: $INTERFACE"
        return 0
    fi

    local choices=()
    for iface in "${interfaces[@]}"; do
        choices+=("$iface" "Интерфейс $iface")
    done

    case "$USE_TUI" in
        "dialog")
            INTERFACE=$(dialog --clear --title "Выбор интерфейса" --menu "Интерфейс:" 15 60 5 "${choices[@]}" 3>&1 1>&2 2>&3)
            ;;
        "whiptail")
            INTERFACE=$(whiptail --title "Выбор интерфейса" --menu "Интерфейс:" 15 60 5 "${choices[@]}" 3>&1 1>&2 2>&3)
            ;;
        *)
            echo "Доступные интерфейсы:"
            for i in "${!interfaces[@]}"; do
                echo " [$i] ${interfaces[$i]}"
            done
            read -p "Выберите: " idx
            INTERFACE="${interfaces[$idx]}"
            ;;
    esac

    if [[ -z "$INTERFACE" || ! " ${interfaces[*]} " =~ " $INTERFACE " ]]; then
        log_error "Неверный выбор интерфейса"
        return 1
    fi

    log_info "Выбран интерфейс: $INTERFACE"
    return 0
}

# === Сохранение активного соединения ===
backup_connection() {
    NM_ACTIVE_CONNECTION=$(nmcli -t -f NAME,STATE connection show --active | grep ":activated" | cut -d: -f1 | head -n1)
    if [[ -n "$NM_ACTIVE_CONNECTION" ]]; then
        log_info "Активное соединение сохранено: $NM_ACTIVE_CONNECTION"
    else
        log_warn "Не найдено активное соединение NetworkManager"
    fi
}

# === Настройка статического IP ===
setup_static_ip() {
    # Автоматически определяем IP из конфига
    local listen_ip=$(get_listen_ip_from_config)
    local ip_cidr="${1:-$listen_ip/24}"

    # Отключаем управление от NM
    nmcli dev set "$INTERFACE" managed no || log_warn "Не удалось отключить управление NM"

    # Очищаем и поднимаем
    ip addr flush dev "$INTERFACE" scope global
    ip link set "$INTERFACE" up

    # Назначаем IP
    if ! ip addr add "$ip_cidr" dev "$INTERFACE"; then
        log_error "Не удалось назначить IP: $ip_cidr"
        return 1
    fi

    log_info "Назначен IP: $ip_cidr на интерфейсе $INTERFACE"
    return 0
}

# === Запуск dnsmasq с фиксированным конфигом ===
start_dnsmasq() {
    if [[ ! -f "$DNSMASQ_CONFIG" ]]; then
        log_error "Конфиг dnsmasq не найден: $DNSMASQ_CONFIG"
        echo -e "${RED}Создайте файл: config/diag-dnsmasq.conf${NC}"
        return 1
    fi

    log_info "Запуск dnsmasq с конфигом: $DNSMASQ_CONFIG"

    # Убиваем старый
    if [[ -f "$DNSMASQ_PIDFILE" ]]; then
        local old_pid=$(cat "$DNSMASQ_PIDFILE" 2>/dev/null)
        if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
            log_warn "Останавливаем старый dnsmasq (PID: $old_pid)"
            kill "$old_pid" || true
        fi
        rm -f "$DNSMASQ_PIDFILE"
    fi

    # Запускаем с --no-daemon для отладки
    if sudo /usr/sbin/dnsmasq \
        --conf-file="$DNSMASQ_CONFIG" \
        --pid-file="$DNSMASQ_PIDFILE" \
        --no-daemon \
        --log-queries \
        --log-dhcp 2>&1 | while IFS= read -r line; do
            log_debug "dnsmasq: $line"
        done; then

        log_info "dnsmasq запущен в фоне"
        # Перезапускаем в фоне
        sudo /usr/sbin/dnsmasq --conf-file="$DNSMASQ_CONFIG" --pid-file="$DNSMASQ_PIDFILE"
        return 0
    else
        log_error "dnsmasq завершился с ошибкой"
        return 1
    fi
}

# === Сканирование сети ===
scan_network() {
    local ip_cidr=${1:-$(get_listen_ip_from_config)/24}
    local listen_ip=$(echo "$ip_cidr" | cut -d/ -f1)
    local subnet=$(echo "$listen_ip" | cut -d. -f1-3)
    local timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
    local report_file="$LOG_DIR/devices-$timestamp.txt"

    log_info "Сканируем сеть $subnet.0/24..."

    ip neigh flush nud all

    for i in {1..254}; do
        ping -c1 -W1 "$subnet.$i" &>/dev/null &
    done
    wait
    sleep 2

    local devices=()
    while IFS= read -r line; do
        local ip=$(echo "$line" | awk '{print $1}')
        local mac=$(echo "$line" | awk '{print $5}')
        if [[ "$ip" != "$listen_ip" && -n "$ip" && -n "$mac" ]]; then
            local hostname=$(nslookup "$ip" 127.0.0.1 | awk '/name =/ {gsub(/\.$/,"",$4); print $4; exit}' 2>/dev/null || echo "unknown")
            devices+=("$ip|$mac|$hostname")
        fi
    done < <(ip neigh show | grep -v "nud failed\|nud incomplete")

    {
        echo "=== СЕТЕВАЯ ДИАГНОСТИКА ==="
        echo "Дата: $(date)"
        echo "Интерфейс: $INTERFACE"
        echo "Сеть: $ip_cidr"
        echo "DHCP: диапазон из diag-dnsmasq.conf"
        echo ""
        echo "Найдено ${#devices[@]} устройств:"
        echo ""
        printf "%-15s %-17s %-20s\n" "IP" "MAC" "Hostname"
        printf "%-15s %-17s %-20s\n" "---------------" "-----------------" "--------"
        for dev in "${devices[@]}"; do
            IFS='|' read -r ip mac host <<< "$dev"
            printf "%-15s %-17s %-20s\n" "$ip" "$mac" "$host"
        done
    } > "$report_file"

    log_info "Отчёт сохранён: $report_file"
    echo -e "${GREEN}Найдено устройств: ${#devices[@]}${NC}"
    cat "$report_file"
}

# === Восстановление сети через NM ===
restore_network() {
    if [[ "$DIAG_IN_PROGRESS" != "true" ]]; then
        log_debug "Сеть уже восстановлена, пропускаем"
        return 0
    fi

    log_info "Восстанавливаем интернет-соединение..."

    # Остановка dnsmasq
    if [[ -f "$DNSMASQ_PIDFILE" ]] && ps -p "$(cat "$DNSMASQ_PIDFILE" 2>/dev/null)" &>/dev/null; then
        kill "$(cat "$DNSMASQ_PIDFILE")" 2>/dev/null
        rm -f "$DNSMASQ_PIDFILE"
    fi

    # Очистка IP
    ip addr flush dev "$INTERFACE" scope global
    nmcli dev set "$INTERFACE" managed yes

    # Перезапуск соединения
    if [[ -n "$NM_ACTIVE_CONNECTION" ]]; then
        log_info "Перезапуск соединения: $NM_ACTIVE_CONNECTION"
        nmcli con down "$NM_ACTIVE_CONNECTION" &>/dev/null || true
        sleep 2
        if nmcli con up "$NM_ACTIVE_CONNECTION"; then
            log_info "Интернет-соединение восстановлено"
        else
            log_error "Не удалось восстановить соединение"
        fi
    else
        log_warn "Нет активного соединения для восстановления"
    fi
    DIAG_IN_PROGRESS=false
}

# === Очистка при выходе ===
cleanup() {
    if [[ "$DIAG_IN_PROGRESS" == "true" ]]; then
        log_warn "Модуль прерван аварийно. Восстанавливаем сеть..."
        restore_network
    fi
}

# === Главная функция ===
network_diagnostic_suite() {
    log_info "Запуск: Диагностика сети (Полный пакет)"
    log_info "Подсказка: выберите 'Выход без восстановления', чтобы оставить dnsmasq в фоне"

    if [[ $EUID -ne 0 ]]; then
        log_error "Требуются права root"
        echo -e "${RED}Выполните: sudo ./start.sh${NC}"
        return 1
    fi

    if ! check_dependencies; then
        return 1
    fi

    trap cleanup EXIT
    DIAG_IN_PROGRESS=true

    if ! choose_interface; then
        return 1
    fi

    backup_connection

    while true; do
        local choice=""
        case "$USE_TUI" in
            "dialog")
                choice=$(dialog --clear --title "Сеть" --menu "Действие:" 16 65 6 \
                    "1" "Настроить диагностику (DHCP/DNS)" \
                    "2" "Восстановить сеть и выйти" \
                    "q" "Выйти, оставив dnsmasq в фоне" \
                    3>&1 1>&2 2>&3)
                ;;
            "whiptail")
                choice=$(whiptail --title "Сеть" --menu "Действие:" 16 65 6 \
                    "1" "Настроить диагностику (DHCP/DNS)" \
                    "2" "Восстановить сеть и выйти" \
                    "q" "Выйти, оставив dnsmasq в фоне" \
                    3>&1 1>&2 2>&3)
                ;;
            *)
                show_menu_header "Диагностика сети"
                show_menu_item 1 "Настроить диагностику (DHCP/DNS)"
                show_menu_item 2 "Восстановить сеть и выйти"
                show_menu_item
                echo ""
                read -p "Выберите: " choice
                ;;
        esac

        case "$choice" in
            "1")
                read -p "Введите IP/маску (Enter = автоиз конфига): " user_ip
                setup_static_ip "$user_ip" || continue
                start_dnsmasq || continue
                scan_network "$user_ip"
                ;;
            "2")
                restore_network
                DIAG_IN_PROGRESS=false
                log_info "Модуль завершён. Сеть восстановлена."
                return 0
                ;;
            "q")
                if [[ -f "$DNSMASQ_PIDFILE" ]] && ps -p "$(cat "$DNSMASQ_PIDFILE" 2>/dev/null)" &>/dev/null; then
					log_info "Выход без восстановления сети."
					log_warn "dnsmasq и IP-настройки остаются активными."
					log_warn "Восстановите сеть вручную при необходимости."
					log_warn "Чтобы остановить dnsmasq выполни: sudo kill \$(cat /tmp/dnsmasq-diag.pid)"
					log_warn "Чтобы восстановить сеть: nmcli con up '$NM_ACTIVE_CONNECTION'"
				else
					log_info "Выход из модуля."
				fi
                DIAG_IN_PROGRESS=false
                return 0
                ;;
            *)
                log_warn "Неверный выбор"
                ;;
        esac
    done
}
