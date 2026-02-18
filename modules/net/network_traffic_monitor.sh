#!/usr/bin/env bash
# === MENU: Мониторинг трафика в реальном времени
# === FUNC: network_traffic_monitor
# Автор: Diz A Torr
# Версия: 1.0
# Лицензия: MIT
# Описание: Мониторинг сетевого трафика в реальном времени

network_traffic_monitor() {
    local interface="${2:-$(net_select_interface "$config_file")}"
    
    echo -e "${BLUE}Мониторинг трафика в реальном времени${NC}"
    echo -e "${YELLOW}Нажмите Ctrl+C для остановки${NC}"
    
    local monitor_duration=60
    read -r -p "Длительность мониторинга (секунд) [60]: " input_duration
    monitor_duration=${input_duration:-60}
    
    local timestamp
    timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
    local traffic_log="$LOG_DIR/traffic-monitor-$timestamp.txt"
    
    {
        echo "=== МОНИТОРИНГ ТРАФИКА ==="
        echo "Дата: $(date)"
        echo "Интерфейс: $interface"
        echo "Длительность: $monitor_duration секунд"
        echo ""
    } > "$traffic_log"
    
    local start_time
    start_time=$(date +%s)
    local end_time=$((start_time + monitor_duration))
    local cycle=0
    
    while [[ $(date +%s) -lt $end_time ]]; do
        cycle=$((cycle + 1))
        local current_time
        current_time=$(date '+%H:%M:%S')
        
        # Получаем текущую статистику
        local rx_bytes tx_bytes
        rx_bytes=$(cat /proc/net/dev | grep "^$interface:" | awk '{print $2}')
        tx_bytes=$(cat /proc/net/dev | grep "^$interface:" | awk '{print $10}')
        
        # Конвертируем в удобочитаемый формат
        local rx_mb tx_mb
        rx_mb=$((rx_bytes / 1024 / 1024))
        tx_mb=$((tx_bytes / 1024 / 1024))
        
        echo "[$current_time] Цикл $cycle:" | tee -a "$traffic_log"
        echo "  Принято: ${rx_mb} MB" | tee -a "$traffic_log"
        echo "  Передано: ${tx_mb} MB" | tee -a "$traffic_log"
        echo "  Всего: $((rx_mb + tx_mb)) MB" | tee -a "$traffic_log"
        echo "---" | tee -a "$traffic_log"
        
        sleep 2
    done
    
    echo -e "${GREEN}Мониторинг завершен${NC}"
    echo -e "${GREEN}Лог сохранен: $traffic_log${NC}"
}