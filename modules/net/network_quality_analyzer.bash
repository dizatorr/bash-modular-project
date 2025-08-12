#!/usr/bin/env bash
# === MENU: Анализ качества изолированной сети
# === FUNC: network_quality_analyzer
# Автор: Diz A Torr
# Версия: 1.0
# Лицензия: MIT
# Описание: Комплексный анализ качества и стабильности изолированной сети

network_quality_analyzer() {
    local log_dir="$LOG_DIR"
    
    # Получаем список доступных отчетов о сетевых устройствах
    local reports=()
    while IFS= read -r file; do
        [[ -f "$file" ]] && reports+=("$file")
    done < <(find "$log_dir" -name "devices-*.txt" -type f | sort -r)
    
    # Проверяем наличие отчетов
    if [[ ${#reports[@]} -eq 0 ]]; then
        echo -e "${YELLOW}Отчеты о сетевых устройствах не найдены${NC}"
        echo -e "${YELLOW}Сначала выполните сканирование сети${NC}"
        return 1
    fi
    
    # Получаем информацию об отчетах для меню
    local report_info=()
    local report_display_names=()
    local report_file date_time interface network device_count
    
    for report_file in "${reports[@]}"; do
        # Извлекаем информацию из отчета
        date_time=$(grep "^Дата:" "$report_file" 2>/dev/null | cut -d: -f2- | xargs)
        interface=$(grep "^Интерфейс:" "$report_file" 2>/dev/null | cut -d: -f2 | xargs)
        network=$(grep "^Сеть:" "$report_file" 2>/dev/null | cut -d: -f2 | xargs)
        device_count=$(grep "^Найдено" "$report_file" 2>/dev/null | awk '{print $2}')
        
        # Формируем отображаемое имя
        local display_name
        if [[ -n "$date_time" ]]; then
            display_name="$(basename "$report_file") - $date_time"
        else
            display_name="$(basename "$report_file")"
        fi
        
        report_info+=("$date_time|$interface|$network|$device_count")
        report_display_names+=("$display_name")
    done
    
    # Меню выбора отчета
    local menu_items=("${report_display_names[@]}" "Обновить список")
    local MENU_TITLE="Выберите отчет для анализа качества сети"
    local selected
    
    while true; do
        show_menu "$MENU_TITLE" "${menu_items[@]}"
        
        case "$selected" in
            [0-9]*)
                if (( selected < ${#report_display_names[@]} )); then
                    # Выбран отчет для анализа
                    local selected_report="${reports[selected]}"
                    local selected_info="${report_info[selected]}"
                    
                    IFS='|' read -r date_time interface network device_count <<< "$selected_info"
                    
                    echo -e "${BLUE}=== АНАЛИЗ КАЧЕСТВА СЕТИ ===${NC}"
                    echo "Отчет: $(basename "$selected_report")"
                    echo "Дата: $date_time"
                    echo "Интерфейс: $interface"
                    echo "Сеть: $network"
                    echo "Устройств: $device_count"
                    echo "----------------------------------------"
                    
                    # Парсим устройства из отчета
                    local devices=()
                    local in_devices_section=false
                    local line
                    
                    while IFS= read -r line || [[ -n "$line" ]]; do
                        if [[ "$line" == "Найдено "*"устройств:" ]]; then
                            in_devices_section=true
                            continue
                        fi
                        
                        if [[ "$line" == "IP"*"MAC"*"Hostname"* ]] || [[ "$line" == "---"* ]]; then
                            continue
                        fi
                        
                        if $in_devices_section && [[ -n "$line" ]] && [[ "$line" != "Найдено"* ]]; then
                            local ip mac hostname
                            ip=$(echo "$line" | awk '{print $1}')
                            mac=$(echo "$line" | awk '{print $2}')
                            hostname=$(echo "$line" | awk '{print $3}')
                            
                            if [[ -n "$ip" && "$ip" != "IP" && "$ip" != "---" ]]; then
                                devices+=("$ip|$mac|$hostname")
                            fi
                        fi
                        
                        if [[ -z "$line" ]] && $in_devices_section; then
                            break
                        fi
                    done < "$selected_report"
                    
                    if [[ ${#devices[@]} -eq 0 ]]; then
                        echo -e "${YELLOW}Устройства не найдены в отчете${NC}"
                        echo ""
                        read -p "Нажмите Enter для продолжения..."
                        continue
                    fi
                    
                    # Меню действий с анализом
                    local action_items=(
                        "Тестирование ping для всех устройств"
                        "Детальный анализ конкретного устройства"
                        "Мониторинг стабильности"
                        "Генерация сводного отчета"
                        "Назад"
                    )
                    local ACTION_TITLE="Выберите тип анализа"
                    local action_selected
                    
                    while true; do
                        show_menu "$ACTION_TITLE" "${action_items[@]}"
                        
                        case "$action_selected" in
                            0)  # Тестирование ping для всех устройств
                                echo -e "${BLUE}Тестирование ping для всех устройств...${NC}"
                                
                                local timestamp
                                timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
                                local ping_report="$log_dir/ping-analysis-$timestamp.txt"
                                
                                {
                                    echo "=== АНАЛИЗ PING ==="
                                    echo "Дата: $(date)"
                                    echo "Исходный отчет: $(basename "$selected_report")"
                                    echo "Сеть: $network"
                                    echo "Всего устройств: ${#devices[@]}"
                                    echo ""
                                } > "$ping_report"
                                
                                local total_loss=0
                                local total_devices=${#devices[@]}
                                local failed_devices=0
                                
                                for device in "${devices[@]}"; do
                                    IFS='|' read -r ip mac hostname <<< "$device"
                                    
                                    echo -e "${BLUE}Тестирование $ip ($hostname)...${NC}"
                                    echo "Тестирование $ip ($hostname):" >> "$ping_report"
                                    
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
                                        total_loss=$((total_loss + loss_percent))
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
                                    echo "Средний процент потерь: $((total_loss / total_devices))%"
                                    echo ""
                                    
                                    if [[ $failed_devices -eq 0 && $((total_loss / total_devices)) -eq 0 ]]; then
                                        echo "Оценка качества: ОТЛИЧНОЕ"
                                    elif [[ $failed_devices -eq 0 && $((total_loss / total_devices)) -lt 5 ]]; then
                                        echo "Оценка качества: ХОРОШЕЕ"
                                    elif [[ $failed_devices -lt $((total_devices / 10)) ]]; then
                                        echo "Оценка качества: УДОВЛЕТВОРИТЕЛЬНОЕ"
                                    else
                                        echo "Оценка качества: ПЛОХОЕ"
                                    fi
                                } >> "$ping_report"
                                
                                echo -e "${GREEN}Анализ ping завершен${NC}"
                                echo -e "${GREEN}Отчет сохранен: $ping_report${NC}"
                                cat "$ping_report"
                                echo ""
                                read -p "Нажмите Enter для продолжения..."
                                ;;
                            1)  # Детальный анализ конкретного устройства
                                # Получаем список устройств для меню
                                local device_menu_items=()
                                local device ip mac hostname
                                
                                for device in "${devices[@]}"; do
                                    IFS='|' read -r ip mac hostname <<< "$device"
                                    if [[ "$hostname" != "unknown" && -n "$hostname" ]]; then
                                        device_menu_items+=("$hostname ($ip)")
                                    else
                                        device_menu_items+=("$ip")
                                    fi
                                done
                                device_menu_items+=("Назад")
                                
                                local DEVICE_TITLE="Выберите устройство для детального анализа"
                                local device_selected
                                
                                show_menu "$DEVICE_TITLE" "${device_menu_items[@]}"
                                
                                if [[ "$device_selected" =~ ^[0-9]+$ ]] && (( device_selected < ${#device_menu_items[@]} - 1 )); then
                                    local selected_device="${devices[device_selected]}"
                                    IFS='|' read -r ip mac hostname <<< "$selected_device"
                                    
                                    echo -e "${BLUE}Детальный анализ устройства: $ip${NC}"
                                    
                                    # Базовый ping
                                    echo -e "${BLUE}1. Базовый тест ping:${NC}"
                                    if ping -c 5 "$ip"; then
                                        echo -e "${GREEN}Устройство доступно${NC}"
                                    else
                                        echo -e "${RED}Устройство недоступно${NC}"
                                    fi
                                    
                                    # Расширенный ping
                                    echo -e "${BLUE}2. Расширенный тест ping (100 пакетов):${NC}"
                                    ping -c 100 "$ip"
                                    
                                    # Проверка ARP
                                    echo -e "${BLUE}3. Проверка ARP записи:${NC}"
                                    ip neigh show | grep "$ip"
                                    
                                    # Проверка маршрута (если доступно)
                                    if command -v traceroute &> /dev/null; then
                                        echo -e "${BLUE}4. Трассировка маршрута:${NC}"
                                        timeout 10 traceroute -m 10 "$ip" 2>/dev/null || echo "Трассировка не завершена"
                                    fi
                                    
                                    echo ""
                                    read -p "Нажмите Enter для продолжения..."
                                fi
                                ;;
                            2)  # Мониторинг стабильности
                                echo -e "${BLUE}Мониторинг стабильности сети...${NC}"
                                echo -e "${YELLOW}Нажмите Ctrl+C для остановки${NC}"
                                
                                local monitor_duration=60
                                read -p "Длительность мониторинга (секунд) [60]: " input_duration
                                monitor_duration=${input_duration:-60}
                                
                                local start_time
                                start_time=$(date +%s)
                                local end_time=$((start_time + monitor_duration))
                                
                                echo "Мониторинг на $monitor_duration секунд..."
                                
                                while [[ $(date +%s) -lt $end_time ]]; do
                                    local current_time
                                    current_time=$(date '+%H:%M:%S')
                                    echo "[$current_time] Проверка устройств:"
                                    
                                    local online_count=0
                                    local device ip
                                    
                                    for device in "${devices[@]}"; do
                                        IFS='|' read -r ip _ _ <<< "$device"
                                        if ping -c 1 -W 1 "$ip" &>/dev/null; then
                                            echo -e "  ${GREEN}✓ $ip${NC}"
                                            online_count=$((online_count + 1))
                                        else
                                            echo -e "  ${RED}✗ $ip${NC}"
                                        fi
                                    done
                                    
                                    echo "Онлайн: $online_count/${#devices[@]}"
                                    echo "---"
                                    
                                    sleep 5
                                done
                                
                                echo -e "${GREEN}Мониторинг завершен${NC}"
                                echo ""
                                read -p "Нажмите Enter для продолжения..."
                                ;;
                            3)  # Генерация сводного отчета
                                echo -e "${BLUE}Генерация сводного отчета...${NC}"
                                
                                local summary_timestamp
                                summary_timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
                                local summary_report="$log_dir/network-quality-summary-$summary_timestamp.txt"
                                
                                {
                                    echo "=== СВОДНЫЙ ОТЧЕТ О КАЧЕСТВЕ СЕТИ ==="
                                    echo "Дата: $(date)"
                                    echo "Исходный отчет: $(basename "$selected_report")"
                                    echo "Сеть: $network"
                                    echo "Устройств: $device_count"
                                    echo ""
                                    echo "=== ИНФОРМАЦИЯ ОБ УСТРОЙСТВАХ ==="
                                } > "$summary_report"
                                
                                # Анализ каждого устройства
                                local quality_stats=()
                                local device ip mac hostname
                                
                                for device in "${devices[@]}"; do
                                    IFS='|' read -r ip mac hostname <<< "$device"
                                    
                                    echo "Устройство: $ip" >> "$summary_report"
                                    echo "  MAC: $mac" >> "$summary_report"
                                    echo "  Hostname: $hostname" >> "$summary_report"
                                    
                                    # Краткий тест
                                    if ping -c 5 -W 1 "$ip" &>/dev/null; then
                                        local result
                                        result=$(ping -c 5 "$ip" 2>&1)
                                        local packet_loss
                                        packet_loss=$(echo "$result" | grep "packet loss" | awk '{print $6}')
                                        local avg_time
                                        avg_time=$(echo "$result" | grep "rtt" | awk -F'/' '{print $5}')
                                        
                                        echo "  Статус: ДОСТУПЕН" >> "$summary_report"
                                        echo "  Потери: $packet_loss" >> "$summary_report"
                                        echo "  Среднее время: ${avg_time:-N/A} ms" >> "$summary_report"
                                        
                                        # Классификация качества
                                        local loss_percent=${packet_loss%\%}
                                        if [[ $loss_percent -eq 0 ]]; then
                                            echo "  Качество: ОТЛИЧНОЕ" >> "$summary_report"
                                            quality_stats+=("excellent")
                                        elif [[ $loss_percent -lt 3 ]]; then
                                            echo "  Качество: ХОРОШЕЕ" >> "$summary_report"
                                            quality_stats+=("good")
                                        elif [[ $loss_percent -lt 10 ]]; then
                                            echo "  Качество: УДОВЛЕТВОРИТЕЛЬНОЕ" >> "$summary_report"
                                            quality_stats+=("satisfactory")
                                        else
                                            echo "  Качество: ПЛОХОЕ" >> "$summary_report"
                                            quality_stats+=("poor")
                                        fi
                                    else
                                        echo "  Статус: НЕДОСТУПЕН" >> "$summary_report"
                                        echo "  Качество: ПЛОХОЕ" >> "$summary_report"
                                        quality_stats+=("poor")
                                    fi
                                    echo "" >> "$summary_report"
                                done
                                
                                # Общая статистика
                                {
                                    echo "=== ОБЩАЯ СТАТИСТИКА ==="
                                    local excellent_count=0 good_count=0 satisfactory_count=0 poor_count=0
                                    for stat in "${quality_stats[@]}"; do
                                        case "$stat" in
                                            "excellent") excellent_count=$((excellent_count + 1)) ;;
                                            "good") good_count=$((good_count + 1)) ;;
                                            "satisfactory") satisfactory_count=$((satisfactory_count + 1)) ;;
                                            "poor") poor_count=$((poor_count + 1)) ;;
                                        esac
                                    done
                                    
                                    echo "Отличное качество: $excellent_count устройств"
                                    echo "Хорошее качество: $good_count устройств"
                                    echo "Удовлетворительное качество: $satisfactory_count устройств"
                                    echo "Плохое качество: $poor_count устройств"
                                    echo ""
                                    
                                    local total_quality=$((excellent_count * 4 + good_count * 3 + satisfactory_count * 2 + poor_count * 1))
                                    local max_quality=$(( ${#devices[@]} * 4 ))
                                    local quality_percent=$(( total_quality * 100 / max_quality ))
                                    
                                    echo "Общий уровень качества сети: $quality_percent%"
                                    
                                    if [[ $quality_percent -ge 90 ]]; then
                                        echo "РЕКОМЕНДАЦИЯ: Качество сети отличное"
                                    elif [[ $quality_percent -ge 75 ]]; then
                                        echo "РЕКОМЕНДАЦИЯ: Качество сети хорошее"
                                    elif [[ $quality_percent -ge 60 ]]; then
                                        echo "РЕКОМЕНДАЦИЯ: Качество сети удовлетворительное, требуется внимание"
                                    else
                                        echo "РЕКОМЕНДАЦИЯ: Качество сети плохое, требуется срочное вмешательство"
                                    fi
                                } >> "$summary_report"
                                
                                echo -e "${GREEN}Сводный отчет сохранен: $summary_report${NC}"
                                cat "$summary_report"
                                echo ""
                                read -p "Нажмите Enter для продолжения..."
                                ;;
                            4|q)  # Назад
                                break
                                ;;
                            *)
                                echo -e "${RED}Некорректный выбор${NC}"
                                sleep 1
                                ;;
                        esac
                    done
                elif (( selected == ${#report_display_names[@]} )); then
                    # Обновить список отчетов
                    reports=()
                    while IFS= read -r file; do
                        [[ -f "$file" ]] && reports+=("$file")
                    done < <(find "$log_dir" -name "devices-*.txt" -type f | sort -r)
                    
                    report_info=()
                    report_display_names=()
                    
                    for report_file in "${reports[@]}"; do
                        date_time=$(grep "^Дата:" "$report_file" 2>/dev/null | cut -d: -f2- | xargs)
                        interface=$(grep "^Интерфейс:" "$report_file" 2>/dev/null | cut -d: -f2 | xargs)
                        network=$(grep "^Сеть:" "$report_file" 2>/dev/null | cut -d: -f2 | xargs)
                        device_count=$(grep "^Найдено" "$report_file" 2>/dev/null | awk '{print $2}')
                        
                        local display_name
                        if [[ -n "$date_time" ]]; then
                            display_name="$(basename "$report_file") - $date_time"
                        else
                            display_name="$(basename "$report_file")"
                        fi
                        
                        report_info+=("$date_time|$interface|$network|$device_count")
                        report_display_names+=("$display_name")
                    done
                    
                    menu_items=("${report_display_names[@]}" "Обновить список")
                else
                    echo -e "${RED}Некорректный выбор${NC}"
                    sleep 1
                fi
                ;;
            q)
                return 0
                ;;
            *)
                echo -e "${RED}Некорректный выбор${NC}"
                sleep 1
                ;;
        esac
    done
}