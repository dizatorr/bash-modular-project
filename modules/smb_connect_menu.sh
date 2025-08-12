#!/usr/bin/env bash
# === MENU: Подключение к SMB ресурсам 2
# === FUNC: smb_connect_menu
# Автор: Diz A Torr
# Версия: 1.0
# Лицензия: MIT
# Описание: Подключение и работа с SMB ресурсами

# --- Константы ---
readonly DEFAULT_CONFIG_FILE="$SCRIPT_DIR/config/smb_quick.conf"

# --- Функции проверки зависимостей ---
check_smb_dependencies() {
    if ! command -v smbclient &>/dev/null; then
        log_error "smbclient не установлен"
        echo -e "${RED}Установите пакет samba-common-bin${NC}"
        return 1
    fi
    return 0
}

# --- Главное меню ---
smb_connect_menu() {
    local module_dir="$SCRIPT_DIR/modules/smb"
    # Проверяем зависимости
    check_smb_dependencies || return 1

    # Автоматически загружаем все модули из директории modules/smb
    load_modules "$module_dir" || {
        log_error "Ошибка загрузки модулей SMB"
        return 1
    }

    local MENU_TITLE="Работа с SMB"
    local selected

    # Основной цикл меню
    while true; do
        clear
        show_menu "$MENU_TITLE" "${MENU_ITEMS[@]}"
        
        # Обрабатываем выбор пользователя
        case "$selected" in
            [0-9]*)
                # Проверяем, что индекс в допустимом диапазоне
                if (( selected < ${#MENU_ITEMS[@]} )) && (( selected < ${#FUNCTIONS[@]} )); then
                    # Вызываем функцию модуля
                    log_debug "Выбран модуль $selected"
                    call_module_function "$selected" "$DEFAULT_CONFIG_FILE"
                else
                    log_error "Некорректный выбор"
                fi
                ;;
            q) 
                load_module_var
                return 0 ;;
            *) log_error "Некорректный выбор" ;;
        esac
        
        echo
        read -n1 -r -s -p "Нажмите любую клавишу для продолжения..."
    done
}