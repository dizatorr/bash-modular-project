#!/usr/bin/env bash
# === MENU: Проверить требования для диагностики
# === FUNC: check_network_prerequisites
# Автор: Diz A Torr
# Версия: 1.0
# Лицензия: MIT
# Описание: Проверка прав root и необходимых зависимостей

check_network_prerequisites() {
    local config_file="$1"
    
    # Проверка прав root
    if [[ $EUID -ne 0 ]]; then
        log_error "Требуются права root"
        echo -e "${RED}Выполните: sudo ./Start.sh${NC}"
        return 1
    fi

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
    
    # Проверяем наличие конфигурационного файла
    if [[ ! -f "$config_file" ]]; then
        log_warn "Конфигурационный файл не найден: $config_file"
        log_info "Будет использована стандартная конфигурация"
    fi
    
    log_info "Все проверки пройдены успешно"
    return 0
}