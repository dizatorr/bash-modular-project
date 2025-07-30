#!/usr/bin/env bash
# === MENU: Установка SMB зависимостей
# === FUNC: install_smb_deps
# Автор: Diz A Torr
# Версия: 1.0
# Лицензия: MIT
# Описание: Установка необходимых пакетов для работы с SMB

install_smb_deps() {
    local packages=("samba-common-bin" "cifs-utils")
    local missing_packages=()
    
    clear
    echo -e "${BLUE}=== Проверка зависимостей SMB ===${NC}"
    echo
    
    for package in "${packages[@]}"; do
        if dpkg -l | grep -q "^ii  $package "; then
            echo -e "✓ $package ${GREEN}(установлен)${NC}"
        else
            echo -e "✗ $package ${RED}(не установлен)${NC}"
            missing_packages+=("$package")
        fi
    done
    
    if [[ ${#missing_packages[@]} -gt 0 ]]; then
        echo
        echo -e "${YELLOW}Необходимо установить: ${missing_packages[*]}${NC}"
        read -p "Установить недостающие пакеты? (y/N): " confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            if command -v apt >/dev/null 2>&1; then
                sudo apt update
                sudo apt install -y "${missing_packages[@]}"
                
                if [[ $? -eq 0 ]]; then
                    log_info "Пакеты успешно установлены"
                else
                    log_error "Ошибка установки пакетов"
                fi
            else
                log_error "Менеджер пакетов apt не найден"
            fi
        fi
    else
        log_info "Все зависимости установлены"
    fi
}