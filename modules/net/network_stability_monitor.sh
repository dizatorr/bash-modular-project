#!/usr/bin/env bash
# === MENU: Мониторинг стабильности сети
# === FUNC: network_stability_monitor
# Автор: Diz A Torr
# Версия: 1.0
# Лицензия: MIT
# Описание: Непрерывный мониторинг стабильности сетевых устройств

network_stability_monitor() {
    
    # Получаем список доступных отчетов
    local reports=()
    while IFS= read -r file; do
        [[ -f "$file" ]] && reports+=("$file")
    done < <(find "$LOG_DIR" -name "devices-*.txt" -type f | sort -r)
    
    # Проверяем наличие отчетов
    if [[ ${#reports[@]} -eq 0 ]]; then
        echo -e "${YELLOW}Отчеты о сетевых устройствах не найдены${NC}"
        echo -e "${YELLOW}Сначала выполните сканирование сети${NC}"
        return 1
    fi
    
    local selected_report
    
    # Если есть только один отчет, используем его
    if [[ ${#reports[@]} -eq 1 ]]; then
        selected_report="${reports[0]}"
        echo -e "${BLUE}Используется отчет: $(basename "$selected_report")${NC}"
    else
        # Предлагаем выбор из списка
        local report_display_names=()
        local report_file date_time
        
        for report_file in "${reports[@]}"; do
            date_time=$(grep "^Дата:" "$report_file" 2>/dev/null | cut -d: -f2- | xargs)
            if [[ -n "$date_time" ]]; then
                report_display_names+=("$(basename "$report_file") - $date_time")
            else
                report_display_names+=("$(basename "$report_file")")
            fi
        done
        
        local menu_items=("${report_display_names[@]}")
        local MENU_TITLE="Выберите отчет для мониторинга"
        local selected
        
        show_menu "$MENU_TITLE" "${menu_items[@]}"
        
        if [[ "$selected" =~ ^[0-9]+$ ]] && (( selected < ${#reports[@]} )); then
            selected_report="${reports[selected]}"
        else
            echo -e "${RED}Некорректный выбор${NC}"
            return 1
        fi
    fi
    
    # Парсим устройства из отчета
    local devices=()
    local in_devices_section=false
    local found_header=false
    local line
    
    # Читаем файл и ищем секцию с устройствами
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Ищем начало секции устройств
        if [[ "$line" == "Найдено "*"устройств:" ]]; then
            in_devices_section=true
            continue
        fi
        
        # Ищем заголовок таблицы
        if $in_devices_section && [[ "$line" == "IP"*"MAC"*"Hostname"* ]]; then
            found_header=true
            continue
        fi
        
        # Пропускаем разделительную строку
        if $in_devices_section && [[ "$line" == "---"* ]]; then
            continue
        fi
        
        # Обрабатываем строки с устройствами
        if $in_devices_section && [[ -n "$line" ]] && [[ "$line" != "Найдено"* ]] && [[ "$line" != "IP"* ]] && [[ "$line" != "---"* ]]; then
            # Проверяем, что строка содержит данные устройства
            if [[ "$line" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]]; then
                # Извлекаем данные из строки
                local ip mac hostname
                ip=$(echo "$line" | awk '{print $1}')
                mac=$(echo "$line" | awk '{print $2}')
                hostname=$(echo "$line" | awk '{print $3}')
                
                if [[ -n "$ip" ]]; then
                    devices+=("$ip|$mac|$hostname")
                fi
            fi
        fi
        
        # Завершаем обработку при достижении конца секции
        if $in_devices_section && [[ -z "$line" ]] && $found_header; then
            break
        fi
    done < "$selected_report"
    
    if [[ ${#devices[@]} -eq 0 ]]; then
        echo -e "${YELLOW}Устройства не найдены в отчете${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Мониторинг стабильности сети...${NC}"
    echo -e "${YELLOW}Нажмите Ctrl+C для остановки${NC}"
    
    local monitor_duration=60
    read -p "Длительность мониторинга (секунд) [60]: " input_duration
    monitor_duration=${input_duration:-60}
    
    local cycle_interval=5
    read -p "Интервал между циклами (секунд) [5]: " input_interval
    cycle_interval=${input_interval:-5}
    
    local start_time
    start_time=$(date +%s)
    local end_time=$((start_time + monitor_duration))
    
    echo "Мониторинг на $monitor_duration секунд с интервалом $cycle_interval секунд..."
    echo ""
    
    # Создаем файл для логирования результатов
    local timestamp
    timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
    local monitor_log="$LOG_DIR/stability-monitor-$timestamp.txt"
    
    {
        echo "=== МОНИТОРИНГ СТАБИЛЬНОСТИ СЕТИ ==="
        echo "Дата: $(date)"
        echo "Исходный отчет: $(basename "$selected_report")"
        echo "Длительность: $monitor_duration секунд"
        echo "Интервал: $cycle_interval секунд"
        echo "Всего устройств: ${#devices[@]}"
        echo ""
    } > "$monitor_log"
    
    local cycle_count=0
    local total_checks=0
    local total_failures=0
    
    while [[ $(date +%s) -lt $end_time ]]; do
        cycle_count=$((cycle_count + 1))
        local current_time
        current_time=$(date '+%Y-%m-%d %H:%M:%S')
        
        echo "=== ЦИКЛ $cycle_count [$current_time] ===" | tee -a "$monitor_log"
        echo "Проверка ${#devices[@]} устройств:" | tee -a "$monitor_log"
        
        local online_count=0
        local device ip mac hostname
        
        for device in "${devices[@]}"; do
            IFS='|' read -r ip mac hostname <<< "$device"
            total_checks=$((total_checks + 1))
            
            if ping -c 1 -W 1 "$ip" &>/dev/null; then
                echo -e "  ${GREEN}✓ $ip${NC} - ДОСТУПЕН" | tee -a "$monitor_log"
                online_count=$((online_count + 1))
                echo "  $ip - ДОСТУПЕН" >> "$monitor_log"
            else
                echo -e "  ${RED}✗ $ip${NC} - НЕДОСТУПЕН" | tee -a "$monitor_log"
                total_failures=$((total_failures + 1))
                echo "  $ip - НЕДОСТУПЕН" >> "$monitor_log"
            fi
        done
        
        local availability_percent=$((online_count * 100 / ${#devices[@]}))
        echo "Статистика: $online_count/${#devices[@]} устройств онлайн ($availability_percent%)" | tee -a "$monitor_log"
        echo "---" | tee -a "$monitor_log"
        echo "" | tee -a "$monitor_log"
        
        # Проверяем, не пора ли завершать мониторинг
        if [[ $(date +%s) -ge $end_time ]]; then
            break
        fi
        
        sleep "$cycle_interval"
    done
    
    # Финальная статистика
    {
        echo "=== ФИНАЛЬНАЯ СТАТИСТИКА ==="
        echo "Всего циклов: $cycle_count"
        echo "Всего проверок: $total_checks"
        echo "Успешных проверок: $((total_checks - total_failures))"
        echo "Проваленных проверок: $total_failures"
        if [[ $total_checks -gt 0 ]]; then
            local success_rate=$(( (total_checks - total_failures) * 100 / total_checks ))
            echo "Общий уровень доступности: $success_rate%"
        fi
        echo ""
        
        if [[ $total_failures -eq 0 ]]; then
            echo "РЕЗУЛЬТАТ: СЕТЬ СТАБИЛЬНА"
        elif [[ $total_failures -lt $((total_checks / 10)) ]]; then
            echo "РЕЗУЛЬТАТ: СЕТЬ УМЕРЕННО СТАБИЛЬНА"
        else
            echo "РЕЗУЛЬТАТ: СЕТЬ НЕСТАБИЛЬНА"
        fi
    } >> "$monitor_log"
    
    echo -e "${GREEN}Мониторинг завершен${NC}"
    echo -e "${GREEN}Лог сохранен: $monitor_log${NC}"
    
    # Показываем финальную статистику
    echo ""
    echo -e "${BLUE}=== ФИНАЛЬНАЯ СТАТИСТИКА ===${NC}"
    echo "Всего циклов: $cycle_count"
    echo "Всего проверок: $total_checks"
    echo "Проваленных проверок: $total_failures"
    if [[ $total_checks -gt 0 ]]; then
        local success_rate=$(( (total_checks - total_failures) * 100 / total_checks ))
        echo "Общий уровень доступности: $success_rate%"
    fi
    
    # Предлагаем просмотр полного лога
    echo ""
    read -p "Показать полный лог мониторинга? (y/n): " show_log
    if [[ "$show_log" == "y" || "$show_log" == "Y" ]]; then
        cat "$monitor_log"
    fi
}