#!/usr/bin/env bash
# === MENU: Пример меню
# === FUNC: example_menu
# Автор: Diz A Torr
# Версия: 1.0
# Лицензия: MIT

example_menu() {
    if ! declare -f log_info > /dev/null; then
        echo "Ошибка: библиотека не загружена" >&2
        return 1
    fi

    local menu_items=("Пункт 1" "Пункт 2" "Пункт 3")
    local MENU_TITLE="Пример меню"

    while true; do
        selected=$(show_submenu "${menu_items[@]}" "$MENU_TITLE")
        [[ "$selected" == "q" ]] && return 0

        case "$selected" in
            0) log_info "Выбран Пункт 1" ;;
            1) log_info "Выбран Пункт 2" ;;
            2) log_info "Выбран Пункт 3" ;;
            *) log_error "Неизвестный выбор: $selected" ;;
        esac

        read -n1 -r -s -p "Нажмите любую клавишу для возврата в меню..."
    done
}

# Вспомогательная функция для вызова show_menu из lib.sh
# show_submenu нужна для удобного и чистого вызова show_menu из библиотеки, 
# когда требуется передать пункты меню и заголовок.
show_submenu() {
    local menu_items=("${@:1:$#-1}")
    local title="${!#}"
    export menu_items MENU_TITLE
    show_menu
}