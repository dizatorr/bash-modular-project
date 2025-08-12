#!/usr/bin/env bash
# === MENU: Просмотр результатов диагностики
# === FUNC: show_network_diagnostics
# Автор: Diz A Torr
# Версия: 1.0
# Лицензия: MIT
# Описание: Просмотр сохраненных результатов сетевой диагностики

show_network_diagnostics() {
    local log_dir="$LOG_DIR"
    
    clear
    echo -e "${BLUE}=== Результаты сетевой диагностики ===${NC}"
    echo

    # Проверяем наличие файлов диагностики
    local diag_files=()
    mapfile -t diag_files < <(find "$log_dir" -name "devices-*.txt" -type f 2>/dev/null | sort -r)

    if [[ ${#diag_files[@]} -eq 0 ]]; then
        echo "Нет сохраненных результатов диагностики"
        return 0
    fi

    echo "Найдено отчетов: ${#diag_files[@]}"
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
    
    if [[ -f "$selected_file" ]]; then
        echo
        echo "=== Содержимое отчета: $(basename "$selected_file") ==="
        echo
        cat "$selected_file"
    else
        log_error "Файл отчета не найден: $selected_file"
        return 1
    fi
}