#!/usr/bin/env bash
# === MENU: Диагностика сети с локальным DHCP/DNS
# === FUNC: network_diagnostic_sub
# Автор: Diz A Torr
# Версия: 1.0 (субмодульная версия)
# Лицензия: MIT
# Описание: Комплексная диагностика сети с возможностью запуска локального DHCP/DNS

# Проверка зависимостей

check_network_diagnostic_dependencies() {
    local config_file="$DNSMASQ_CONF"
    local deps=("ping" "nslookup" "ipcalc" "dnsmasq" "ip" "nmcli")
    local missing=()
    local cmd

    # Проверка прав root
    if [[ $EUID -ne 0 ]]; then
        log_error "Требуются права root"
        echo -e "${RED}Выполните: sudo ./Start.sh${NC}"
        return 1
    fi

    # Проверка зависимостей    
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Не хватает зависимостей: ${missing[*]}"
        echo -e "${RED}Установите: sudo apt install ${missing[*]}${NC}"
        return 1
    fi
    log_debug "Зависимости проверены успешно"

    return 0
}

check_network_inteface() {
    # Проверка существования конфига
    if ! load_config "$config_file" true false ; then
        echo -e "${RED}Создайте файл: $config_file${NC}"
        return 1
    fi
    
    log_debug "Чтение конфига: $config_file"
    
    # Получаем интерфейс из конфига
    local interface
    interface=$(grep -E "^[[:space:]]*interface=" "$config_file" | head -n1 | cut -d'=' -f2 | xargs)
    
    if [[ -z "$interface" ]]; then
        log_error "Интерфейс не найден в конфиге: $config_file"
        echo -e "${RED}Добавьте строку: interface=имя_интерфейса${NC}"
        return 1
    fi
    
    log_debug "Найден интерфейс в конфиге: $interface"
    
    # Проверка существования интерфейса
    if ! ip link show "$interface" &>/dev/null; then
        log_error "Интерфейс $interface не найден"
        echo -e "${RED}Добавьте интерфейс: ip link add dev $interface type dummy${NC}"
        return 1
    fi
    
    log_debug "Интерфейс найден: $interface"
    
    return "$interface"
}

# --- Главное меню ---
network_diagnostic_sub() {
    local module_dir="$SCRIPT_DIR/modules/net"
    local config_file="$DNSMASQ_CONF"

    # Проверяем зависимости
    check_network_diagnostic_dependencies || return 1

    # Автоматически загружаем все модули из директории modules/net
    load_modules "$module_dir" || {
        log_error "Ошибка загрузки модулей диагностики сети"
        return 1
    }

    local MENU_TITLE="Диагностика сети"
    local selected
    local interface

    # Проверяем интерфейс
    interface=$(check_network_interface "$config_file") || return 1

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
                    call_module_function "$selected" "$config_file" "$interface"
                else
                    log_error "Некорректный выбор"
                fi
                ;;
            q) return 0 ;;
            *) log_error "Некорректный выбор" ;;
        esac
        
        echo
        read -n1 -r -s -p "Нажмите любую клавишу для продолжения..."
    done
}