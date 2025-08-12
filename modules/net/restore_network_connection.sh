#!/usr/bin/env bash
# === MENU: Восстановить сетевое соединение
# === FUNC: restore_network_connection
# Автор: Diz A Torr
# Версия: 1.0
# Лицензия: MIT
# Описание: Восстановление исходного сетевого соединения

restore_network_connection() {
    local config_file="${1:-$DNSMASQ_CONF}"
    
    log_info "Восстанавливаем интернет-соединение..."

    # Получаем интерфейс из конфига (если не передан как переменная)
    local interface_from_config=""
    if [[ -z "$interface" ]] && [[ -f "$config_file" ]]; then
        interface_from_config=$(grep -E "^[[:space:]]*interface=" "$config_file" | head -n1 | cut -d'=' -f2 | xargs)
        if [[ -n "$interface_from_config" ]]; then
            interface="$interface_from_config"
            log_debug "Интерфейс из конфига: $interface"
        fi
    fi

    # Проверка наличия интерфейса
    if [[ -z "$interface" ]]; then
        log_error "Интерфейс не определен для восстановления"
        return 1
    fi

    # Проверка существования интерфейса
    if ! ip link show "$interface" &>/dev/null; then
        log_error "Интерфейс $interface не найден в системе"
        return 1
    fi

    # Остановка dnsmasq
    local dnsmasq_pidfile="/tmp/dnsmasq-diag.pid"
    if [[ -f "$dnsmasq_pidfile" ]]; then
        if [[ -s "$dnsmasq_pidfile" ]]; then
            local pid
            pid=$(cat "$dnsmasq_pidfile" 2>/dev/null)
            if [[ -n "$pid" ]] && [[ "$pid" =~ ^[0-9]+$ ]]; then
                if kill -0 "$pid" 2>/dev/null; then
                    log_info "Останавливаем dnsmasq (PID: $pid)..."
                    kill "$pid" && log_info "dnsmasq остановлен" || log_warn "Не удалось остановить dnsmasq"
                else
                    log_debug "Процесс dnsmasq (PID: $pid) не найден"
                fi
            else
                log_warn "Некорректный PID в файле: $dnsmasq_pidfile"
            fi
        else
            log_debug "PID файл пуст: $dnsmasq_pidfile"
        fi
        rm -f "$dnsmasq_pidfile"
    else
        log_debug "PID файл не найден: $dnsmasq_pidfile"
    fi

    # Очистка IP и возврат управления NetworkManager
    log_info "Восстанавливаем интерфейс $interface..."
    
    # Очищаем назначенные IP
    ip addr flush dev "$interface" scope global 2>/dev/null || true
    
    # Возвращаем управление NetworkManager
    if command -v nmcli &>/dev/null; then
        if nmcli dev set "$interface" managed yes 2>/dev/null; then
            log_info "Управление $interface передано NetworkManager"
        else
            log_warn "Не удалось передать управление NetworkManager для $interface"
        fi
    else
        log_debug "NetworkManager не найден"
    fi

    # Перезапуск соединения NetworkManager
    local connection_found=false
    
    # Пытаемся найти и восстановить активное соединение
    if [[ -n "$nm_active_connection" ]]; then
        log_info "Перезапуск соединения: $nm_active_connection"
        nmcli con down "$nm_active_connection" &>/dev/null || true
        sleep 2
        if nmcli con up "$nm_active_connection"; then
            log_info "Интернет-соединение восстановлено"
            connection_found=true
        else
            log_warn "Не удалось восстановить соединение: $nm_active_connection"
        fi
    fi

    # Если нет сохраненного соединения, ищем активные соединения для интерфейса
    if [[ "$connection_found" == false ]]; then
        local active_connections
        active_connections=$(nmcli -t -f NAME,DEVICE con show --active | grep ":$interface$" | cut -d':' -f1)
        
        if [[ -n "$active_connections" ]]; then
            local conn
            while IFS= read -r conn; do
                if [[ -n "$conn" ]]; then
                    log_info "Восстанавливаем соединение: $conn"
                    nmcli con down "$conn" &>/dev/null || true
                    sleep 2
                    if nmcli con up "$conn"; then
                        log_info "Соединение $conn восстановлено"
                        connection_found=true
                        break
                    else
                        log_warn "Не удалось восстановить соединение: $conn"
                    fi
                fi
            done <<< "$active_connections"
        fi
    fi

    # Если все еще нет соединения, пытаемся автоматически подключиться
    if [[ "$connection_found" == false ]]; then
        log_info "Попытка автоматического подключения интерфейса $interface..."
        if command -v nmcli &>/dev/null; then
            # Перезапускаем NetworkManager
            if sudo systemctl is-active NetworkManager &>/dev/null; then
                sudo systemctl reload NetworkManager 2>/dev/null || true
            fi
            
            # Ждем немного
            sleep 3
            
            # Проверяем статус
            if nmcli dev show "$interface" &>/dev/null; then
                log_info "Интерфейс $interface доступен"
            else
                log_warn "Интерфейс $interface может требовать ручной настройки"
            fi
        fi
    fi

    # Очищаем переменные
    unset interface nm_active_connection dnsmasq_pidfile

    log_info "Восстановление сетевого соединения завершено"
    return 0
}