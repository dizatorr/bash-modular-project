#!/usr/bin/env bash
# === MENU: Подключение к SMB ресурсам через smbclient
# === FUNC: smb_interactive_connect
# Автор: Diz A Torr
# Версия: 1.0
# Лицензия: MIT
# Описание: Интерактивное подключение к SMB ресурсу через smbclient

smb_interactive_connect() {
    local config_file="$1"
    local server share username

    # Загружаем список ресурсов
    local shares_data=($(load_smb_resources "$config_file"))
    local display_names=($(get_display_names "${shares_data[@]}"))

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
    username=$(get_smb_username)

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