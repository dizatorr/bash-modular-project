# lib.sh
#!/usr/bin/env bash

# === Общие переменные ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/log"

# === Функции логирования ===
log_debug()   { [[ "$LOG_LEVEL" =~ ^(DEBUG|INFO|WARNING|ERROR|CRITICAL)$ ]] && echo -e "\e[2m[D] $(date '+%H:%M:%S')\e[0m $*" | tee -a "$LOG_DIR/$(date +%F).log" >&2; }
log_info()    { [[ "$LOG_LEVEL" =~ ^(INFO|WARNING|ERROR|CRITICAL)$ ]]     && echo -e "\e[36m[I] $(date '+%H:%M:%S')\e[0m $*" | tee -a "$LOG_DIR/$(date +%F).log" >&2; }
log_warning() { [[ "$LOG_LEVEL" =~ ^(WARNING|ERROR|CRITICAL)$ ]]          && echo -e "\e[33m[W] $(date '+%H:%M:%S')\e[0m $*" | tee -a "$LOG_DIR/$(date +%F).log" >&2; }
log_error()   { [[ "$LOG_LEVEL" =~ ^(ERROR|CRITICAL)$ ]]                  && echo -e "\e[31m[E] $(date '+%H:%M:%S')\e[0m $*" | tee -a "$LOG_DIR/$(date +%F).log" >&2; }
log_critical(){ echo -e "\e[1;31m[C] $(date '+%H:%M:%S') $*\e[0m" | tee -a "$LOG_DIR/$(date +%F).log" >&2; exit 1; }

# === Очистка старых логов ===
cleanup_old_logs() {
    [[ -d "$LOG_DIR" ]] || return 0
    find "$LOG_DIR" -name "*.log" -type f -mtime "+$LOG_RETENTION_DAYS" -delete 2>/dev/null && \
        log_info "Автоочистка: удалены логи старше $LOG_RETENTION_DAYS дней."
}

# === Отображение сообщений (TUI) ===
show_message() {
    local title="$1" msg="$2"
    if command -v dialog >/dev/null 2>&1; then
        dialog --title "$title" --msgbox "$msg" 10 60
    elif command -v whiptail >/dev/null 2>&1; then
        whiptail --title "$title" --msgbox "$msg" 10 60
    else
        echo "=== $title ==="
        echo "$msg"
    fi
}
