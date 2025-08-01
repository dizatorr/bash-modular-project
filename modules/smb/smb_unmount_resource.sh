#!/usr/bin/env bash
# === MENU: Отмонтировать SMB ресурс
# === FUNC: smb_unmount_resource_menu
# Автор: Diz A Torr
# Версия: 1.0
# Лицензия: MIT
# Описание: Выбор и отмонтирование SMB ресурса из списка смонтированных

smb_unmount_resource_menu() {
    clear
    echo -e "${BLUE}=== Отмонтирование SMB ресурса ===${NC}"
    echo

    # Проверяем доступность команды mount
    if ! command -v mount &>/dev/null; then
        log_error "Команда mount недоступна"
        return 1
    fi

    # Получаем список смонтированных CIFS ресурсов
    local cifs_mounts
    cifs_mounts=$(mount | grep -i cifs | grep -v grep)

    # Проверяем, есть ли смонтированные ресурсы
    if [[ -z "$cifs_mounts" ]]; then
        echo "Нет смонтированных CIFS ресурсов"
        return 0
    fi

    # Массивы для хранения информации о ресурсах
    local mount_points=()
    local display_items=()

    # Парсим каждый ресурс
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" ]] && continue
        
        # Парсим строку монтирования
        if [[ "$line" =~ ^//([^/]+)/([^[:space:]]+)[[:space:]]+on[[:space:]]+([^[:space:]]+)[[:space:]]+type[[:space:]]+cifs ]]; then
            local server="${BASH_REMATCH[1]}"
            local mount_point="${BASH_REMATCH[3]}"
            mount_points+=("$mount_point")
            display_items+=("Сервер: $server | Точка: $mount_point")
        else
            # Альтернативный способ извлечения точки монтирования
            if [[ "$line" =~ [[:space:]]on[[:space:]]+([^[:space:]]+)[[:space:]]+type[[:space:]]+cifs ]]; then
                local mount_point="${BASH_REMATCH[1]}"
                mount_points+=("$mount_point")
                display_items+=("Точка: $mount_point")
            else
                # Последний резерв
                local mount_point=$(echo "$line" | awk '{print $3}')
                mount_points+=("$mount_point")
                display_items+=("Точка: $mount_point")
            fi
        fi
    done <<< "$cifs_mounts"
    
    # Проверяем, что у нас есть ресурсы для отображения
    if [[ ${#display_items[@]} -eq 0 ]]; then
        log_warn "Не удалось извлечь информацию о смонтированных ресурсах"
        return 1
    fi

    # Добавляем опцию для ручного ввода
    display_items+=("Ввести точку монтирования вручную")
    
    # Показываем меню выбора
    local selected
    local MENU_TITLE="Выберите ресурс для отмонтирования"
    show_menu "$MENU_TITLE" "${display_items[@]}"
    
    local mount_point_to_unmount=""
    
    case "$selected" in
        [0-9]*)
            if (( selected < ${#display_items[@]} - 1 )); then
                # Выбран ресурс из списка
                mount_point_to_unmount="${mount_points[selected]}"
            elif (( selected == ${#display_items[@]} - 1 )); then
                # Выбран ручной ввод
                read -r -p "Введите точку монтирования: " mount_point_to_unmount
                if [[ -z "$mount_point_to_unmount" ]]; then
                    log_warn "Точка монтирования не указана"
                    return 1
                fi
            else
                log_warn "Некорректный выбор"
                return 1
            fi
            ;;
        q)
            return 0
            ;;
        *)
            log_warn "Некорректный выбор"
            return 1
            ;;
    esac

    # Проверяем, что точка монтирования указана и существует
    if [[ -z "$mount_point_to_unmount" ]]; then
        log_error "Точка монтирования не указана"
        return 1
    fi

    if [[ ! -d "$mount_point_to_unmount" ]]; then
        log_error "Указанная точка монтирования не существует: $mount_point_to_unmount"
        return 1
    fi

    # Пытаемся отмонтировать
    echo -e "${YELLOW}Попытка отмонтировать: $mount_point_to_unmount${NC}"
    
    if sudo umount "$mount_point_to_unmount"; then
        log_info "Успешно отмонтировано: $mount_point_to_unmount"
        # Удаляем временную директорию если она в /tmp
        [[ "$mount_point_to_unmount" == /tmp/* ]] && rmdir "$mount_point_to_unmount" 2>/dev/null && log_info "Удалена временная директория: $mount_point_to_unmount"
    else
        local exit_code=$?
        log_error "Ошибка отмонтирования (код: $exit_code)"
        echo -e "${YELLOW}Попробовать принудительное отмонтирование?${NC}"
        
        local force_choice
        read -r -p "Принудительное отмонтирование (y/N): " force_choice
        
        if [[ "$force_choice" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Попытка принудительного отмонтирования...${NC}"
            if sudo umount -f "$mount_point_to_unmount"; then
                log_info "Успешно отмонтировано принудительно: $mount_point_to_unmount"
                [[ "$mount_point_to_unmount" == /tmp/* ]] && rmdir "$mount_point_to_unmount" 2>/dev/null && log_info "Удалена временная директория: $mount_point_to_unmount"
            else
                log_error "Принудительное отмонтирование не удалось"
                echo -e "${YELLOW}Совет: Закройте все приложения, использующие этот ресурс, и попробуйте снова${NC}"
            fi
        fi
    fi
}