#!/usr/bin/env bash
# === MENU: Монтирование SMB ресурсов
# === FUNC: smb_mount_resource
# Автор: Diz A Torr
# Версия: 1.0
# Лицензия: MIT
# Описание: Монтирование SMB ресурса в локальную файловую систему

smb_mount_resource() {
    local config_file="$1"

    if ! command -v mount.cifs &>/dev/null; then
        log_error "mount.cifs не установлен"
        echo -e "${RED}Установите пакет cifs-utils${NC}"
        return 1
    fi

    show_menu_header "Монтирование SMB ресурса"

    # Загружаем список ресурсов
    # shellcheck disable=SC2207
    local shares_data=($(load_smb_resources "$config_file"))
    # shellcheck disable=SC2207
    local display_names=($(get_display_names "${shares_data[@]}"))

    if [[ ${#display_names[@]} -eq 0 ]]; then
        echo "Нет настроенных ресурсов. Сначала настройте список ресурсов."
        echo "Файл конфигурации: $config_file"
        return
    fi

    echo "Выберите ресурс для монтирования:"
    for i in "${!display_names[@]}"; do
        echo "$((i+1)). ${display_names[$i]}"
    done
    echo

    local choice
    read -p "Выбор (1-${#display_names[@]}): " choice

    if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 )) || (( choice > ${#shares_data[@]} )); then
        log_warn "Некорректный выбор"
        return
    fi

    local selected_share="${shares_data[$((choice-1))]}"
    local server share display_name options
    IFS='|' read -r server share display_name options <<< "$selected_share"

    # Получаем учетные данные
    local username password domain
    username=$(get_smb_username)

    # Извлекаем домен из опций конфигурации
    if [[ -n "$options" && "$options" == *"domain="* ]]; then
        domain=$(echo "$options" | grep -o "domain=[^,]*" | cut -d'=' -f2)
    fi

    # Если домен не указан в конфиге, спрашиваем у пользователя
    if [[ -z "$domain" && -n "$username" ]]; then
        read -r -p "Домен (например, domain.local, оставьте пустым если не нужен): " domain
    fi

    local mount_point
    read -r -p "Точка монтирования (пусто для временной): " mount_point

    if [[ -z "$mount_point" ]]; then
        mount_point=$(mktemp -d)
        log_info "Создана временная точка монтирования: $mount_point"
    fi

    # Создаем точку монтирования если не существует
    if [[ ! -d "$mount_point" ]]; then
        mkdir -p "$mount_point" || {
            log_error "Не удалось создать точку монтирования: $mount_point"
            return 1
        }
    fi

    local smb_path="//${server}/${share}"

    # Подготовка опций монтирования
    local options_array=()
    local cred_options=()
    local cred_file="" # Объявляем здесь, чтобы использовать вне блока if

    # Добавляем базовые опции
    options_array+=("uid=$(id -u)")
    options_array+=("gid=$(id -g)")
    options_array+=("iocharset=utf8")
    options_array+=("sec=ntlmssp")

    if [[ -n "$username" ]]; then
        # Если указан пользователь, запрашиваем пароль
        read -s -p "Пароль для $username: " password
        echo

        # Обрабатываем имя пользователя - если содержит домен, разделяем
        local user_only="$username"
        local user_domain=""

        if [[ "$username" == *"\\"* ]]; then
            # Формат: домен\пользователь
            user_domain="${username%%\\*}"
            user_only="${username#*\\}"
        elif [[ "$username" == *"@"* ]]; then
            # Формат: пользователь@домен
            user_only="${username%@*}"
            user_domain="${username#*@}"
        fi

        # Создаем временный файл с учетными данными
        cred_file=$(mktemp)
        echo "username=$user_only" > "$cred_file"
        echo "password=$password" >> "$cred_file"
        [[ -n "$user_domain" ]] && echo "domain=$user_domain" >> "$cred_file"
        chmod 600 "$cred_file"
        options_array+=("credentials=$cred_file")
        cred_options+=("credentials=$cred_file")
    else
        # Гостевой доступ
        options_array+=("guest")
    fi

    # Добавляем домен в опции, если он указан отдельно
    if [[ -n "$domain" && -z "$(echo "${cred_options[*]}" | grep domain)" ]]; then
        options_array+=("domain=$domain")
    fi

    # Добавляем опции из конфигурации (кроме domain, который уже обработан)
    if [[ -n "$options" ]]; then
        IFS=',' read -ra config_options <<< "$options"
        local opt config_domain
        for opt in "${config_options[@]}"; do
            opt=$(echo "$opt" | xargs) # trim whitespace
            # Пропускаем domain, если он уже добавлен
            if [[ -n "$opt" && "$opt" != "domain="* ]]; then
                options_array+=("$opt")
            elif [[ "$opt" == "domain="* && -z "$domain" ]]; then
                # Если domain не задан явно, берем из конфига
                config_domain="${opt#domain=}"
                if [[ -n "$config_domain" ]]; then
                    options_array+=("domain=$config_domain")
                fi
            fi
        done
    fi

    # Формируем строку опций
    local mount_options
    mount_options=$(IFS=','; echo "${options_array[*]}")

    echo -e "${YELLOW}Команда монтирования:${NC}"
    echo "sudo mount.cifs \"$smb_path\" \"$mount_point\" -o $mount_options"
    echo

    # Монтируем с учетными данными
    local result=0
    if sudo mount.cifs "$smb_path" "$mount_point" -o "$mount_options"; then
        log_info "Успешно смонтировано: $smb_path -> $mount_point"
    else
        log_error "Ошибка монтирования (код: $?)"
        echo -e "${YELLOW}Попробуйте указать домен в формате домен\\пользователь или пользователь@домен${NC}"
        result=1
        # Удаляем временную директорию если создавали
        [[ "$mount_point" == /tmp/* ]] && rmdir "$mount_point" 2>/dev/null
    fi

    # Удаляем временный файл с учетными данными
    [[ -n "$cred_file" ]] && rm -f "$cred_file"

    return $result
}