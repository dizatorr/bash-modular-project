#!/usr/bin/env bash
# === MENU: Восстановить сетевое соединение
# === FUNC: restore_network_connection
# Автор: Diz A Torr
# Версия: 1.0
# Лицензия: MIT
# Описание: Восстановление исходного сетевого соединения

restore_network_connection() {
    local interface="$1"
    local nm_active_connection="$2"
    local dnsmasq_pidfile="$3"
    
    log_info "Восстанавливаем интернет-соединение..."

    # Остановка dnsmasq
    if [[ -n "$dnsmasq_pidfile" && -f "$dnsmasq_pidfile" ]] && [[ -s "$dnsmasq_pidfile" ]]; then
        local pid
        pid=$(cat "$dnsmasq_pidfile")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" && log_info "dnsmasq остановлен" || log_warn "Не удалось остановить dnsmasq"
        else
            log_debug "Процесс dnsmasq (PID: $pid) не найден"
        fi
        rm -f "$dnsmasq_pidfile"
    fi

    # Очистка IP и возврат управления NetworkManager
    ip addr flush dev "$interface" scope global
    nmcli dev set "$interface" managed yes

    # Перезапуск соединения NetworkManager
    if [[ -n "$nm_active_connection" ]]; then
        log_info "Перезапуск соединения: $nm_active_connection"
        nmcli con down "$nm_active_connection" &>/dev/null || true
        sleep 2
        if nmcli con up "$nm_active_connection"; then
            log_info "Интернет-соединение восстановлено"
        else
            log_error "Не удалось восстановить соединение"
        fi
    else
        log_warn "Нет активного соединения для восстановления"
    fi
    
    return 0
}