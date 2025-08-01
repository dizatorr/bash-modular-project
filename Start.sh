#!/usr/bin/env bash
# Автор: Diz A Torr
# Версия: 1.0
# Лицензия: MIT
# Описание: Главный скрипт проекта

# === Настройки ===
MENU_TITLE="${MENU_TITLE:-Главное меню}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
readonly LIB_DIR="$SCRIPT_DIR" # Предполагается, что lib.sh и module_loader.sh в той же директории

# === Загрузка библиотек ===
# Загружаем основную библиотеку
source "$LIB_DIR/lib.sh" || {
    log_error "FATAL: Не удалось загрузить lib.sh"
    exit 1
}

# Загружаем универсальную функцию загрузки модулей
source "$LIB_DIR/module_loader.sh" || {
    log_error "Не удалось загрузить module_loader.sh"
    exit 1
}

# === Основной цикл ===
main() {
    local module_dir="$SCRIPT_DIR/modules"
    # Загружаем все модули из директории
    if ! load_modules "$module_dir"; then
        log_error "Не удалось загрузить модули"
        exit 1
    fi
    #sleep 10
    # Основной цикл меню
    while true; do
        show_menu "$MENU_TITLE" "${MENU_ITEMS[@]}"
        
        # Обработка выбора пользователя
        # Если selected не установлена или пуста, Bash выведет сообщение об ошибке и завершит
        case "${selected:?}" in 
            q|Q)
                break
                ;;
            [0-9]*)
                # Проверка ввода
                if (( selected >= 0 )) && (( selected < ${#MENU_ITEMS[@]} )) && (( selected < ${#FUNCTIONS[@]} )); then
                    # Вызываем функцию модуля
                    if ! call_module_function "$selected"; then
                        log_error "Ошибка при выполнении модуля '$selected'"
                    fi
                else
                    log_error "Некорректный выбор: '$selected'"
                fi
                ;;
            *)
                log_error "Некорректный ввод: '$selected'"
                ;;
        esac

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