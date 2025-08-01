#!/usr/bin/env bash
# === MENU: Настройка списка быстрых SMB
# === FUNC: configure_smb_resources
# Автор: Diz A Torr
# Версия: 1.0
# Лицензия: MIT
# Описание: Настройка списка быстрых SMB ресурсов через редактор

# Предполагается, что следующие функции определены в основном скрипте или подключены отдельно:
# log_info

configure_smb_resources() {
    local config_file="$1"
    show_menu_header "Настройка SMB ресурсов"
    echo "Формат конфигурации:"
    echo "сервер|ресурс|отображаемое_имя|дополнительные_опции"
    echo "Пример: share.domain.local|dir|Файлопомойка|domain=domain.local,vers=3.0"
    echo

    # Создаем конфиг если его нет
    if [[ ! -f "$config_file" ]]; then
        mkdir -p "$(dirname "$config_file")"
        cat > "$config_file" << 'EOF'
# Файл быстрого доступа к SMB ресурсам
# Формат: сервер|ресурс|отображаемое_имя|дополнительные_опции
# Дополнительные опции: domain=имя_домена,vers=версия и т.д.
EOF
        log_info "Создан файл конфигурации"
    fi

    # Выбираем редактор
    local editors=("nano" "vim" "vi" "gedit") # Доступные редакторы по умолчанию
    local editor=""
    local ed
    for ed in "${editors[@]}"; do
        if command -v "$ed" &>/dev/null; then
            editor="$ed"
            break
        fi
    done

    if [[ -n "$editor" ]]; then
        $editor "$config_file"
    else
        echo "Доступные редакторы не найдены. Откройте файл вручную:"
        echo "$config_file"
        echo
        echo "=== Текущее содержимое ==="
        cat "$config_file"
        echo "========================"
        read -p "Нажмите Enter после редактирования файла..."
    fi
}