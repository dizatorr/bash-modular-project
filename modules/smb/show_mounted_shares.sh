#!/usr/bin/env bash
# === MENU: Список всех смонтированных CIFS/SMB ресурсов
# === FUNC: show_mounted_shares
# Автор: Diz A Torr
# Версия: 1.0
# Лицензия: MIT
# Описание: Отображение списка всех смонтированных CIFS/SMB ресурсов

show_mounted_shares() {
    show_menu_header "Смонтированные SMB ресурсы"

    # Проверяем доступность команды mount
    if ! command -v mount &>/dev/null; then
        echo "Команда mount недоступна"
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

    # Выводим информацию о каждом ресурсе
    local line_count=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Пропускаем пустые строки
        [[ -z "$line" ]] && continue
        
        ((line_count++))
        echo -e "${YELLOW}Ресурс #$line_count:${NC}"
        
        # Парсим строку монтирования
        # Пример строки: //server/share on /mount/point type cifs (rw,relatime,cache=strict,username=user,domain=domain.com,...)
        
        if [[ "$line" =~ ^//([^/]+)/([^[:space:]]+)[[:space:]]+on[[:space:]]+([^[:space:]]+)[[:space:]]+type[[:space:]]+cifs[[:space:]]*\((.*)\)$ ]]; then
            local server="${BASH_REMATCH[1]}"
            local share="${BASH_REMATCH[2]}"
            local mount_point="${BASH_REMATCH[3]}"
            local options="${BASH_REMATCH[4]}"
            
            echo "  Сервер:     $server"
            echo "  Ресурс:     $share"
            echo "  Точка монтирования: $mount_point"
            
            # Извлекаем интересные опции
            local username domain vers
            if [[ "$options" =~ username=([^,]+) ]]; then
                username="${BASH_REMATCH[1]}"
            fi
            
            if [[ "$options" =~ domain=([^,]+) ]]; then
                domain="${BASH_REMATCH[1]}"
            fi
            
            if [[ "$options" =~ vers=([^,]+) ]]; then
                vers="${BASH_REMATCH[1]}"
            fi
            
            # Выводим дополнительную информацию, если она есть
            [[ -n "$username" ]] && echo "  Пользователь: $username"
            [[ -n "$domain" ]] && echo "  Домен:        $domain"
            [[ -n "$vers" ]] && echo "  Версия SMB:   $vers"
            
            # Показываем режим доступа
            if [[ "$options" =~ rw ]]; then
                echo "  Доступ:       Чтение/Запись"
            elif [[ "$options" =~ ro ]]; then
                echo "  Доступ:       Только чтение"
            fi
            
        else
            # Если не удалось распарсить, выводим как есть
            echo "  $line"
        fi
        
        echo # Пустая строка для разделения ресурсов
    done <<< "$cifs_mounts"
    
    # Выводим общее количество
    echo -e "${BLUE}Всего смонтировано ресурсов: $line_count${NC}"
}