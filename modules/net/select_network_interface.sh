#!/usr/bin/env bash
# === MENU: Выбрать сетевой интерфейс
# === FUNC: select_network_interface
# Автор: Diz A Torr
# Версия: 1.0
# Лицензия: MIT
# Описание: Выбор сетевого интерфейса для диагностики

select_network_interface() {
    local config_file="${1:-$DNSMASQ_CONF}"
    
    # Проверка существования конфига
    if ! load_config "$config_file" true false ; then
        echo -e "${RED}Создайте файл: $config_file${NC}"
        return 1
    fi

    # Выбираем интерфейс
    local interfaces=()
    mapfile -t interfaces < <(ip -br link show | awk '$2 == "UP" {print $1}' | grep -v "^lo$")

    if [[ ${#interfaces[@]} -eq 0 ]]; then
        log_error "Нет активных интерфейсов"
        return 1
    fi

    # Получаем текущий интерфейс из конфига (если есть)
    local current_interface
    current_interface=$(grep -E "^[[:space:]]*interface=" "$config_file" | head -n1 | cut -d'=' -f2 | xargs)
    
    local selected_interface

    if [[ ${#interfaces[@]} -eq 1 ]]; then
        selected_interface="${interfaces[0]}"
        log_info "Автоматически выбран интерфейс: $selected_interface"
    else
        # Добавляем текущий интерфейс в начало списка, если он есть
        #local display_interfaces=()
        local default_choice=0
        
        if [[ -n "$current_interface" ]] && [[ " ${interfaces[*]} " =~ " $current_interface " ]]; then
            # Находим индекс текущего интерфейса
            for i in "${!interfaces[@]}"; do
                if [[ "${interfaces[$i]}" == "$current_interface" ]]; then
                    default_choice=$i
                    break
                fi
            done
        fi
        
        local choices=()
        for i in "${!interfaces[@]}"; do
            if [[ $i -eq $default_choice ]]; then
                choices+=("$i" "${interfaces[$i]} (текущий)")
            else
                choices+=("$i" "${interfaces[$i]}")
            fi
        done

        local choice
        case "$USE_TUI" in
            "dialog")
                choice=$(dialog --clear --title "Выбор интерфейса" --menu "Интерфейс:" 15 60 5 "${choices[@]}" 3>&1 1>&2 2>&3)
                ;;
            "whiptail")
                choice=$(whiptail --title "Выбор интерфейса" --menu "Интерфейс:" 15 60 5 "${choices[@]}" 3>&1 1>&2 2>&3)
                ;;
            *)
                echo "Доступные интерфейсы:"
                for i in "${!interfaces[@]}"; do
                    if [[ $i -eq $default_choice ]]; then
                        echo " [$i] ${interfaces[$i]} (текущий)"
                    else
                        echo " [$i] ${interfaces[$i]}"
                    fi
                done
                read -p "Выберите номер (Enter для текущего - $current_interface): " choice
                choice="${choice:-$default_choice}"
                ;;
        esac

        if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 0 )) || (( choice >= ${#interfaces[@]} )); then
            log_error "Неверный выбор интерфейса"
            return 1
        fi

        selected_interface="${interfaces[choice]}"
    fi

    # Записываем выбранный интерфейс в конфиг
    if write_interface_to_config "$config_file" "$selected_interface"; then
        log_info "Выбран и записан интерфейс: $selected_interface"
        echo "$selected_interface"
        return 0
    else
        log_error "Не удалось записать интерфейс в конфиг"
        return 1
    fi
}

# Вспомогательная функция для записи интерфейса в конфиг
write_interface_to_config() {
    local config_file="$1"
    local interface="$2"
    local temp_file
    temp_file=$(mktemp)
    
    if [[ ! -f "$temp_file" ]]; then
        log_error "Не удалось создать временный файл"
        return 1
    fi
    
    # Если в конфиге уже есть interface=, заменяем его
    if grep -qE "^[[:space:]]*interface=" "$config_file"; then
        sed -E "s/^[[:space:]]*interface=.*/interface=$interface/" "$config_file" > "$temp_file"
    else
        # Если нет, добавляем в начало
        echo "interface=$interface" > "$temp_file"
        cat "$config_file" >> "$temp_file"
    fi
    
    # Перемещаем временный файл на место оригинала
    if mv "$temp_file" "$config_file"; then
        log_debug "Интерфейс $interface записан в $config_file"
        return 0
    else
        log_error "Не удалось обновить конфиг файл"
        rm -f "$temp_file"
        return 1
    fi
}