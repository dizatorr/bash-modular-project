#!/usr/bin/env bash
# === MENU: Приветствие
# === FUNC: greet_user

greet_user() {
    local name
    name=$(dialog --inputbox "Введите имя:" 8 40 "Пользователь" 3>&1 1>&2 2>&3) || {
        log_info "Ввод отменён"
        return
    }
    dialog --msgbox "Привет, $name!" 8 40
}
