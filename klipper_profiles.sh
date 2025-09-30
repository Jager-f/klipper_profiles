#!/bin/bash
set -e

# === Настройки ===
CONFIG_DIR="/home/biqu/printer_data/config"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TMP_BACKUP="/tmp/klipper_config_backup_${TIMESTAMP}.tar.gz"
FINAL_BACKUP="$CONFIG_DIR/klipper_config_backup_${TIMESTAMP}.tar.gz"

echo "=== Старт установки профилей Klipper ===" 

# --- Проверка на повторный запуск ---
PROFILE_DIRS_EXIST=false
for i in 1 2 3; do
    if [ -d "$CONFIG_DIR/printer_$i" ]; then
        PROFILE_DIRS_EXIST=true
        break
    fi
done

ACTIVE_PROFILE_EXISTS=false
if [ -f "$CONFIG_DIR/active_profile" ]; then
    ACTIVE_PROFILE_EXISTS=true
fi

if $PROFILE_DIRS_EXIST || $ACTIVE_PROFILE_EXISTS; then
    echo "⚠️  ВНИМАНИЕ: Система профилей уже настроена!"
    echo ""
    echo "Повторный запуск ПЕРЕЗАПИШЕТ все папки профилей (printer_1, printer_2, printer_3)"
    echo "и ВАШИ РУЧНЫЕ ИЗМЕНЕНИЯ В НИХ БУДУТ УТЕРЯНЫ."
    echo ""
    echo "Также будет активирован профиль printer_1, и текущая конфигурация"
    echo "в $CONFIG_DIR будет заменена его содержимым."
    echo ""

    # Читаем с терминала, даже если скрипт запущен через pipe
    read -p "Вы уверены, что хотите продолжить? (y/N): " -n 1 -r </dev/tty
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Установка отменена."
        exit 0
    else
        echo "Продолжаем установку с перезаписью профилей..."
    fi
fi

# --- 1. Резервная копия текущей папки config ---
echo "Создаём временный архив config в $TMP_BACKUP (исключаем архивы и профили)..."
tar -czf "$TMP_BACKUP" \
  --exclude="*.tar.gz" \
  --exclude="printer_1" --exclude="printer_2" --exclude="printer_3" \
  --exclude="active_profile" --exclude="change_profile.sh" --exclude="change_profile.cfg" \
  -C "$(dirname "$CONFIG_DIR")" "$(basename "$CONFIG_DIR")"

mv "$TMP_BACKUP" "$FINAL_BACKUP"
echo "Резервная копия создана: $FINAL_BACKUP"

# --- 2. Создаём change_profile.cfg ---
PROFILE_CFG_FILE="$CONFIG_DIR/change_profile.cfg"
echo "Создаём change_profile.cfg с макросами переключения профилей..."
cat > "$PROFILE_CFG_FILE" << 'EOF'
[gcode_shell_command change_profile]
command: /home/biqu/printer_data/config/change_profile.sh
timeout: 10.0
verbose: True

[gcode_macro SWITCH_PROFILE_1]
gcode:
    RUN_SHELL_COMMAND CMD=change_profile PARAMS=printer_1
    RESPOND PREFIX="info" MSG="Переключение на профиль 1 завершено"
    RESTART

[gcode_macro SWITCH_PROFILE_2]
gcode:
    RUN_SHELL_COMMAND CMD=change_profile PARAMS=printer_2
    RESPOND PREFIX="info" MSG="Переключение на профиль 2 завершено"
    RESTART

[gcode_macro SWITCH_PROFILE_3]
gcode:
    RUN_SHELL_COMMAND CMD=change_profile PARAMS=printer_3
    RESPOND PREFIX="info" MSG="Переключение на профиль 3 завершено"
    RESTART

[gcode_macro Profile_1]
description: Переключиться на профиль 1
gcode:
    SWITCH_PROFILE_1

[gcode_macro Profile_2]
description: Переключиться на профиль 2
gcode:
    SWITCH_PROFILE_2

[gcode_macro Profile_3]
description: Переключиться на профиль 3
gcode:
    SWITCH_PROFILE_3
EOF
echo "Файл change_profile.cfg создан."

# --- 3. Добавляем include change_profile.cfg в основной printer.cfg ---
PRINTER_CFG="$CONFIG_DIR/printer.cfg"
if [ -f "$PRINTER_CFG" ]; then
    if ! grep -q "include change_profile.cfg" "$PRINTER_CFG"; then
        sed -i '1i[include change_profile.cfg]' "$PRINTER_CFG"
        echo "Добавлен [include change_profile.cfg] в начало printer.cfg"
    else
        echo "[include change_profile.cfg] уже присутствует в основном printer.cfg"
    fi
else
    echo "Файл printer.cfg не найден в $CONFIG_DIR!"
    exit 1
fi

# --- 4. Создаём папки профилей и копируем файлы ---
for i in 1 2 3; do
    prof="printer_$i"
    PROF_DIR="$CONFIG_DIR/$prof"
    echo "=== Работа с профилем $prof ==="

    mkdir -p "$PROF_DIR"

    # Копируем с --delete для чистоты
    rsync -a --delete \
          --exclude="printer_1" --exclude="printer_2" --exclude="printer_3" \
          --exclude="active_profile" --exclude="change_profile.sh" \
          --exclude="change_profile.cfg" \
          "$CONFIG_DIR/" "$PROF_DIR/"

    PROF_CFG="$PROF_DIR/printer.cfg"
    if [ -f "$PROF_CFG" ]; then
        sed -i '/^#Profile_/d' "$PROF_CFG"
        sed -i "1i#Profile_$i" "$PROF_CFG"
        echo "Добавлен комментарий #Profile_$i в $PROF_CFG"

        if ! grep -q "include change_profile.cfg" "$PROF_CFG"; then
            sed -i '2i[include change_profile.cfg]' "$PROF_CFG"
            echo "Добавлен [include change_profile.cfg] на 2-ю строку в $PROF_CFG"
        fi
    else
        echo "В профиле $prof отсутствует printer.cfg!"
    fi

    cp "$PROFILE_CFG_FILE" "$PROF_DIR/change_profile.cfg"
    echo "change_profile.cfg скопирован в $PROF_DIR"
