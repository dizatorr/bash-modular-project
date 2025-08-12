#!/usr/bin/env bash
# === MENU: Настроить SSH доступ к root
# === FUNC: setup_ssh_root_access
# Автор: Diz A Torr
# Версия: 1.0
# Лицензия: MIT
# Описание: Настройка SSH доступа к учетной записи root на удаленных серверах

setup_ssh_root_access() {
    local hosts_file="$LOG_DIR"/hosts
    
    log_info "Настройка SSH доступа к root..."
    
    # Проверка существования файла hosts
    if [[ ! -f "$hosts_file" ]]; then
        log_error "Файл hosts не найден: $hosts_file"
        return 1
    fi
    
    # Запрос учетных данных
    local username password root_password
    
    read -r -p "Введите имя пользователя: " username
    if [[ -z "$username" ]]; then
        log_error "Имя пользователя не может быть пустым"
        return 1
    fi
    
    read -r -s -p "Введите пароль для пользователя $username: " password
    echo
    if [[ -z "$password" ]]; then
        log_error "Пароль не может быть пустым"
        return 1
    fi
    
    read -r -s -p "Введите пароль для учетной записи root: " root_password
    echo
    if [[ -z "$root_password" ]]; then
        log_error "Пароль root не может быть пустым"
        return 1
    fi
    
    # Проверка наличия необходимых утилит
    if ! command -v sshpass &>/dev/null; then
        log_error "Утилита sshpass не установлена"
        echo -e "${RED}Установите: sudo apt install sshpass${NC}"
        return 1
    fi
    
    # Парсинг файла hosts Ansible для получения списка IP-адресов
    local ip_addresses=()
    mapfile -t ip_addresses < <(awk '/^\[all\]/{flag=1;next} /^\[/{flag=0} flag && NF > 0 {print $1}' "$hosts_file")
    
    if [[ ${#ip_addresses[@]} -eq 0 ]]; then
        log_error "Не найдено IP-адресов в файле hosts"
        return 1
    fi
    
    log_info "Найдено серверов: ${#ip_addresses[@]}"
    
    # Обработка каждого IP-адреса
    local success_count=0
    local failed_hosts=()
    
    for ip_address in "${ip_addresses[@]}"; do
        log_info "Обработка сервера: $ip_address"
        
        # Настройка PermitRootLogin
        if setup_permit_root_login "$ip_address" "$username" "$password" "$root_password"; then
            log_info "✓ Настройка PermitRootLogin на $ip_address выполнена"
        else
            log_error "✗ Не удалось настроить PermitRootLogin на $ip_address"
            failed_hosts+=("$ip_address (PermitRootLogin)")
            continue
        fi
        
        # Копирование SSH-ключа root
        if copy_root_ssh_key "$ip_address" "$username" "$password" "$root_password"; then
            log_info "✓ SSH-ключ скопирован на $ip_address"
            ((success_count++))
        else
            log_error "✗ Не удалось скопировать SSH-ключ на $ip_address"
            failed_hosts+=("$ip_address (SSH-ключ)")
        fi
    done
    
    # Вывод результатов
    log_info "Настройка завершена. Успешно: $success_count из ${#ip_addresses[@]}"
    
    if [[ ${#failed_hosts[@]} -gt 0 ]]; then
        log_warn "Ошибки на следующих серверах:"
        for failed_host in "${failed_hosts[@]}"; do
            log_warn "  - $failed_host"
        done
        return 1
    fi
    
    return 0
}

# Вспомогательная функция для настройки PermitRootLogin
setup_permit_root_login() {
    local ip_address="$1"
    local username="$2"
    local password="$3"
    local root_password="$4"
    
    local ssh_config_file="/etc/ssh/sshd_config"
    
    # Подключение по SSH и изменение параметра
    if echo "$password" | sshpass -p "$password" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$username@$ip_address" "
        echo '$root_password' | sudo -S sed -i 's/[#]*PermitRootLogin.*/PermitRootLogin yes/' $ssh_config_file 2>/dev/null || \
        echo '$root_password' | sudo -S sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' $ssh_config_file 2>/dev/null || \
        echo '$root_password' | sudo -S echo 'PermitRootLogin yes' >> $ssh_config_file
        sudo systemctl restart sshd
    " 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Вспомогательная функция для копирования SSH-ключа root
copy_root_ssh_key() {
    local ip_address="$1"
    local username="$2"
    local password="$3"
    local root_password="$4"
    
    # Копирование SSH-ключа
    if echo "$root_password" | sshpass -p "$password" ssh-copy-id -o StrictHostKeyChecking=no -o ConnectTimeout=10 "root@$ip_address" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Функция для тестирования подключения к root
test_root_ssh_access() {
    local hosts_file="${1:-/home/tecon/security/hosts}"
    
    log_info "Тестирование SSH доступа к root..."
    
    # Парсинг файла hosts
    local ip_addresses=()
    mapfile -t ip_addresses < <(awk '/^\[all\]/{flag=1;next} /^\[/{flag=0} flag && NF > 0 {print $1}' "$hosts_file")
    
    if [[ ${#ip_addresses[@]} -eq 0 ]]; then
        log_error "Не найдено IP-адресов в файле hosts"
        return 1
    fi
    
    local success_count=0
    
    for ip_address in "${ip_addresses[@]}"; do
        log_info "Тестирование $ip_address..."
        
        if ssh -o BatchMode=yes -o ConnectTimeout=5 "root@$ip_address" "echo 'OK'" 2>/dev/null; then
            log_info "✓ Доступ к root на $ip_address: УСПЕШНО"
            ((success_count++))
        else
            log_warn "✗ Доступ к root на $ip_address: ОТСУТСТВУЕТ"
        fi
    done
    
    log_info "Тест завершен. Доступно: $success_count из ${#ip_addresses[@]}"
    return 0
}