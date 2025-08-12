#!/usr/bin/env bash
# === MENU: Диагностика сети 2
# === FUNC: network_diagnostic_sub
# Автор: Diz A Torr
# Версия: 1.0 (субмодульная версия)
# Лицензия: MIT
# Описание: Комплексная диагностика сети с возможностью запуска локального DHCP/DNS

# --- Главное меню ---
network_diagnostic_sub() {
    local module_dir="$SCRIPT_DIR/modules/net"

    # Проверяем зависимости
    local deps=("dnsmasq" "ip" "nmcli" "ping" "nslookup" "ipcalc")
    local missing=()
    local cmd

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

    # Автоматически загружаем все модули из директории modules/net
    load_modules "$module_dir" || {
        log_error "Ошибка загрузки модулей диагностики сети"
        return 1
    }

    local MENU_TITLE="Диагностика сети"
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
                    call_module_function "$selected" "$SCRIPT_DIR/config/diag-dnsmasq.conf"
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