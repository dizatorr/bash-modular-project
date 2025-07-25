#!/usr/bin/env bash
# === MENU: Пример модуля
# === FUNC: hello_world
#
# === Описание ===
# Простой пример модуля с выводом приветствия.
# Версия: 1.0 (2025-04-05)
# Требует: Нет

hello_world() {
    log_info "Запущен модуль hello_world"
    echo -e "${GREEN}🎉 Привет из модуля!${NC}"
    echo "Это пример расширения Bash Modular Project."
    log_info "Модуль hello_world завершён"
}
