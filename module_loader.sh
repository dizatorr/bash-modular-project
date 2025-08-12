#!/usr/bin/env bash
# Утилита загрузки модулей
# Автор: Diz A Torr
# Версия: 1.0
# Лицензия: MIT
# Описание: Универсальная функция для автоматической загрузки модулей из указанной директории

# Глобальные массивы для хранения информации о загруженных модулях
# Эти переменные будут заполнены после вызова load_modules
SCRIPTS=()       # Пути к файлам модулей
MENU_ITEMS=()    # Элементы меню (извлекаются из файлов)
FUNCTIONS=()     # Имена функций (извлекаются из файлов)

# --- Универсальная функция загрузки модулей ---
# Аргументы:
#   $1 - путь к директории с модулями
# Возвращает:
#   0 - успех
#   1 - ошибка
load_modules() {
    local module_dir="$1"
    
    # Проверка аргументов
    if [[ -z "$module_dir" ]]; then
        log_error "Не указана директория модулей"
        return 1
    fi
    
    # Проверяем существование директории
    if [[ ! -d "$module_dir" ]]; then
        log_error "Директория модулей не найдена: $module_dir"
        return 1
    fi
    
    # Очищаем глобальные массивы перед новой загрузкой
    save_module_var

    SCRIPTS=()
    MENU_ITEMS=()
    FUNCTIONS=()
    
    local file menu_item func_name
    local loaded_count=0
    local failed_modules=()
    
    # Проходим по всем .sh файлам в директории модулей
    for file in "$module_dir"/*.sh; do
        # Пропускаем, если файл не существует (например, если нет *.sh файлов)
        [[ -f "$file" ]] || continue
        
        # Извлекаем метаданные из комментариев в файле
        menu_item=$(grep '^# === MENU:' "$file" | head -n1 | cut -d':' -f2- | xargs)
        func_name=$(grep '^# === FUNC:' "$file" | head -n1 | cut -d':' -f2- | xargs)
        
        # Проверяем, что оба параметра извлечены
        if [[ -n "$menu_item" && -n "$func_name" ]]; then
            # Подключаем файл
            # shellcheck source=/dev/null
            if source "$file"; then
                # Добавляем в глобальные массивы
                SCRIPTS+=("$file")
                MENU_ITEMS+=("$menu_item")
                FUNCTIONS+=("$func_name")
                
                ((loaded_count++))
                log_debug "Загружен модуль: $file (Функция: $func_name)"
            else
                log_error "Ошибка загрузки модуля: $file"
                failed_modules+=("$file")
            fi
        else
            log_warn "Файл $file не содержит корректных метаданных (# === MENU: и # === FUNC:)"
            failed_modules+=("$file")
        fi
    done
    
    # Выводим результаты
    if [[ ${#failed_modules[@]} -gt 0 ]]; then
        log_warn "Не удалось загрузить модулей: ${#failed_modules[@]} из $(($loaded_count + ${#failed_modules[@]}))"
    fi
    
    log_info "Успешно загружено модулей из $module_dir: $loaded_count"
    
    # Возвращаем ошибку, если ни один модуль не загрузился, но файлы были найдены
    if [[ $loaded_count -eq 0 && $(ls "$module_dir"/*.sh 2>/dev/null | wc -l) -gt 0 ]]; then
        log_error "Не удалось загрузить ни один модуль из $module_dir"
        return 1
    fi
    
    return 0
}

# --- Функция для вызова функции модуля по индексу ---
# Аргументы:
#   $1 - индекс функции (0-based)
#   $@ - дополнительные аргументы для передачи в функцию модуля
call_module_function() {
    local index="$1"
    shift # Убираем первый аргумент (индекс)
    
    # Проверяем индекс
    if [[ ! "$index" =~ ^[0-9]+$ ]] || (( index < 0 )) || (( index >= ${#FUNCTIONS[@]} )); then
        log_error "Некорректный индекс функции: $index"
        return 1
    fi
    
    local func_name="${FUNCTIONS[index]}"
    
    # Проверяем наличие функции
    if ! declare -f "$func_name" >/dev/null; then
        log_error "Функция '$func_name' не найдена"
        return 1
    fi
    
    # Вызываем функцию с переданными аргументами
    "$func_name" "$@"
}

# Сохраняем старые переменные SCRIPTS=() MENU_ITEMS=() FUNCTIONS=()  
save_module_var() {
    if [[ -n "${MENU_ITEMS:-}" ]]; then
        TEMP_SCRIPTS=("${SCRIPTS[@]}")
        TEMP_MENU_ITEMS=("${MENU_ITEMS[@]}")
        TEMP_FUNCTIONS=("${FUNCTIONS[@]}")
    fi
}

load_module_var() {
    # Восстанавливаем переменные
    SCRIPTS=("${TEMP_SCRIPTS[@]}")
    unset TEMP_SCRIPTS    
    MENU_ITEMS=("${TEMP_MENU_ITEMS[@]}")
    unset TEMP_MENU_ITEMS
    FUNCTIONS=("${TEMP_FUNCTIONS[@]}")
    unset TEMP_FUNCTIONS
}