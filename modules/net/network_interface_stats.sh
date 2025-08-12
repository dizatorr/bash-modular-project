#!/usr/bin/env bash
# === MENU: Статистика интерфейса
# === FUNC: network_interface_stats
# Автор: Diz A Torr
# Версия: 1.0
# Лицензия: MIT
# Описание: Подробная статистика сетевого интерфейса

network_interface_stats() {
    local config_file="${1:-$DNSMASQ_CONF}"
    local interface="${2:-$(select_network_interface "$config_file")}"
    
    echo -e "${BLUE}Статистика интерфейса $interface:${NC}"
    
    local timestamp
    timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
    local stats_report="$LOG_DIR/interface-stats-$timestamp.txt"
    
    {
        echo "=== СТАТИСТИКА ИНТЕРФЕЙСА ==="
        echo "Дата: $(date)"
        echo "Интерфейс: $interface"
        echo "Исходный отчет: $(basename "${stats_report}")"
        echo ""
        echo "=== БАЗОВАЯ СТАТИСТИКА ==="
    } > "$stats_report"
    
    # Базовая статистика ip
    echo -e "${BLUE}1. Статистика IP:${NC}"
    ip -s link show "$interface" | tee -a "$stats_report"
    echo "" >> "$stats_report"
    
    # Статистика /proc
    if [[ -f "/proc/net/dev" ]]; then
        echo -e "${BLUE}2. Статистика /proc/net/dev:${NC}"
        grep "^$interface:" /proc/net/dev | tee -a "$stats_report"
        echo "" >> "$stats_report"
    fi
    
    # Активные соединения
    echo -e "${BLUE}3. Активные соединения:${NC}"
    if command -v ss &> /dev/null; then
        echo "TCP соединения:" >> "$stats_report"
        ss -t | wc -l >> "$stats_report"
        ss -t | head -10 >> "$stats_report"
        echo "" >> "$stats_report"
        echo "UDP соединения:" >> "$stats_report"
        ss -u | wc -l >> "$stats_report"
        ss -u | head -10 >> "$stats_report"
    elif command -v netstat &> /dev/null; then
        netstat -an | grep ESTABLISHED | tee -a "$stats_report"
    fi
    
    echo "" >> "$stats_report"
    
    # Скорость передачи данных
    echo -e "${BLUE}4. Измерение скорости (5 секунд):${NC}"
    local rx1 tx1 rx2 tx2
    rx1=$(cat /proc/net/dev | grep "^$interface:" | awk '{print $2}')
    tx1=$(cat /proc/net/dev | grep "^$interface:" | awk '{print $10}')
    
    sleep 5
    
    rx2=$(cat /proc/net/dev | grep "^$interface:" | awk '{print $2}')
    tx2=$(cat /proc/net/dev | grep "^$interface:" | awk '{print $10}')
    
    local rx_rate tx_rate
    rx_rate=$(( (rx2 - rx1) / 5 ))
    tx_rate=$(( (tx2 - tx1) / 5 ))
    
    echo "Принято: $((rx_rate / 1024)) KB/s" | tee -a "$stats_report"
    echo "Передано: $((tx_rate / 1024)) KB/s" | tee -a "$stats_report"
    echo "Общая скорость: $(((rx_rate + tx_rate) / 1024)) KB/s" | tee -a "$stats_report"
    
    {
        echo ""
        echo "=== ОЦЕНКА ЗАГРУЖЕННОСТИ ==="
        local total_rate=$(( (rx_rate + tx_rate) / 1024 ))
        if [[ $total_rate -lt 100 ]]; then
            echo "Загруженность: НИЗКАЯ"
        elif [[ $total_rate -lt 1000 ]]; then
            echo "Загруженность: СРЕДНЯЯ"
        elif [[ $total_rate -lt 10000 ]]; then
            echo "Загруженность: ВЫСОКАЯ"
        else
            echo "Загруженность: ОЧЕНЬ ВЫСОКАЯ"
        fi
    } >> "$stats_report"
    
    echo -e "${GREEN}Статистика сохранена: $stats_report${NC}"
}