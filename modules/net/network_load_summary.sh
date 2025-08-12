#!/usr/bin/env bash
# === MENU: Сводный отчет по загруженности
# === FUNC: network_load_summary
# Автор: Diz A Torr
# Версия: 1.0
# Лицензия: MIT
# Описание: Генерация сводного отчета по загруженности сети

network_load_summary() {
    local interface="${1:-$DNSMASQ_CONF}"
   
    
    echo -e "${BLUE}Генерация сводного отчета по загруженности${NC}"
    
    local timestamp
    timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
    local summary_report="$LOG_DIR/load-summary-$timestamp.txt"
    
    {
        echo "=== СВОДНЫЙ ОТЧЕТ ПО ЗАГРУЖЕННОСТИ СЕТИ ==="
        echo "Дата: $(date)"
        echo "Интерфейс: $interface"
        echo "Исходный отчет: $(basename $summary_report )"
        echo ""
        echo "=== ИНФОРМАЦИЯ ОБ ИНТЕРФЕЙСЕ ==="
    } > "$summary_report"
    
    # Информация об интерфейсе
    echo "Состояние интерфейса:" >> "$summary_report"
    ip link show "$interface" >> "$summary_report" 2>&1
    echo "" >> "$summary_report"
    
    # Текущая статистика
    echo "Текущая статистика:" >> "$summary_report"
    cat /proc/net/dev | grep "^$interface:" >> "$summary_report"
    echo "" >> "$summary_report"
    
    # Активные соединения
    echo "Активные соединения:" >> "$summary_report"
    if command -v ss &> /dev/null; then
        echo "TCP соединений: $(ss -t | wc -l)" >> "$summary_report"
        echo "UDP соединений: $(ss -u | wc -l)" >> "$summary_report"
    fi
    echo "" >> "$summary_report"
    
    # Быстрый тест нагрузки
    echo "=== БЫСТРЫЙ ТЕСТ НАГРУЗКИ (10 секунд) ===" >> "$summary_report"
    
    local rx_start tx_start rx_end tx_end
    rx_start=$(cat /proc/net/dev | grep "^$interface:" | awk '{print $2}')
    tx_start=$(cat /proc/net/dev | grep "^$interface:" | awk '{print $10}')
    
    sleep 10
    
    rx_end=$(cat /proc/net/dev | grep "^$interface:" | awk '{print $2}')
    tx_end=$(cat /proc/net/dev | grep "^$interface:" | awk '{print $10}')
    
    local rx_bytes tx_bytes total_bytes
    rx_bytes=$((rx_end - rx_start))
    tx_bytes=$((tx_end - tx_start))
    total_bytes=$((rx_bytes + tx_bytes))
    
    local rx_kbps tx_kbps total_kbps
    rx_kbps=$((rx_bytes / 1024 / 10))
    tx_kbps=$((tx_bytes / 1024 / 10))
    total_kbps=$((total_bytes / 1024 / 10))
    
    {
        echo "Передано данных: $((tx_bytes / 1024 / 1024)) MB"
        echo "Принято данных: $((rx_bytes / 1024 / 1024)) MB"
        echo "Всего данных: $((total_bytes / 1024 / 1024)) MB"
        echo "Средняя скорость передачи: ${tx_kbps} KB/s"
        echo "Средняя скорость приема: ${rx_kbps} KB/s"
        echo "Средняя общая скорость: ${total_kbps} KB/s"
        echo ""
        echo "=== РЕКОМЕНДАЦИИ ==="
        if [[ $total_kbps -lt 100 ]]; then
            echo "РЕКОМЕНДАЦИЯ: Загруженность низкая. Интерфейс недоиспользуется."
        elif [[ $total_kbps -lt 1000 ]]; then
            echo "РЕКОМЕНДАЦИЯ: Загруженность средняя. Интерфейс используется оптимально."
        elif [[ $total_kbps -lt 10000 ]]; then
            echo "РЕКОМЕНДАЦИЯ: Загруженность высокая. Следите за производительностью."
        else
            echo "РЕКОМЕНДАЦИЯ: Загруженность очень высокая. Возможны проблемы с производительностью."
        fi
    } >> "$summary_report"
    
    echo -e "${GREEN}Сводный отчет сохранен: $summary_report${NC}"
    cat "$summary_report"
}