done

# --- 5. Создаём скрипт смены профиля ---
CHANGE_SCRIPT="$CONFIG_DIR/change_profile.sh"
echo "Создаём скрипт смены профиля change_profile.sh..."
cat > "$CHANGE_SCRIPT" << 'EOF'
#!/bin/bash
CONFIG_DIR="/home/biqu/printer_data/config"
PROFILE="$1"

if [ -z "$PROFILE" ]; then
  echo "Укажите профиль: printer_1, printer_2 или printer_3"
  exit 1
fi

PROF_DIR="$CONFIG_DIR/$PROFILE"
if [ ! -d "$PROF_DIR" ]; then
  echo "Профиль $PROFILE не найден!"
  exit 1
fi

ACTIVE_PROFILE_FILE="$CONFIG_DIR/active_profile"
ACTIVE_PROFILE=$(cat "$ACTIVE_PROFILE_FILE" 2>/dev/null)

# --- Сохраняем текущий профиль, если он активен и существует ---
if [ -n "$ACTIVE_PROFILE" ] && [ -d "$CONFIG_DIR/$ACTIVE_PROFILE" ]; then
  echo "Сохраняем изменения текущего профиля $ACTIVE_PROFILE..."
  rsync -a --delete \
        --exclude="printer_1" --exclude="printer_2" --exclude="printer_3" \
        --exclude="active_profile" --exclude="change_profile.sh" \
        --exclude="change_profile.cfg" \
        "$CONFIG_DIR/" "$CONFIG_DIR/$ACTIVE_PROFILE/"
fi

# --- Копируем новый профиль в config ---
echo "Загружаем профиль $PROFILE..."
rsync -a --delete \
      --exclude="printer_1" --exclude="printer_2" --exclude="printer_3" \
      --exclude="active_profile" --exclude="change_profile.sh" \
      --exclude="change_profile.cfg" \
      "$PROF_DIR/" "$CONFIG_DIR/"

# Обновляем active_profile
echo "$PROFILE" > "$ACTIVE_PROFILE_FILE"

# Убеждаемся, что в printer.cfg есть правильный заголовок и include
PRINTER_CFG="$CONFIG_DIR/printer.cfg"
if [ -f "$PRINTER_CFG" ]; then
  sed -i '/^#Profile_/d' "$PRINTER_CFG"
  case "$PROFILE" in
    printer_1) NUM=1 ;;
    printer_2) NUM=2 ;;
    printer_3) NUM=3 ;;
    *) NUM=0 ;;
  esac
  if [ "$NUM" -ne 0 ]; then
    sed -i "1i#Profile_$NUM" "$PRINTER_CFG"
  fi

  if ! grep -q "^\[include change_profile.cfg\]$" "$PRINTER_CFG"; then
    sed -i '2i[include change_profile.cfg]' "$PRINTER_CFG"
  fi
fi

echo "Профиль 🟡 $PROFILE переключается. Ожидайте загрузку (~10 сек) "

# --- Отображаем текущий профиль в интерфейсе ---
if command -v curl >/dev/null 2>&1; then
    curl -s -X POST http://localhost:7125/printer/gcode/script \
         -H "Content-Type: application/json" \
         -d "{\"script\": \"M117 🟢 Профиль: $PROFILE\"}" >/dev/null && \
    echo "Статус профиля обновлён в интерфейсе."
else
    echo "curl не найден — не удалось обновить статус в интерфейсе."
fi

# --- Перезапускаем Klipper в фоне, чтобы избежать таймаута ---
echo "Перезапускаем Klipper в фоне...Ожидайте перезагрузку"
(
    sleep 1
    sudo systemctl restart klipper
) >/dev/null 2>&1 &

# Успешно завершаем скрипт — Moonraker получит "OK"
exit 0
EOF

chmod +x "$CHANGE_SCRIPT"
echo "Скрипт change_profile.sh создан и стал исполняемым."

# --- 6. Первичная активация первого профиля ---
echo "Активируем первый профиль printer_1..."

echo "printer_1" > "$CONFIG_DIR/active_profile"

# Используем --delete для чистой инициализации
rsync -a --delete \
      --exclude="printer_1" --exclude="printer_2" --exclude="printer_3" \
      --exclude="active_profile" --exclude="change_profile.sh" \
      --exclude="change_profile.cfg" \
      "$CONFIG_DIR/printer_1/" "$CONFIG_DIR/"

PRINTER_CFG="$CONFIG_DIR/printer.cfg"
if [ -f "$PRINTER_CFG" ]; then
  sed -i '/^#Profile_/d' "$PRINTER_CFG"
  sed -i '1i#Profile_1' "$PRINTER_CFG"
  if ! grep -q "^\[include change_profile.cfg\]$" "$PRINTER_CFG"; then
    sed -i '2i[include change_profile.cfg]' "$PRINTER_CFG"
  fi
fi

echo "Первый профиль printer_1 активирован. Содержимое config обновлено."

echo "=== Установка профилей завершена ==="

echo "Первый профиль активирован. Перезапускаем Klipper для загрузки макросов..."
sudo systemctl restart klipper
