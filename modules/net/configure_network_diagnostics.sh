#!/usr/bin/env bash
# === MENU: Настроить параметры диагностики
# === FUNC: configure_network_diagnostics
# Автор: Diz A Torr
# Версия: 1.0
# Лицензия: MIT
# Описание: Настройка конфигурационного файла для сетевой диагностики

configure_network_diagnostics() {
    local config_file="${1:-$DNSMASQ_CONF}"

    clear
    echo -e "${BLUE}=== Настройка параметров диагностики ===${NC}"
    echo -e "${YELLOW}Редактирование файла: $config_file${NC}"
    echo
    echo "Формат конфигурации dnsmasq:"
    echo "# Пример конфигурации для диагностики сети"
    echo "interface=eth0"
    echo "bind-interfaces"
    echo "dhcp-range=192.168.1.100,192.168.1.200,12h"
    echo "listen-address=192.168.1.1"
    echo "dhcp-option=3,192.168.1.1"
    echo "dhcp-option=6,192.168.1.1"
    echo "log-queries"
    echo "log-dhcp"
    echo

    # Создаем конфиг если его нет
    if [[ ! -f "$config_file" ]]; then
        mkdir -p "$(dirname "$config_file")"
        cat > "$config_file" << 'EOF'
# Конфигурационный файл для сетевой диагностики (dnsmasq)
# Раскомментируйте и измените параметры под свою сеть

# Интерфейс для работы (обязательно измените на ваш)
# interface=eth0

# Привязка только к указанному интерфейсу
# bind-interfaces

# Диапазон DHCP (начало, конец, время аренды)
# dhcp-range=192.168.1.100,192.168.1.200,12h

# IP-адрес сервера (обычно IP интерфейса)
# listen-address=192.168.1.1

# Шлюз по умолчанию для клиентов
# dhcp-option=3,192.168.1.1

# DNS-серверы для клиентов
# dhcp-option=6,192.168.1.1,8.8.8.8

# Логирование запросов
log-queries
log-dhcp
EOF
        log_info "Создан файл конфигурации: $config_file"
    fi

    # Выбираем редактор
    local editors=("nano" "vim" "vi" "gedit")
    local editor=""
    local ed

    for ed in "${editors[@]}"; do
        if command -v "$ed" &>/dev/null; then
            editor="$ed"
            break
        fi
    done

    if [[ -n "$editor" ]]; then
        $editor "$config_file"
    else
        echo "Доступные редакторы не найдены. Откройте файл вручную:"
        echo "$config_file"
        echo
        echo "=== Текущее содержимое ==="
        cat "$config_file"
        echo "========================"
        read -p "Нажмите Enter после редактирования файла..."
    fi
}