# start.sh
#!/usr/bin/env bash

# Защита от source
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    echo "Ошибка: запускайте через ./start.sh" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_FILE="$SCRIPT_DIR/lib.sh"
CONFIG_FILE="$SCRIPT_DIR/config/settings.conf"

# Проверка lib.sh
if [[ ! -f "$LIB_FILE" ]]; then
    echo "FATAL: Не найден lib.sh" >&2
    exit 1
fi
source "$LIB_FILE" || exit 1

# Загрузка конфига
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE" || log_critical "Не найден settings.conf"

# Блокировка
LOCK_FILE="${LOCK_FILE:-/tmp/dizatorr_project.lock}"
acquire_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        if kill -0 "$(cat "$LOCK_FILE" 2>/dev/null)" 2>/dev/null; then
            log_warning "Проект уже запущен (PID: $(cat "$LOCK_FILE"))."
            exit 0
        else
            rm -f "$LOCK_FILE"
        fi
    fi
    echo $$ > "$LOCK_FILE"
}
release_lock() { [[ -f "$LOCK_FILE" ]] && rm -f "$LOCK_FILE"; }

# Обработка сигналов
trap 'log_info "Прервано (Ctrl+C)."; release_lock; exit 0' INT
trap 'log_info "Получен SIGTERM."; release_lock; exit 0' TERM
trap 'release_lock' EXIT

# Проверка зависимостей
check_deps() {
    local missing=()
    command -v dialog >/dev/null || missing+=("dialog")
    command -v whiptail >/dev/null || missing+=("whiptail")
    (( ${#missing[@]} > 0 )) && log_warning "TUI-инструменты не найдены: ${missing[*]}"
    (( BASH_VERSINFO[0] < 4 )) && log_critical "Требуется Bash >= 4.0"
}

# Главное меню
main() {
    acquire_lock
    log_info "Запуск Bash Modular Project v0.1"
    check_deps
    cleanup_old_logs

    local mod_dir="$SCRIPT_DIR/modules"
    [[ ! -d "$mod_dir" ]] && log_critical "Нет папки modules/"

    local -a scripts=() menu_items=() func_names=()

    while IFS= read -r -d '' file; do
        local menu=$(grep -m1 '^# === MENU:' "$file" | cut -d: -f2- | xargs)
        local func=$(grep -m1 '^# === FUNC:' "$file" | cut -d: -f2- | xargs)
        if [[ -n "$menu" && -n "$func" ]]; then
            scripts+=("$file")
            menu_items+=("$menu")
            func_names+=("$func")
        fi
    done < <(find "$mod_dir" -name "*.sh" -type f -executable -print0 2>/dev/null)

    (( ${#menu_items[@]} == 0 )) && {
        log_warning "Модули не найдены в $mod_dir"
        show_message "Внимание" "Добавьте .sh файлы в папку modules/ и сделайте их исполняемыми (chmod +x)"
        exit 0
    }

    # Формируем меню
    local -a items=()
    for i in "${!menu_items[@]}"; do
        items+=("$((i+1))" "${menu_items[i]}")
    done

    local choice
    if command -v dialog >/dev/null; then
        choice=$(dialog --clear --backtitle "Bash Modular Project" \
            --menu "Выберите модуль:" 15 60 10 "${items[@]}" 3>&1 1>&2 2>&3)
    elif command -v whiptail >/dev/null; then
        choice=$(whiptail --clear --backtitle "Bash Modular Project" \
            --menu "Выберите модуль:" 15 60 10 "${items[@]}" 3>&1 1>&2 2>&3)
    else
        log_critical "Нет dialog/whiptail. Установите: sudo apt install dialog"
    fi

    [[ -z "$choice" ]] && { log_info "Выход без выбора."; exit 0; }

    local idx=$((choice - 1))
    if (( idx >= 0 && idx < ${#scripts[@]} )); then
        source "${scripts[idx]}" && "${func_names[idx]}"
    else
        log_error "Неверный выбор: $choice"
    fi
}

main "$@"
