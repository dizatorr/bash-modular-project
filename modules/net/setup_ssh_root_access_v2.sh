#!/usr/bin/env bash
# === MENU: Настроить SSH доступ к root v2
# === FUNC: setup_ssh_root_access_v2
# Автор: Diz A Torr
# Версия: 1.1
# Лицензия: MIT
# Описание: Настройка SSH доступа к учетной записи root на удаленных серверах

# Функция для получения списка IP-адресов из файла hosts
get_ip_addresses() {
    local hosts_file="$1"
    local ip_list=()
    mapfile -t ip_list < <(awk '/^\[all\]/{flag=1;next} /^\[/{flag=0} flag && NF > 0 {print $1}' "$hosts_file")
    echo "${ip_list[@]}"
}

# Вспомогательная функция для настройки PermitRootLogin
setup_permit_root_login() {
    local ip_address="$1"
    local username="$2"
    local password="$3"
    local root_password="$4"

    if echo "$password" | sshpass -p "$password" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$username@$ip_address" "
        echo '$root_password' | sudo -S sed -i 's/[#]*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config || \
        echo '$root_password' | sudo -S sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config || \
        echo 'PermitRootLogin yes' | sudo tee -a /etc/ssh/sshd_config > /dev/null
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
    local password="$2"
    
    if echo "$password" | sshpass -p "$password" ssh-copy-id -o StrictHostKeyChecking=no -o ConnectTimeout=10 "root@$ip_address" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Функция для тестирования подключения к root
test_root_ssh_access() {
    local hosts_file="${1:-/home/tecon/security/hosts}"
    
    echo "Тестирование SSH доступа к root..."
    
    local ip_addresses=($(get_ip_addresses "$hosts_file"))
    
    if [[ ${#ip_addresses[@]} -eq 0 ]]; then
        echo "Ошибка: Не найдено IP-адресов в файле hosts"
        return 1
    fi
    
    local success_count=0
    
    for ip_address in "${ip_addresses[@]}"; do
        echo "Тестирование $ip_address..."
        
        if ssh -o BatchMode=yes -o ConnectTimeout=5 "root@$ip_address" "echo 'OK'" 2>/dev/null; then
            echo "✓ Доступ к root на $ip_address: УСПЕШНО"
            ((success_count++))
        else
            echo "✗ Доступ к root на $ip_address: ОТСУТСТВУЕТ"
        fi
    done
    
    echo "Тест завершен. Доступно: $success_count из ${#ip_addresses[@]}"
    return 0
}

# Основная функция настройки SSH доступа к root
setup_ssh_root_access() {
    local hosts_file="$LOG_DIR"/hosts
    
    echo "Настройка SSH доступа к root..."
    
    if [[ ! -f "$hosts_file" ]]; then
        echo "Ошибка: Файл hosts не найден: $hosts_file"
        return 1
    fi
    
    read -r -p "Введите имя пользователя: " username
    if [[ -z "$username" ]]; then
        echo "Ошибка: Имя пользователя не может быть пустым"
        return 1
    fi
    
    read -r -s -p "Введите пароль для пользователя $username: " password
    echo
    if [[ -z "$password" ]]; then
        echo "Ошибка: Пароль не может быть пустым"
        return 1
    fi
    
    read -r -s -p "Введите пароль для учетной записи root: " root_password
    echo
    if [[ -z "$root_password" ]]; then
        echo "Ошибка: Пароль root не может быть пустым"
        return 1
    fi
    
    if ! command -v sshpass &>/dev/null; then
        echo "Ошибка: Утилита sshpass не установлена"
        echo "Установите: sudo apt install sshpass"
        return 1
    fi
    
    local ip_addresses=($(get_ip_addresses "$hosts_file"))
    
    if [[ ${#ip_addresses[@]} -eq 0 ]]; then
        echo "Ошибка: Не найдено IP-адресов в файле hosts"
        return 1
    fi
    
    echo "Найдено серверов: ${#ip_addresses[@]}"
    
    local success_count=0
    local failed_hosts=()
    
    for ip_address in "${ip_addresses[@]}"; do
        echo "Обработка сервера: $ip_address"
        
        if setup_permit_root_login "$ip_address" "$username" "$password" "$root_password"; then
            echo "✓ Настройка PermitRootLogin на $ip_address выполнена"
        else
            echo "✗ Не удалось настроить PermitRootLogin на $ip_address"
            failed_hosts+=("$ip_address (PermitRootLogin)")
            continue
        fi
        
        if copy_root_ssh_key "$ip_address" "$root_password"; then
            echo "✓ SSH-ключ скопирован на $ip_address"
            ((success_count++))
        else
            echo "✗ Не удалось скопировать SSH-ключ на $ip_address"
            failed_hosts+=("$ip_address (SSH-ключ)")
        fi
    done
    
    echo "Настройка завершена. Успешно: $success_count из ${#ip_addresses[@]}"
    
    if [[ ${#failed_hosts[@]} -gt 0 ]]; then
        echo "Ошибки на следующих серверах:"
        for failed_host in "${failed_hosts[@]}"; do
            echo "  - $failed_host"
        done
        return 1
    fi
    
    return 0
}