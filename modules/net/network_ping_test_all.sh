#!/usr/bin/env bash
# === MENU: Тестирование ping для всех устройств
# === FUNC: network_ping_test_all
# Автор: Diz A Torr
# Версия: 1.0
# Лицензия: MIT
# Описание: Массовое тестирование ping для всех устройств из отчета

network_ping_test_all() {
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
        local MENU_TITLE="Выберите отчет для анализа"
        local selected
        
        show_menu "$MENU_TITLE" "${menu_items[@]}"
        
        if [[ "$selected" =~ ^[0-9]+$ ]] && (( selected < ${#reports[@]} )); then
            selected_report="${reports[selected]}"
        else
            echo -e "${RED}Некорректный выбор${NC}"
            return 1
        fi
    fi
    
    # Отладка: показываем содержимое файла
    log_debug "Содержимое отчета $selected_report:"
    log_debug "$(head -20 "$selected_report")"
    
    # Парсим устройства из отчета
    local devices=()
    local in_devices_section=false
    local line
    
    # Читаем файл и ищем секцию с устройствами
    local found_header=false
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Отладка: показываем обрабатываемую строку
        log_debug "Обрабатываем строку: '$line'"
        
        # Ищем начало секции устройств
        if [[ "$line" == "Найдено "*"устройств:" ]]; then
            log_debug "Найдено начало секции устройств"
            in_devices_section=true
            continue
        fi
        
        # Пропускаем пустые строки до начала секции
        if ! $in_devices_section && [[ -z "$line" ]]; then
            continue
        fi
        
        # Ищем заголовок таблицы
        if $in_devices_section && [[ "$line" == "IP"*"MAC"*"Hostname"* ]]; then
            log_debug "Найден заголовок таблицы"
            found_header=true
            continue
        fi
        
        # Пропускаем разделительную строку
        if $in_devices_section && [[ "$line" == "---"* ]]; then
            log_debug "Пропущена разделительная строка"
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
                
                log_debug "Найдено устройство: IP=$ip, MAC=$mac, Hostname=$hostname"
                
                if [[ -n "$ip" ]]; then
                    devices+=("$ip|$mac|$hostname")
                fi
            fi
        fi
        
        # Завершаем обработку при достижении конца секции (пустая строка после данных)
        if $in_devices_section && [[ -z "$line" ]] && $found_header; then
            log_debug "Достигнут конец секции устройств"
            break
        fi
    done < "$selected_report"
    
    log_debug "Всего найдено устройств: ${#devices[@]}"
    
    if [[ ${#devices[@]} -eq 0 ]]; then
        echo -e "${YELLOW}Устройства не найдены в отчете${NC}"
        echo -e "${BLUE}Содержимое файла:$selected_report${NC}"
        head -30 "$selected_report"
        return 1
    fi
    
    echo -e "${BLUE}Тестирование ping для всех устройств...${NC}"
    
    local timestamp
    timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
    local ping_report="$LOG_DIR/ping-analysis-$timestamp.txt"
    
    {
        echo "=== АНАЛИЗ PING ==="
        echo "Дата: $(date)"
        echo "Исходный отчет: $(basename "$selected_report")"
        echo "Всего устройств: ${#devices[@]}"
        echo ""
    } > "$ping_report"
    
    local total_loss=0
    local total_devices=${#devices[@]}
    local failed_devices=0
    
    for device in "${devices[@]}"; do
        IFS='|' read -r ip mac hostname <<< "$device"
        
        echo -e "${BLUE}Тестирование $ip${NC}"
        [[ -n "$hostname" && "$hostname" != "unknown" ]] && echo -e "${BLUE}Хост: $hostname${NC}"
        echo "Тестирование $ip:" >> "$ping_report"
        
        if ping -c 10 -W 1 "$ip" &>/dev/null; then
            local ping_result
            ping_result=$(ping -c 10 "$ip" 2>&1)
            local packet_loss
            packet_loss=$(echo "$ping_result" | grep "packet loss" | awk '{print $6}')
            local avg_time
            avg_time=$(echo "$ping_result" | grep "rtt" | awk -F'/' '{print $5}')
            
            echo "  Потери: $packet_loss, Среднее время: ${avg_time:-N/A} ms" >> "$ping_report"
            echo -e "${GREEN}  Успешно: потери $packet_loss${NC}"
            
            # Подсчет общих потерь
            local loss_percent=${packet_loss%\%}
            if [[ -n "$loss_percent" && "$loss_percent" =~ ^[0-9]+$ ]]; then
                total_loss=$((total_loss + loss_percent))
            fi
        else
            echo "  Не доступен" >> "$ping_report"
            echo -e "${RED}  Не доступен${NC}"
            failed_devices=$((failed_devices + 1))
        fi
        echo "" >> "$ping_report"
    done
    
    # Сводная статистика
    {
        echo "=== СВОДНАЯ СТАТИСТИКА ==="
        echo "Общее количество устройств: $total_devices"
        echo "Недоступных устройств: $failed_devices"
        if [[ $total_devices -gt 0 ]]; then
            echo "Средний процент потерь: $((total_loss / (total_devices > 0 ? total_devices : 1)))%"
        fi
        echo ""
        
        if [[ $failed_devices -eq 0 ]] && [[ $total_devices -gt 0 ]] && [[ $((total_loss / (total_devices > 0 ? total_devices : 1))) -eq 0 ]]; then
            echo "Оценка качества: ОТЛИЧНОЕ"
        elif [[ $failed_devices -eq 0 ]] && [[ $total_devices -gt 0 ]] && [[ $((total_loss / (total_devices > 0 ? total_devices : 1))) -lt 5 ]]; then
            echo "Оценка качества: ХОРОШЕЕ"
        elif [[ $failed_devices -lt $((total_devices / 10 + 1)) ]]; then
            echo "Оценка качества: УДОВЛЕТВОРИТЕЛЬНОЕ"
        else
            echo "Оценка качества: ПЛОХОЕ"
        fi
    } >> "$ping_report"
    
    echo -e "${GREEN}Анализ ping завершен${NC}"
    echo -e "${GREEN}Отчет сохранен: $ping_report${NC}"
    
    # Показываем краткую сводку
    echo -e "${BLUE}=== КРАТКАЯ СВОДКА ===${NC}"
    echo "Всего устройств: $total_devices"
    echo "Недоступно: $failed_devices"
    if [[ $total_devices -gt 0 ]]; then
        echo "Средние потери: $((total_loss / (total_devices > 0 ? total_devices : 1)))%"
    fi
    
    # Предлагаем просмотр полного отчета
    read -p "Показать полный отчет? (y/n): " show_report
    if [[ "$show_report" == "y" || "$show_report" == "Y" ]]; then
        cat "$ping_report"
    fi
}