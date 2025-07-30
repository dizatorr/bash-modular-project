# lib.sh — общие функции и универсальное меню
# Автор: Diz A Torr
# Версия: 1.0
# Лицензия: MIT
# Описание: Библиотека с общими функциями и универсальным меню

# === Цвета ===
NC='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'

# === Конфигурация ===
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
CONFIG_FILE="$SCRIPT_DIR/config/settings.conf"
LOCKFILE="${LOCKFILE:-/tmp/bash-modular-project.lock}"
LOG_DIR="$SCRIPT_DIR/logs"

# === Инициализация ===

# Проверка наличия конфига
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${RED}FATAL: Конфигурационный файл не найден: $CONFIG_FILE${NC}" >&2
    exit 1
fi
source "$CONFIG_FILE" || {
    echo -e "${RED}FATAL: Ошибка загрузки конфигурации${NC}" >&2
    exit 1
}

# Проверка уровня логирования
if [[ -z "$LOG_LEVEL" ]] || [[ -z "${LOG_LEVELS[$LOG_LEVEL]}" ]]; then
    LOG_LEVEL="INFO"
fi

# Создание директории логов
mkdir -p "$LOG_DIR" || {
    echo -e "${RED}FATAL: Не удалось создать директорию логов: $LOG_DIR${NC}" >&2
    exit 1
}

# Инициализация уровней логирования
declare -A LOG_LEVELS=( [DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3 )

# Установка обработчиков сигналов
trap 'trap_handler SIGINT'  SIGINT
trap 'trap_handler SIGTERM' SIGTERM
trap 'trap_handler EXIT'    EXIT


# === Логирование ===
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

# === Управление блокировками ===
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

trap_handler() {
    log_warn "Получен сигнал $1. Завершение работы..."
    release_lock
    exit 1
}

# === Очистка старых логов ===
cleanup_logs() {
    find "$LOG_DIR" -name "*.log" -type f -mtime +${LOG_RETENTION_DAYS:-7} -delete
}

# === Меню ===
determine_tui() {
    if [[ "$USE_TUI" == "dialog" ]] && command -v dialog >/dev/null; then
        return 0
    elif [[ "$USE_TUI" == "whiptail" ]] && command -v whiptail >/dev/null; then
        return 0
    else
        USE_TUI="text"
        return 0
    fi
}

show_menu_item() {
    local index=${1:-"q"}
    local menu_item=${2:-"Выход"}
    if [[ "$index" == "q" ]]; then
        echo -e "  ${RED}[$index]${NC} $menu_item"
    else
        echo -e "  ${GREEN}[$index]${NC} $menu_item"
    fi
}

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

show_menu() {
    local menu_title=${1:-$MENU_TITLE}  # Заголовок меню
    local menu_items=("${@:2}") # Массив с пунктами меню
    local choices=()
    local i=0

    determine_tui

    for item in "${menu_items[@]}"; do
        choices+=("$i" "${item%%|*}")
        ((i++))
    done
    choices+=("q" "Выход")

    selected=""

    case "$USE_TUI" in
        "dialog")
            selected=$(dialog --clear --no-cancel --title "$menu_title" --menu "Выберите действие:" 15 60 5 "${choices[@]}" 2>&1 >/dev/tty)
            ;;
        "whiptail")
            selected=$(whiptail --title "$menu_title" --menu "Выберите действие:" 15 60 5 "${choices[@]}" 3>&1 1>&2 2>&3)
            ;;
        "text")
            show_menu_header "$menu_title"
            for i in "${!menu_items[@]}"; do
                show_menu_item "$i" "${menu_items[$i]%%|*}"
            done
            show_menu_item "q" "Выход"
            echo
            read -p "Выбор: " selected
            ;;
    esac

    echo "${selected:-q}"
}

