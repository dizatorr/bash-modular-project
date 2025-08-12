#!/usr/bin/env bash
# === MENU: Текущая загрузка интерфейса
# === FUNC: network_load_current
# Автор: Diz A Torr
# Версия: 1.0
# Лицензия: MIT
# Описание: Анализ текущей загрузки сетевого интерфейса с помощью iftop

network_load_current() {
    local interface="${1:-$DNSMASQ_CONF}"
    
    if command -v iftop &> /dev/null; then
        echo -e "${BLUE}Запуск iftop для интерфейса $interface${NC}"
        echo -e "${YELLOW}Нажмите 'q' для выхода из iftop${NC}"
        echo -e "${YELLOW}Используйте стрелки для навигации${NC}"
        read -p "Нажмите Enter для продолжения..."
        sudo iftop -i "$interface"
    else
        echo -e "${YELLOW}iftop не установлен. Установка...${NC}"
        if command -v apt &> /dev/null; then
            sudo apt update && sudo apt install -y iftop
        elif command -v yum &> /dev/null; then
            sudo yum install -y iftop
        elif command -v pacman &> /dev/null; then
            sudo pacman -S iftop
        else
            echo -e "${RED}Не удалось определить менеджер пакетов${NC}"
            return 1
        fi
        
        if command -v iftop &> /dev/null; then
            echo -e "${BLUE}Запуск iftop для интерфейса $interface${NC}"
            sudo iftop -i "$interface"
        else
            echo -e "${RED}Не удалось установить iftop${NC}"
        fi
    fi
}