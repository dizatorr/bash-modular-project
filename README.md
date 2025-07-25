# Bash Modular Project

[![[bdfcfccc88537ba7e3983e56c026575f_MD5.svg]]](LICENSE)
[![[e03929e48e341eacd827657a2693c609_MD5.svg]]](https://www.gnu.org/software/bash/)

**Bash Modular Project** — модульная система на базе Bash для создания расширяемых консольных приложений с TUI (текстовым интерфейсом). Идеально подходит для системных утилит, автоматизации и администрирования.

> ✅ Просто. Надёжно. Расширяемо.

---

## 🔧 Возможности

- ✅ **Модульность**: добавляй новые функции — просто положи `.sh` в `modules/`, после выполнения модуля переход в главное меню. Наиболее часто используемые функции вынесены в lib.sh в корне
- ✅ **TUI-интерфейс**: красивое меню через `dialog` или `whiptail`
- ✅ **Логирование**: цветной вывод + файлы по дням, есть возможность в конфиге установить уровень логирования
- ✅ **Безопасность**: защита от двойного запуска, обработка сигналов
- ✅ **Автоочистка**: старые логи удаляются автоматически

---

## 📦 Установка

```bash
git clone https://github.com/dizatorr/bash-modular-project.git
cd bash-modular-project
chmod +x start.sh modules/*.sh
```

🚀 Запуск
```bash
./start.sh
```

🧩 Добавление модуля
Создай файл в modules/:
```bash
touch modules/mytool.sh
```

Добавь содержимое:
```bash
# === MENU: Моя утилита
# === FUNC: my_function
#
# === Описание ===
# [Описание]
# Версия: [номер] [дата]
# Требует: [требования]
my_function() {
    echo "Привет из модуля!"
}
```
Сделай исполняемым:
```bash
chmod +x modules/mytool.sh
```

Запусти ./start.sh — и выбери новый пункт!
⚙️ Настройки
Редактируй config/settings.conf:
```bash
LOG_LEVEL="INFO"                # Уровень логирования
LOG_RETENTION_DAYS=30           # Хранить логи (в днях)
```

🧪 Тестирование (GitHub Actions)
Проект автоматически тестируется при каждом коммите.

📞 Поддержка
📧 Email: dizatorr@gmail.com
📁 GitHub: github.com/dizatorr/bash-modular-project

📜 Лицензия
MIT © Diz A Torr
