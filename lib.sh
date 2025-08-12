# shellcheck disable=SC2148
# ==============================================================================
# lib.sh — общие функции и универсальное меню
# Автор: Diz A Torr
# Версия: 1.0
# Лицензия: MIT
# Описание: Библиотека с общими функциями и универсальным меню
# ==============================================================================

# ------------------------------------------------------------------------------
# Константы цветов
# ------------------------------------------------------------------------------
readonly NC='\033[0m'
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'

# ------------------------------------------------------------------------------
# Глобальные переменные конфигурации
# ------------------------------------------------------------------------------
readonly SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
readonly CONFIG_FILE="$SCRIPT_DIR/config/settings.conf"
readonly LOCAL_CONFIG_FILE="$SCRIPT_DIR/config/local.conf"
readonly LOCKFILE="${LOCKFILE:-/tmp/bash-modular-project.lock}"
readonly LOG_DIR="$SCRIPT_DIR/logs"
readonly DNSMASQ_CONF="$SCRIPT_DIR/config/diag-dnsmasq.conf"

# Проверка наличия конфига (файла)
# $1 - путь к файлу конфигурации
# $2 - флаг обязательности файла (true/false)
# $3 - флаг загрузки файла (true/false)
load_config() {
    local config_file="$1"
    local required="${2:-true}"
    local load_file="${3:-true}"
    local mesage=""
    
    if [[ ! -f "$config_file" ]]; then
        if [[ "$required" == "true" ]]; then
            log_error "Конфигурационный файл не найден: $config_file"
            exit 1
        else
            log_warn "Опциональный конфигурационный файл не найден: $config_file"
            return 1
        fi
    fi
    
    if [[ ! -r "$config_file" ]]; then
        log_error "Нет прав на чтение файла: $config_file"
        exit 1
    fi
    
    if [[ "$load_file" == "true" ]]; then
        # shellcheck disable=SC1090
        if ! source "$config_file"; then
            log_error "Ошибка загрузки конфигурационного файла: $config_file"
            exit 1
        fi
        log_info "Загружен конфигурационный файл: $config_file"
    else
        log_info "Проверен конфигурационный файл: $config_file"
    fi
    
    return 0
}

load_config "$CONFIG_FILE"
load_config "$LOCAL_CONFIG_FILE" false  # Опциональный файл
load_config "$DNSMASQ_CONF" false false 


# Проверка уровня логирования
if [[ -z "$LOG_LEVEL" ]] || [[ -z "${LOG_LEVELS[$LOG_LEVEL]}" ]]; then
    LOG_LEVEL="INFO"
fi

# Создание директории логов
mkdir -p "$LOG_DIR" || {
    log_error "Не удалось создать директорию логов: $LOG_DIR"
    exit 1
}

# Инициализация уровней логирования
declare -A LOG_LEVELS=( [DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3 )

# Установка обработчиков сигналов
trap 'trap_handler SIGINT'  SIGINT
trap 'trap_handler SIGTERM' SIGTERM
trap 'trap_handler EXIT'    EXIT


# ------------------------------------------------------------------------------
# Система логирования
# ------------------------------------------------------------------------------
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

    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Вывод в stderr с цветами
    echo -e "${color}[$level] $timestamp — $msg$NC" >&2
    
    # Запись в лог-файл без цветов
    printf "[%s] %s — %s\n" \
        "$level" \
        "$timestamp" \
        "$msg" >> "$LOG_DIR/$(date '+%Y-%m-%d').log"
}

log_debug() { log "DEBUG" "$*"; }
log_info()  { log "INFO"  "$*"; }
log_warn()  { log "WARN"  "$*"; }
log_error() { log "ERROR" "$*"; }


# ------------------------------------------------------------------------------
# Управление блокировками
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# Управление логами
# ------------------------------------------------------------------------------
cleanup_logs() {
    find "$LOG_DIR" -name "*.log" -type f -mtime +${LOG_RETENTION_DAYS:-7} -delete
}

# ------------------------------------------------------------------------------
# Система меню
# ------------------------------------------------------------------------------
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
            read -r -p "Выбор: " selected
            ;;
    esac

    echo "${selected:-q}"
}

