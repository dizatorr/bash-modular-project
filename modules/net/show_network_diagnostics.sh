#!/usr/bin/env bash
# === MENU: Просмотр результатов диагностики
# === FUNC: show_network_diagnostics
# Автор: Diz A Torr
# Версия: 1.0
# Лицензия: MIT
# Описание: Просмотр сохраненных результатов сетевой диагностики

show_network_diagnostics() {
    # shellcheck disable=SC2153
    local log_dir="$LOG_DIR"
    local hosts_dir="$log_dir"
    
    show_menu_header "Результаты сетевой диагностики"
    
    # Проверяем наличие файлов диагностики
    local diag_files=()
    mapfile -t diag_files < <(find "$log_dir" -name "devices-*.txt" -type f 2>/dev/null | sort -r)

    if [[ ${#diag_files[@]} -eq 0 ]]; then
        log_warn "Нет сохраненных результатов диагностики"
        return 0
    fi

    log_info "Найдено отчетов: ${#diag_files[@]}"
    echo

    # Показываем последние 10 отчетов
    local count=0
    local file
    for file in "${diag_files[@]}"; do
        ((count++))
        if (( count > 10 )); then
            break
        fi
        
        local filename
        filename=$(basename "$file")
        echo "[$count] $filename"
    done

    echo
    read -p "Выберите отчет для просмотра (1-$((count < 10 ? count : 10))), или 0 для выхода: " choice

    if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 0 )) || (( choice > count )); then
        log_warn "Некорректный выбор"
        return 1
    fi

    if (( choice == 0 )); then
        return 0
    fi

    local selected_file="${diag_files[$((choice-1))]}"
    
    if [[ ! -f "$selected_file" ]]; then
        log_error "Файл отчета не найден: $selected_file"
        return 1
    fi

    show_menu_header "Содержимое отчета: $(basename "$selected_file")"
    cat "$selected_file"
    
    # Предложение создать хостфайл
    echo
    read -r -p "Создать хостфайл на основе этого отчета? (y/N): " create_hosts
    if [[ "${create_hosts,,}" =~ ^(y|yes)$ ]]; then
        net_create_hosts_from_report "$selected_file" "$hosts_dir"
    fi
}

# Функция для создания хостфайла из отчета диагностики
net_create_hosts_from_report() {
    local report_file="$1"
    local hosts_dir="$2"
    
    # Создаем директорию если она не существует
    mkdir -p "$hosts_dir"
    
    # Генерируем имя файла хостфайла
    local report_name
    report_name=$(basename "$report_file" .txt)
    local hosts_file="$hosts_dir/hosts_${report_name#devices-}.txt"
    
    log_info "Создание хостфайла: $hosts_file"
    
    # Создаем хостфайл в формате Ansible
    {
        echo "# Хостфайл, созданный из отчета диагностики: $(basename "$report_file")"
        echo "# Дата создания: $(date '+%Y-%m-%d %H:%M:%S')"
        echo
        echo "[all]"
    } > "$hosts_file"
    
    # Извлекаем IP-адреса из отчета
    local ip_count=0
    while IFS= read -r line; do
        # Ищем строки с IP-адресами (формат: IP MAC Vendor)
        if [[ "$line" =~ ^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)[[:space:]]+([0-9a-fA-F:]+)[[:space:]]+(.*)$ ]]; then
            local ip="${BASH_REMATCH[1]}"
            local mac="${BASH_REMATCH[2]}"
            local vendor="${BASH_REMATCH[3]}"
            
            # Пропускаем шлюз (обычно заканчивается на .1)
            if [[ ! "$ip" =~ \.1$ ]]; then
                echo "$ip ansible_user=tecon" >> "$hosts_file"
                ((ip_count++))
            fi
        fi
    done < "$report_file"
    
    if [[ $ip_count -gt 0 ]]; then
        log_info "Хостфайл успешно создан. Добавлено устройств: $ip_count"
        echo "Файл сохранен: $hosts_file"
        
        # Предложение просмотреть созданный файл
        echo
        read -p "Показать содержимое созданного хостфайла? (y/N): " show_hosts
        if [[ "${show_hosts,,}" =~ ^(y|yes)$ ]]; then
            show_menu_header "Содержимое хостфайла"
            cat "$hosts_file"
        fi
    else
        log_warn "Не найдено IP-адресов для добавления в хостфайл"
        rm -f "$hosts_file"  # Удаляем пустой файл
    fi
}

# Функция для просмотра существующих хостфайлов
net_show_hosts_files() {
    local hosts_dir="${1:-security}"
    
    show_menu_header "Существующие хостфайлы"
    
    # Проверяем наличие хостфайлов
    local hosts_files=()
    mapfile -t hosts_files < <(find "$hosts_dir" -name "hosts_*.txt" -type f 2>/dev/null | sort -r)

    if [[ ${#hosts_files[@]} -eq 0 ]]; then
        log_warn "Нет сохраненных хостфайлов"
        return 0
    fi

    log_info "Найдено хостфайлов: ${#hosts_files[@]}"
    echo

    # Показываем хостфайлы
    local count=0
    local file
    for file in "${hosts_files[@]}"; do
        ((count++))
        local filename
        filename=$(basename "$file")
        local device_count
        device_count=$(grep -c "^[0-9]\+\." "$file" 2>/dev/null || echo "0")
        echo "[$count] $filename (устройств: $device_count)"
    done

    echo
    read -r -p "Выберите хостфайл для просмотра (1-${#hosts_files[@]}), или 0 для выхода: " choice

    if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 0 )) || (( choice > ${#hosts_files[@]} )); then
        log_warn "Некорректный выбор"
        return 1
    fi

    if (( choice == 0 )); then
        return 0
    fi

    local selected_file="${hosts_files[$((choice-1))]}"
    
    if [[ -f "$selected_file" ]]; then
        show_menu_header "Содержимое хостфайла: $(basename "$selected_file")"
        cat "$selected_file"
    else
        log_error "Файл хостфайла не найден: $selected_file"
        return 1
    fi
}