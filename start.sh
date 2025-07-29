#!/usr/bin/env bash

# === Настройки ===
MENU_TITLE="${MENU_TITLE:-Главное меню}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
MODULE_DIR="$SCRIPT_DIR/modules"

# === Загрузка библиотеки ===
source "$SCRIPT_DIR/lib.sh" || {
    echo "FATAL: Не удалось загрузить lib.sh" >&2
    exit 1
}

# === Проверка модулей ===
[[ ! -d "$MODULE_DIR" ]] && {
    log_error "Папка модулей не найдена: $MODULE_DIR"
    exit 1
}

# === Сбор модулей ===
scripts=()
menu_items=()
function_names=()

for file in "$MODULE_DIR"/*.sh; do
    [[ -f "$file" ]] || continue

    menu=$(grep '^# === MENU:' "$file" | head -n1 | cut -d':' -f2- | xargs)
    func=$(grep '^# === FUNC:' "$file" | head -n1 | cut -d':' -f2- | xargs)

    [[ -n "$menu" && -n "$func" ]] && {
        scripts+=("$file")
        menu_items+=("$menu")
        function_names+=("$func")
    }
done

[[ ${#scripts[@]} -eq 0 ]] && {
    log_error "Нет доступных модулей в '$MODULE_DIR'."
    echo "Пожалуйста, добавьте .sh-модули в папку modules/."
    exit 1
}

# === Основной цикл ===
main() {
    while true; do
        show_menu
        [[ "$selected" == "q" ]] && break

        # Проверка ввода
        if ! [[ "$selected" =~ ^[0-9]+$ ]] || (( selected >= ${#scripts[@]} )); then
            log_warn "Некорректный выбор: '$selected'"
            echo -e "${RED}Ошибка: введите корректный номер.${NC}"
            read -n1 -r -s -p "Нажмите любую клавишу..."
            continue
        fi

        local script_path="${scripts[$selected]}"
        local func_name="${function_names[$selected]}"

        log_info "Запуск: $script_path [$func_name]"

        # Загрузка и выполнение модуля
        { [[ -f "$script_path" && -r "$script_path" ]] && source "$script_path"; } || {
            log_error "Не удалось загрузить: $script_path"
            read -n1 -r -s -p "Нажмите любую клавишу..."
            continue
        }

        if declare -f "$func_name" > /dev/null; then
            "$func_name" && log_info "Успешно: $func_name" || log_error "Ошибка: $func_name"
        else
            log_error "Функция не найдена: $func_name"
        fi

        echo
        read -n1 -r -s -p "Нажмите любую клавишу для возврата в меню..."
    done

    log_info "Работа завершена по выбору пользователя."
}

# === Запуск ===
acquire_lock
cleanup_logs
main
release_lock
log_info "Выход."
