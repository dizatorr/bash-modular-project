#!/usr/bin/env bash
# === MENU: Тестовое меню автомат
# === FUNC: test_menu_auto
# Автор: Diz A Torr
# Версия: 1.0
# Лицензия: MIT


# Заголовок меню
MENU_TITLE="Тестовое меню автомат"
#source "$(dirname "$0")/lib.sh"
menu_items=("Обновить систему|update" "Перезагрузить|reboot")

show_menu
test_menu_auto(){
case "$selected" in
    0) log_info "Запуск обновления..." ;;
    1) log_warn "Перезагрузка..." ;;
    q) log_info "Выход"; exit 0 ;;
    *) log_error "Неизвестный выбор: $choice" ;;
esac
}
