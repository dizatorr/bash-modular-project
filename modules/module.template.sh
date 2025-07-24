#!/usr/bin/env bash
# === MENU: Пример модуля
# === FUNC: example_module_main

[[ -z "$PROJECT_ROOT" ]] && { echo "Ошибка: запуск вне контекста проекта"; exit 1; }

example_module_main() {
    log_info "Запуск примера"
    dialog --msgbox "Привет!" 8 40 2>/dev/null || echo "Привет!"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    source "$PROJECT_ROOT/lib.sh" || exit 1
    example_module_main
fi
