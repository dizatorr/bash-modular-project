#!/usr/bin/env bash
# === MENU: Пример меню
# === FUNC: example_menu
# Автор: Diz A Torr
# Версия: 1.0
# Лицензия: MIT
# Описание: Пример меню
#
# === Список функций ===
# - example_menu() - основная функция модуля, демонстрирует работу меню
#
# === Требования ===
# - Внешние зависимости: нет
# - Зависимости от других модулей: show_menu, log_info, log_error (из lib.sh)
# - Права доступа: стандартные
# - Требуемые переменные окружения: нет
#
# === Примеры использования ===
# - вызов example_menu напрямую

example_menu() {
    if ! declare -f log_info > /dev/null; then
        echo "Ошибка: библиотека не загружена" >&2
        return 1
    fi

    local menu_items=("Пункт 1" "Пункт 2" "Пункт 3")
    local MENU_TITLE="Пример меню"
    

    while true; do
        show_menu "$MENU_TITLE" "${menu_items[@]}"

        case "$selected" in
            0) log_info "Выбран Пункт 1" ;;
            1) log_info "Выбран Пункт 2" ;;
            2) log_info "Выбран Пункт 3" ;;
            q) return 0 ;;
            *) log_error "Неизвестный выбор: $selected" ;;
        esac
        
        read -n1 -r -s -p "Нажмите любую клавишу для возврата в меню..."
    done
}
