#!/usr/bin/env bash
# === MENU: Подключение к SMB ресурсам через smbclient
# === FUNC: smb_interactive_connect
# Автор: Diz A Torr
# Версия: 1.0
# Лицензия: MIT
# Описание: Интерактивное подключение к SMB ресурсу через smbclient
#
# === Список функций ===
# - smb_interactive_connect() - основная функция модуля, обеспечивает интерактивное подключение
# - smb_get_username() - внутренняя функция для получения имени пользователя
# - smb_load_resources() - внутренняя функция для загрузки списка ресурсов
# - smb_get_display_names() - внутренняя функция для получения отображаемых имен ресурсов
#
# === Требования ===
# - Внешние зависимости: smbclient
# - Зависимости от других модулей: нет
# - Права доступа: стандартные
# - Требуемые переменные окружения: GREEN, RED, YELLOW, NC (из lib.sh)
#
# === Примеры использования ===
# - вызов smb_interactive_connect напрямую
# - вызов smb_interactive_connect с параметром: config_file

# --- Вспомогательные функции ---
# Получает имя пользователя с учетом дефолтного значения
smb_get_username() {
    local username
    if [[ -n "$SMB_DEFAULT_USER" ]]; then
        echo "$SMB_DEFAULT_USER"
    else
        read -p "Имя пользователя [domen\\name или name@domen] (оставьте пустым для гостевого доступа): " username
        echo "$username"
    fi
}

# Загружает ресурсы из конфигурационного файла
smb_load_resources() {
    local config_file="$1"
    local resources=()
    
    # Проверяем существование файла
    [[ -f "$config_file" ]] || return 0
    
    # Читаем файл построчно
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Пропускаем комментарии и пустые строки
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line//[[:space:]]/}" ]] && continue
        
        # Проверяем формат: сервер|ресурс|отображаемое_имя|опции
        [[ "$line" == *'|'* ]] && resources+=("$line")
    done < "$config_file"
    
    # Возвращаем массив ресурсов
    echo "${resources[@]}"
}

# Извлекает отображаемые имена из данных ресурсов
smb_get_display_names() {
    local resources=("$@")
    local names=()
    local display_name

    # Проходим по всем ресурсам и извлекаем отображаемые имена
    for resource in "${resources[@]}"; do
        IFS='|' read -r _ _ display_name _ <<< "$resource"
        [[ -n "$display_name" ]] && names+=("$display_name")
    done
    
    # Возвращаем массив отображаемых имен
    echo "${names[@]}"
}


smb_interactive_connect() {
    local config_file="$1"
    local server share username

    # Загружаем список ресурсов
    local shares_data=($(smb_load_resources "$config_file"))
    local display_names=($(smb_get_display_names "${shares_data[@]}"))

    # Если есть настроенные ресурсы, показываем меню выбора
    if [[ ${#display_names[@]} -gt 0 ]]; then
        # Добавляем опцию для ручного ввода
        local menu_items=("${display_names[@]}" "Ввести сервер и ресурс вручную")
        local MENU_TITLE="Выберите SMB ресурс"
        local selected
        
        show_menu "$MENU_TITLE" "${menu_items[@]}"
        
        case "$selected" in
            [0-9]*)
                if (( selected < ${#display_names[@]} )); then
                    # Выбран ресурс из списка
                    local selected_share="${shares_data[selected]}"
                    local display_name options
                    IFS='|' read -r server share display_name options <<< "$selected_share"
                elif (( selected == ${#display_names[@]} )); then
                    # Выбран ручной ввод
                    read -p "Адрес сервера: " server
                    read -p "Имя ресурса (share): " share
                else
                    log_warn "Некорректный выбор"
                    return
                fi
                ;;
            q)
                return 0
                ;;
            *)
                log_warn "Некорректный выбор"
                return
                ;;
        esac
    else
        # Нет настроенных ресурсов, запрашиваем вручную
        read -p "Адрес сервера: " server
        read -p "Имя ресурса (share): " share
    fi

    # Получаем имя пользователя с учетом дефолтного значения
    username=$(smb_get_username)

    # Проверяем обязательные параметры и подключаемся
    if [[ -n "$server" && -n "$share" ]]; then
        local smb_path="//${server}/${share}"
        echo -e "${YELLOW}Подключение к: $smb_path${NC}"

        local exit_code
        if [[ -n "$username" ]]; then
            smbclient "$smb_path" -U "$username"
            exit_code=$?
        else
            smbclient "$smb_path" -N
            exit_code=$?
        fi

        if [[ $exit_code -eq 0 ]]; then
            log_info "Успешное подключение к $smb_path"
        else
            log_error "Ошибка подключения к $smb_path (код: $exit_code)"
        fi
    else
        log_warn "Не указаны обязательные параметры (сервер или ресурс)"
    fi
}