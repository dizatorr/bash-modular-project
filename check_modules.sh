#!/bin/bash
# Скрипт для проверки модулей на соответствие требованиям

cd /home/dizatorr/проекты/bash-modular-project

for file in $(find modules -name "*.sh"); do
    echo "=== Проверка $file ==="
    
    # Проверяем наличие метаданных
    menu_count=$(grep -c "^# === MENU:" "$file" 2>/dev/null || echo 0)
    func_count=$(grep -c "^# === FUNC:" "$file" 2>/dev/null || echo 0)
    
    if [ "$menu_count" -gt 0 ] && [ "$func_count" -gt 0 ]; then
        echo "✓ Метаданные присутствуют"
        menu_value=$(grep "^# === MENU:" "$file" 2>/dev/null | head -n1 | cut -d ':' -f2- | xargs)
        func_value=$(grep "^# === FUNC:" "$file" 2>/dev/null | head -n1 | cut -d ':' -f2- | xargs)
        echo "  MENU: $menu_value"
        echo "  FUNC: $func_value"
    else
        echo "✗ ОШИБКА: отсутствуют необходимые метаданные"
        if [ "$menu_count" -eq 0 ]; then
            echo "  - Отсутствует метка # === MENU:"
        fi
        if [ "$func_count" -eq 0 ]; then
            echo "  - Отсутствует метка # === FUNC:"
        fi
    fi
    
    echo
done