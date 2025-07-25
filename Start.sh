#!/usr/bin/env bash
# start.sh — точка входа

# === Загрузка библиотеки ===
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "$SCRIPT_DIR/lib.sh" || {
    echo "FATAL: Не удалось загрузить lib.sh"
    exit 1
}

# === Путь к модулям ===
MODULE_DIR="$SCRIPT_DIR/modules"
if [[ ! -d "$MODULE_DIR" ]]; then
    log_error "Папка модулей '$MODULE_DIR' не найдена!"
    exit 1
fi

# === Проверка TUI утилит ===
check_tui() {
    case "$USE_TUI" in
        "dialog") command -v dialog >/dev/null || USE_TUI="text" ;;
        "whiptail") command -v whiptail >/dev/null || USE_TUI="text" ;;
        *) USE_TUI="text" ;;
    esac
}

# === Сбор модулей ===
scripts=()
menu_items=()
function_names=()

for file in "$MODULE_DIR"/*.sh; do
    [[ -x "$file" ]] || continue

    menu=$(grep '^# === MENU:' "$file" | head -n1 | cut -d':' -f2- | xargs)
    func=$(grep '^# === FUNC:' "$file" | head -n1 | cut -d':' -f2- | xargs)

    if [[ -n "$menu" && -n "$func" ]]; then
        scripts+=("$file")
        menu_items+=("$menu")
        function_names+=("$func")
    fi
done

if [[ ${#scripts[@]} -eq 0 ]]; then
    log_error "Нет доступных модулей в '$MODULE_DIR'."
    echo "Пожалуйста, добавьте модули в папку modules/."
    exit 1
fi

# === Главная функция запуска ===
main() {
    acquire_lock
    cleanup_logs
    check_tui

    log_info "Проект запущен. Доступно модулей: ${#scripts[@]}"

    while true; do
        local choice=""

        case "$USE_TUI" in
            "dialog")
                choice=$(show_menu_dialog)
                ;;
            "whiptail")
                choice=$(show_menu_whiptail)
                ;;
            *)
                show_menu_text
                read -p $'Выберите номер или '\''q'\'' для выхода: ' choice
                ;;
        esac

        if [[ "$choice" == "q" ]]; then
            log_info "Завершение работы по выбору пользователя."
            break
        elif [[ "$choice" =~ ^[0-9]+$ && $choice -lt ${#scripts[@]} ]]; then
            local script="${scripts[$choice]}"
            local func="${function_names[$choice]}"

            log_info "Запуск модуля: $func из $(basename "$script")"

            # Выполняем модуль
            source "$script"
            if declare -f "$func" >/dev/null; then
                "$func"
            else
                log_error "Функция '$func' не найдена в '$script'"
                echo -e "${RED}Ошибка: функция недоступна.${NC}"
            fi

            echo -e "${YELLOW}Нажмите Enter для возврата в меню...${NC}"
            read
        else
            log_warn "Некорректный ввод: '$choice'"
            echo -e "${RED}Неверный выбор.${NC}"
            sleep 1
        fi
    done

    release_lock
    log_info "Работа завершена."
}

# === Запуск ===
main "$@"
