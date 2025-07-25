#!/usr/bin/env bash
# lib.sh — общие функции

# === Цвета ===
NC='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'

# === Загрузка конфига ===
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "$SCRIPT_DIR/config/settings.conf" || {
    echo "FATAL: Не удалось загрузить config/settings.conf"
    exit 1
}

# === Пути ===
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"

LOCKFILE="${LOCKFILE:-/tmp/bash-modular-project.lock}"

# === Уровни логирования ===
LOG_LEVELS=([DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3)

# === Функция логирования ===
log() {
    local level="$1"
    local msg="$2"
    local log_priority=${LOG_LEVELS[$level]:-9}
    local conf_priority=${LOG_LEVELS[$LOG_LEVEL]:-1}

    [[ $log_priority -lt $conf_priority ]] && return

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_file="$LOG_DIR/$(date '+%Y-%m-%d').log"
    local color="$NC"

    case "$level" in
        "ERROR") color="$RED" ;;
        "WARN")  color="$YELLOW" ;;
        "INFO")  color="$GREEN" ;;
        "DEBUG") color="$BLUE" ;;
    esac

    echo -e "${color}[$level] $timestamp — $msg${NC}"
    echo "[$level] $timestamp — $msg" >> "$log_file"
}

log_debug() { log "DEBUG" "$*"; }
log_info()  { log "INFO"  "$*"; }
log_warn()  { log "WARN"  "$*"; }
log_error() { log "ERROR" "$*"; }

# === Очистка старых логов ===
cleanup_logs() {
    log_debug "Очистка логов старше $LOG_RETENTION_DAYS дней"
    find "$LOG_DIR" -name "*.log" -type f -mtime +$LOG_RETENTION_DAYS -delete 2>/dev/null || true
}

# === Обработка сигналов ===
trap_handler() {
    log_warn "Получен сигнал $1. Завершение работы..."
    rm -f "$LOCKFILE"
    exit 1
}

trap 'trap_handler SIGINT'  SIGINT
trap 'trap_handler SIGTERM' SIGTERM
trap 'trap_handler EXIT'    EXIT

# === Проверка блокировки ===
acquire_lock() {
    if [[ -f "$LOCKFILE" ]]; then
        if kill -0 $(cat "$LOCKFILE" 2>/dev/null) 2>/dev/null; then
            log_error "Скрипт уже запущен (PID: $(cat "$LOCKFILE"))."
            exit 1
        else
            log_warn "Старый lockfile найден, но процесс неактивен. Удаляем."
            rm -f "$LOCKFILE"
        fi
    fi
    echo $$ > "$LOCKFILE"
    log_info "Lockfile создан: $LOCKFILE"
}

release_lock() {
    rm -f "$LOCKFILE"
    log_info "Lockfile удалён."
}

# === TUI: диалоговое меню ===
show_menu_dialog() {
    local choices=()
    local i=0
    for item in "${menu_items[@]}"; do
        choices+=("$i" "$item")
        ((i++))
    done
    choices+=("q" "Выход")

    local cmd=(dialog --clear --title "Bash Modular Project" --menu "Выберите действие:" 15 60 5)
    local choice=$("${cmd[@]}" "${choices[@]}" 2>&1 >/dev/tty)

    [[ $? -eq 0 ]] && echo "$choice"
}

show_menu_whiptail() {
    local list=()
    local i=0
    for item in "${menu_items[@]}"; do
        list+=("$i" "$item")
        ((i++))
    done
    list+=("q" "Выход")

    local choice=$(whiptail --title "Bash Modular Project" --menu "Выберите действие:" 15 60 5 "${list[@]}" 3>&1 1>&2 2>&3)

    [[ $? -eq 0 ]] && echo "$choice" || echo "q"
}

# === Вывод текстового меню (fallback) ===
show_menu_text() {
    clear
    echo -e "${PURPLE}╔════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC}     ${BLUE}Bash Modular Project — Главное меню${NC}     ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════╝${NC}"
    echo

    for i in "${!menu_items[@]}"; do
        echo -e "  ${GREEN}[$i]${NC} ${menu_items[$i]}"
    done
    echo -e "  ${RED}[q]${NC} Выход"
    echo
}

# === Печать разделителя ===
print_menu_footer() {
    echo -e "${PURPLE}────────────────────────────────────────────${NC}"
}
