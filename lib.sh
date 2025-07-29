# lib.sh — общие функции и универсальное меню

# Цвета
NC='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'

# Определяем директорию скрипта
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

# Загрузка конфига
if [[ ! -f "$SCRIPT_DIR/config/settings.conf" ]]; then
    echo -e "${RED}FATAL: Конфигурационный файл не найден: $SCRIPT_DIR/config/settings.conf${NC}" >&2
    exit 1
fi
source "$SCRIPT_DIR/config/settings.conf" || {
    echo -e "${RED}FATAL: Ошибка загрузки конфигурации${NC}" >&2
    exit 1
}

# Проверка LOG_LEVEL
if [[ -z "$LOG_LEVEL" ]] || [[ -z "${LOG_LEVELS[$LOG_LEVEL]}" ]]; then
    LOG_LEVEL="INFO"
fi

# Пути
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR" || {
    echo -e "${RED}FATAL: Не удалось создать директорию логов: $LOG_DIR${NC}" >&2
    exit 1
}

LOCKFILE="${LOCKFILE:-/tmp/bash-modular-project.lock}"

# Уровни логирования
declare -A LOG_LEVELS=( [DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3 )

# Функция логирования
log() {
    local level="$1" msg="$2" color="$NC"
    local log_priority=${LOG_LEVELS[$level]:-9}
    local conf_priority=${LOG_LEVELS[$LOG_LEVEL]:-1}
    (( log_priority < conf_priority )) && return
    case "$level" in
        "ERROR") color="$RED" ;;
        "WARN")  color="$YELLOW" ;;
        "INFO")  color="$GREEN" ;;
        "DEBUG") color="$BLUE" ;;
    esac
    echo -e "${color}[$level] $(date '+%Y-%m-%d %H:%M:%S') — $msg${NC}" >&2
    echo "[$level] $(date '+%Y-%m-%d %H:%M:%S') — $msg" >> "$LOG_DIR/$(date '+%Y-%m-%d').log"
}

log_debug() { log "DEBUG" "$*"; }
log_info()  { log "INFO"  "$*"; }
log_warn()  { log "WARN"  "$*"; }
log_error() { log "ERROR" "$*"; }

# Очистка старых логов
cleanup_logs() {
    find "$LOG_DIR" -name "*.log" -type f -mtime +${LOG_RETENTION_DAYS:-7} -delete
}

# Обработка сигналов
trap_handler() {
    log_warn "Получен сигнал $1. Завершение работы..."
    rm -f "$LOCKFILE"
    exit 1
}

trap 'trap_handler SIGINT'  SIGINT
trap 'trap_handler SIGTERM' SIGTERM
trap 'trap_handler EXIT'    EXIT

# Проверка блокировки
acquire_lock() {
    if [[ -f "$LOCKFILE" ]] && kill -0 $(cat "$LOCKFILE") 2>/dev/null; then
        log_error "Скрипт уже запущен (PID: $(cat "$LOCKFILE"))."
        exit 1
    fi
    echo $$ > "$LOCKFILE"
}

release_lock() {
    rm -f "$LOCKFILE"
}

# === Меню: отображение и обработка ===
# Универсальная функция показа меню
# Общая функция для отображения меню
show_menu() {
    local choices=()
    local i=0

    # Проверка доступности TUI
    case "$USE_TUI" in
        "dialog") command -v dialog >/dev/null || USE_TUI="text" ;;
        "whiptail") command -v whiptail >/dev/null || USE_TUI="text" ;;
        *) USE_TUI="text" ;;
    esac

    for item in "${menu_items[@]}"; do
        choices+=("$i" "${item%%|*}")
        ((i++))
    done
    choices+=("q" "Выход")

    selected=""

    case "$USE_TUI" in
        "dialog")
            selected=$(dialog --clear --no-cancel --title "$MENU_TITLE" --menu "Выберите действие:" 15 60 5 "${choices[@]}" 2>&1 >/dev/tty)
            echo "${selected:-q}"
            ;;
        "whiptail")
            selected=$(whiptail --title "$MENU_TITLE" --menu "Выберите действие:" 15 60 5 "${choices[@]}" 3>&1 1>&2 2>&3)
            echo "${selected:-q}"
            ;;
        "text")
            show_menu_header "$MENU_TITLE"
            for i in "${!menu_items[@]}"; do
                show_menu_item "$i" "${menu_items[$i]%%|*}"
            done
            show_menu_item "q" "Выход"
            echo
            read -p "Выбор: " selected
            echo "${selected:-q}"
            ;;
    esac
}
# Функция для отображения меню через dialog
show_menu_dialog() {
    show_menu 
}

# Функция для отображения меню через whiptail
show_menu_whiptail() {
    show_menu 
}

# Функция для отображения текстового меню
show_menu_text() {
    show_menu 
}

# Функция для отображения элемента меню
show_menu_item() {
    local index=${1:-"q"}
    local menu_item=${2:-"Выход"}
    if [[ "$index" == "q" ]]; then
        echo -e "  ${RED}[$index]${NC} $menu_item"
    else
        echo -e "  ${GREEN}[$index]${NC} $menu_item"
    fi
}

# Функция для отображения заголовка меню
show_menu_header() {
    clear
    local menu_name=${1:-"Меню"}
    local len_menu=${#menu_name}
    local count=$((len_menu + 14))
    local border=$(printf '═%.0s' $(seq 1 $count))

    echo -e "${PURPLE}╔${border}╗${NC}"
    echo -e "${PURPLE}║${NC}       ${BLUE}${menu_name}${NC}       ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚${border}╝${NC}"
}
