#!/usr/bin/env bash
# === MENU: Настройка TenixWS (Ansible)
# === FUNC: ansible_tenixws_suite

# Автор: Diz A Torr
# Версия: 1.0
# Лицензия: MIT

# Путь к проекту
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." &>/dev/null && pwd)
source "$SCRIPT_DIR/lib.sh" || {
    echo "FATAL: Не удалось загрузить lib.sh"
    exit 1
}

# === Константы ===
ANSIBLE_BASE_DIR="/home/tecon/security"
INVENTORY_FILE="$ANSIBLE_BASE_DIR/hosts"
PLAYBOOKS=(
    "1|Задать пароли и IP для NTP|$ANSIBLE_BASE_DIR/vars.sh"
    "2|Управление DNSMASQ|$ANSIBLE_BASE_DIR/dnsmasq.sh"
    "3|Добавление пользователей|$ANSIBLE_BASE_DIR/add_users2.yml"
    "4|Добавление пароля на GRUB|$ANSIBLE_BASE_DIR/lock_grub.yml"
    "5|Установка Scada V|$ANSIBLE_BASE_DIR/scada_V.yml"
    "6|NTP клиент|$ANSIBLE_BASE_DIR/ntp_client.yml"
    "7|NTP Сервер 1|$ANSIBLE_BASE_DIR/ntp_server1.yml"
    "8|NTP Сервер 2|$ANSIBLE_BASE_DIR/ntp_server2.yml"
    "9|Автовход Operator|$ANSIBLE_BASE_DIR/autologin.yml"
    "10|Сервер Rsyslog|$ANSIBLE_BASE_DIR/rsyslog-server.yml"
    "11|DrWeb сервер|$ANSIBLE_BASE_DIR/dr.web_server.yml"
    "12|DrWeb клиент|$ANSIBLE_BASE_DIR/dr.web_client.yml"
    "13|CyberBackup сервер|$ANSIBLE_BASE_DIR/cyberbackup_server.yml"
    "14|CyberBackup клиент|$ANSIBLE_BASE_DIR/cyberbackup_client.yml"
    "15|Смена пароля Root|$ANSIBLE_BASE_DIR/chang_pass_root.yml"
    "16|Установка ScanerVS5|$ANSIBLE_BASE_DIR/scaner5.yml"
    "17|Настройка сети|$ANSIBLE_BASE_DIR/network.yml"
    "18|Удаленный доступ|$ANSIBLE_BASE_DIR/vnc.yml"
    "19|Устранение проблем|$ANSIBLE_BASE_DIR/fix_vulnerabilities.yml"
    "20|Настройки ФСТЭК|$ANSIBLE_BASE_DIR/fix.yml"
    "21|Установка ScanerVS6 (не актуально)|$ANSIBLE_BASE_DIR/scaner6.yml"
    "22|Установка Audit|$ANSIBLE_BASE_DIR/audit.yml"
    "23|Безопасность уровня Шесхарис|$ANSIBLE_BASE_DIR/advanced_security.yml"
    "24|Настройка Ubuntu 16|$ANSIBLE_BASE_DIR/add_users.yml"
)

# === Проверка зависимостей ===
check_requirements() {
    if ! command -v ansible-playbook &>/dev/null; then
        log_error "Требуется ansible-playbook. Установите: sudo apt install ansible"
        return 1
    fi

    if [[ ! -d "$ANSIBLE_BASE_DIR" ]]; then
        log_error "Папка Ansible не найдена: $ANSIBLE_BASE_DIR"
        return 1
    fi

    if [[ ! -f "$INVENTORY_FILE" ]]; then
        log_warn "Файл инвентаря не найден: $INVENTORY_FILE"
        echo -e "${YELLOW}Продолжить без инвентаря? (y/N)${NC}"
        read -p "Выбор: " confirm
        [[ "$confirm" =~ ^[Yy] ]] || return 1
    fi

    return 0
}

# === Запуск плейбука или скрипта ===
run_item() {
    local name="$1"
    local path="$2"

    log_info "Запуск: $name"

    if [[ "$path" == *.sh ]]; then
        if [[ -x "$path" ]]; then
            log_debug "Запуск скрипта: $path"
            "$path"
        else
            log_error "Скрипт не исполняемый или не существует: $path"
        fi
    elif [[ "$path" == *.yml ]]; then
        if [[ -f "$path" ]]; then
            echo "Запуск плейбука: $path"
            ansible-playbook -i "$INVENTORY_FILE" "$path"
            echo "Плейбук выполнен"
        else
            log_error "Плейбук не найден: $path"
        fi
    else
        log_warn "Неизвестный тип файла: $path"
    fi
}

# === Главное меню ===
ansible_tenixws_suite() {
    log_info "Запуск: Настройка TenixWS (Ansible)"

    if ! check_requirements; then
        echo -e "${RED}Не все зависимости выполнены.${NC}"
        return 1
    fi

    while true; do
        local choices=()
        for item in "${PLAYBOOKS[@]}"; do
            IFS='|' read -r num name path <<< "$item"
            choices+=("$num" "$name")
        done
        choices+=("q" "Выход")

        local choice=""
        case "$USE_TUI" in
            "dialog")
                choice=$(dialog --clear --title "TenixWS" --menu "Выберите действие:" 20 70 10 "${choices[@]}" 3>&1 1>&2 2>&3)
                ;;
            "whiptail")
                choice=$(whiptail --title "TenixWS" --menu "Выберите действие:" 20 70 10 "${choices[@]}" 3>&1 1>&2 2>&3)
                ;;
            *)
                echo -e "${BLUE}=== Настройка TenixWS (Ansible) ===${NC}"
                for item in "${PLAYBOOKS[@]}"; do
                    IFS='|' read -r num name path <<< "$item"
                    echo -e "  ${GREEN}[$num]${NC} $name"
                done
                echo -e "  ${RED}[0]${NC} Выход"
                read -p $'Выберите пункт (0-24): ' choice
                ;;
        esac

        [[ -z "$choice" ]] && continue

        if [[ "$choice" == "0" ]]; then
            log_info "Выход из модуля TenixWS"
            break
        fi

        # Поиск выбранного пункта
        local found=false
        for item in "${PLAYBOOKS[@]}"; do
            IFS='|' read -r num name path <<< "$item"
            if [[ "$choice" == "$num" ]]; then
                run_item "$name" "$path"
                found=true
                break
            fi
        done

        if [[ "$found" == "false" ]]; then
            log_warn "Неверный выбор: $choice"
        fi

        echo
        echo -e "${YELLOW}Нажмите Enter для возврата в меню...${NC}"
        read
        clear
    done
}
