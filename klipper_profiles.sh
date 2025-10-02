#!/bin/bash
set -euo pipefail

# === Проверка зависимостей ===
MISSING_TOOLS=()
for cmd in rsync tar curl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        MISSING_TOOLS+=("$cmd")
    fi
done

if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
    echo "❌ Не найдены следующие утилиты: ${MISSING_TOOLS[*]}"
    echo "Установите их командой:"
    echo "  sudo apt update && sudo apt install ${MISSING_TOOLS[*]}"
    exit 1
fi

# === Автоматическое определение путей ===
CURRENT_USER=${SUDO_USER:-$(whoami)}
POSSIBLE_PATHS=(
    "/home/$CURRENT_USER/printer_data/config"
)

CONFIG_DIR=""
for path in "${POSSIBLE_PATHS[@]}"; do
    if [ -d "$path" ]; then
        CONFIG_DIR="$path"
        echo "Найдена конфигурация: $CONFIG_DIR"
        break
    fi
done

if [ -z "$CONFIG_DIR" ]; then
    echo "Не удалось автоматически найти конфигурацию Klipper."
    echo "Возможные причины:"
    echo "  - Конфигурация находится в нестандартном пути"
    echo "  - Скрипт запущен с правами root"
    echo ""
    read -p "Введите полный путь к папке config: " USER_CONFIG_DIR </dev/tty

    if [ -d "$USER_CONFIG_DIR" ]; then
        CONFIG_DIR="$USER_CONFIG_DIR"
    else
        echo "Ошибка: Папка '$USER_CONFIG_DIR' не существует!"
        exit 1
    fi
fi

# === Вспомогательные функции ===
get_existing_profiles() {
    local profiles=()
    for dir in "$CONFIG_DIR"/printer_*; do
        if [ -d "$dir" ]; then
            profiles+=("$(basename "$dir")")
        fi
    done
    echo "${profiles[@]}"
}

get_active_profile_num() {
    local active_profile_file="$CONFIG_DIR/active_profile"
    if [ -f "$active_profile_file" ]; then
        local profile=$(cat "$active_profile_file" 2>/dev/null || true)
        if [ -n "$profile" ]; then
            local profile_num=${profile#printer_}
            echo "$profile_num"
            return 0
        fi
    fi
    echo "0"  # Нет активного профиля
}

create_backup() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local tmp_backup=$(mktemp --suffix="_klipper_config_backup_${timestamp}.tar.gz")
    local final_backup="$CONFIG_DIR/klipper_config_backup_${timestamp}.tar.gz"
    
    local rsync_excludes=(
        --exclude="printer_*" --exclude="active_profile" 
        --exclude="change_profile.sh" --exclude="change_profile.cfg" 
        --exclude="*.tar.gz"
    )
    
    echo "Создаём резервную копию в $final_backup..."
    
    # Создаем резервную копию с контролем ошибок
    if ! tar -czf "$tmp_backup" \
        "${rsync_excludes[@]}" \
        -C "$(dirname "$CONFIG_DIR")" "$(basename "$CONFIG_DIR")"; then
        echo "❌ Ошибка при создании резервной копии с помощью tar"
        rm -f "$tmp_backup"  # Удаляем временный файл при ошибке
        exit 1
    fi
    
    # Перемещаем архив в конечное место
    if ! mv "$tmp_backup" "$final_backup"; then
        echo "❌ Ошибка при перемещении резервной копии"
        rm -f "$tmp_backup"  # Удаляем временный файл при ошибке
        exit 1
    fi
    
    echo "Резервная копия создана: $final_backup"
}

create_profile() {
    local profile_num=$1
    local profile_name="printer_$profile_num"
    local profile_dir="$CONFIG_DIR/$profile_name"
    
    echo "=== Создаём профиль $profile_name ==="
    
    # Создаем директорию профиля
    if ! mkdir -p "$profile_dir"; then
        echo "❌ Ошибка при создании директории профиля: $profile_dir"
        exit 1
    fi
    
    local rsync_excludes=(
        --exclude="printer_*" --exclude="active_profile" 
        --exclude="change_profile.sh" --exclude="change_profile.cfg" 
        --exclude="*.tar.gz"
    )
    
    # Копируем файлы с контролем ошибок
    if ! rsync -a --delete "${rsync_excludes[@]}" "$CONFIG_DIR/" "$profile_dir/"; then
        echo "❌ Ошибка при копировании файлов в профиль: $profile_dir"
        exit 1
    fi
    
    local profile_cfg="$profile_dir/printer.cfg"
    if [ -f "$profile_cfg" ]; then
        if ! sed -i '/^#Profile_/d' "$profile_cfg"; then
            echo "⚠️  Предупреждение: Ошибка при очистке профильной строки в $profile_cfg"
        fi
        if ! sed -i "1i#Profile_$profile_num" "$profile_cfg"; then
            echo "⚠️  Предупреждение: Ошибка при добавлении профильной строки в $profile_cfg"
        fi
        
        if ! grep -q "^\[include change_profile.cfg\]$" "$profile_cfg"; then
            if ! sed -i '2i[include change_profile.cfg]' "$profile_cfg"; then
                echo "⚠️  Предупреждение: Ошибка при добавлении include в $profile_cfg"
            fi
        fi
    else
        echo "В профиле $profile_name отсутствует printer.cfg!"
    fi
    
    local profile_cfg_file="$CONFIG_DIR/change_profile.cfg"
    if [ -f "$profile_cfg_file" ]; then
        if ! cp "$profile_cfg_file" "$profile_dir/change_profile.cfg"; then
            echo "⚠️  Предупреждение: Ошибка при копировании change_profile.cfg в профиль $profile_name"
        fi
    fi
}

create_change_profile_script() {
    local script_path="$CONFIG_DIR/change_profile.sh"
    local rsync_excludes_str='--exclude="printer_*" --exclude="active_profile" --exclude="change_profile.sh" --exclude="change_profile.cfg" --exclude="*.tar.gz"'
    
    cat > "$script_path" << EOF
#!/bin/bash
set -euo pipefail

CONFIG_DIR="$CONFIG_DIR"
PROFILE="\$1"

if [ -z "\$PROFILE" ]; then
  echo "Укажите профиль: printer_1, printer_2, printer_3, etc."
  exit 1
fi

PROF_DIR="\$CONFIG_DIR/\$PROFILE"
if [ ! -d "\$PROF_DIR" ]; then
  echo "Профиль \$PROFILE не найден!"
  exit 1
fi

ACTIVE_PROFILE_FILE="\$CONFIG_DIR/active_profile"
ACTIVE_PROFILE=\$(cat "\$ACTIVE_PROFILE_FILE" 2>/dev/null || true)

# --- Сохраняем текущий профиль ---
if [ -n "\$ACTIVE_PROFILE" ] && [ -d "\$CONFIG_DIR/\$ACTIVE_PROFILE" ]; then
  echo "Сохраняем изменения текущего профиля \$ACTIVE_PROFILE..."
  rsync -a --delete $rsync_excludes_str "\$CONFIG_DIR/" "\$CONFIG_DIR/\$ACTIVE_PROFILE/"
fi

# --- Загружаем новый профиль ---
echo "Загружаем профиль \$PROFILE..."
rsync -a --delete $rsync_excludes_str "\$PROF_DIR/" "\$CONFIG_DIR/"

echo "\$PROFILE" > "\$ACTIVE_PROFILE_FILE"

# Обновляем printer.cfg
PRINTER_CFG="\$CONFIG_DIR/printer.cfg"
if [ -f "\$PRINTER_CFG" ]; then
  sed -i '/^#Profile_/d' "\$PRINTER_CFG"
  PROFILE_NUM=\${PROFILE#printer_}
  sed -i "1i#Profile_\$PROFILE_NUM" "\$PRINTER_CFG"

  if ! grep -q "^\\[include change_profile.cfg\\]\$" "\$PRINTER_CFG"; then
    sed -i '2i[include change_profile.cfg]' "\$PRINTER_CFG"
  fi
fi

# Обновляем макрос с динамическим названием профиля в change_profile.cfg
CHANGE_PROFILE_CFG="\$CONFIG_DIR/change_profile.cfg"
if [ -f "\$CHANGE_PROFILE_CFG" ]; then
  # Удаляем старую секцию макроса ACTIVE_PROFILE
  sed -i "/^\[gcode_macro ACTIVE_PROFILE\]/,/^\[.*\]/d" "\$CHANGE_PROFILE_CFG"
  
  # Добавляем новую секцию с динамическим названием в конец файла
  echo "" >> "\$CHANGE_PROFILE_CFG"
  echo "[gcode_macro ACTIVE_PROFILE]" >> "\$CHANGE_PROFILE_CFG"
  echo "description: АКТИВНЫЙ ПРОФИЛЬ \$PROFILE_NUM" >> "\$CHANGE_PROFILE_CFG"
  echo "gcode:" >> "\$CHANGE_PROFILE_CFG"
  echo "    RESPOND PREFIX=\"info\" MSG=\"Текущий профиль: \$PROFILE_NUM\"" >> "\$CHANGE_PROFILE_CFG"
fi

echo "Профиль 🟡 \$PROFILE переключается. Ожидайте загрузку (~10 сек)"

if command -v curl >/dev/null 2>&1; then
    curl -s -X POST http://localhost:7125/printer/gcode/script \\
         -H "Content-Type: application/json" \\
         -d "{\\"script\\": \\"M117 🟢 Профиль: \$PROFILE\\"}" >/dev/null && \\
    echo "Статус профиля обновлён в интерфейсе."
fi

(
    sleep 1
    sudo systemctl restart klipper || echo "⚠️ Не удалось перезапустить Klipper, сделайте это вручную."
) >/dev/null 2>&1 &

exit 0
EOF

    # Делаем скрипт исполняемым
    if ! chmod +x "$script_path"; then
        echo "❌ Ошибка при установке прав на выполнение для $script_path"
        exit 1
    fi
    
    echo "Скрипт change_profile.sh создан и стал исполняемым."
}

create_change_profile_config() {
    local cfg_file="$CONFIG_DIR/change_profile.cfg"
    local active_profile_num=$(get_active_profile_num)
    
    cat > "$cfg_file" << EOF
[gcode_shell_command change_profile]
command: $CONFIG_DIR/change_profile.sh
timeout: 10.0
verbose: True
EOF

    # Динамически создаем макросы для всех профилей
    local existing_profiles=($(get_existing_profiles))
    for profile in "${existing_profiles[@]}"; do
        local num=${profile#printer_}
        if [[ $num =~ ^[0-9]+$ ]]; then
            cat >> "$cfg_file" << EOF

[gcode_macro SWITCH_PROFILE_$num]
gcode:
    RUN_SHELL_COMMAND CMD=change_profile PARAMS=printer_$num
    RESPOND PREFIX="info" MSG="Переключение на профиль $num завершено"
    RESTART

[gcode_macro Profile_$num]
description: Переключиться на профиль $num
gcode:
    SWITCH_PROFILE_$num
EOF
        fi
    done
    
    # Добавляем макрос с динамическим названием профиля
    echo "" >> "$cfg_file"
    echo "[gcode_macro ACTIVE_PROFILE]" >> "$cfg_file"
    echo "description: АКТИВНЫЙ ПРОФИЛЬ $active_profile_num" >> "$cfg_file"
    echo "gcode:" >> "$cfg_file"
    echo "    RESPOND PREFIX=\"info\" MSG=\"Текущий профиль: $active_profile_num\"" >> "$cfg_file"
}

activate_profile() {
    local profile_num=$1
    local profile_name="printer_$profile_num"
    local profile_dir="$CONFIG_DIR/$profile_name"
    
    if [ ! -d "$profile_dir" ]; then
        echo "Ошибка: Профиль $profile_name не существует!"
        return 1
    fi
    
    echo "Активируем профиль $profile_name..."
    if ! echo "$profile_name" > "$CONFIG_DIR/active_profile"; then
        echo "❌ Ошибка при записи активного профиля в $CONFIG_DIR/active_profile"
        exit 1
    fi
    
    local rsync_excludes=(
        --exclude="printer_*" --exclude="active_profile" 
        --exclude="change_profile.sh" --exclude="change_profile.cfg" 
        --exclude="*.tar.gz"
    )
    
    # Копируем файлы с контролем ошибок
    if ! rsync -a --delete "${rsync_excludes[@]}" "$profile_dir/" "$CONFIG_DIR/"; then
        echo "❌ Ошибка при активации профили: rsync завершился с ошибкой"
        exit 1
    fi
    
    local printer_cfg="$CONFIG_DIR/printer.cfg"
    if [ -f "$printer_cfg" ]; then
        if ! sed -i '/^#Profile_/d' "$printer_cfg"; then
            echo "⚠️  Предупреждение: Ошибка при очистке профильной строки в $printer_cfg"
        fi
        if ! sed -i "1i#Profile_$profile_num" "$printer_cfg"; then
            echo "⚠️  Предупреждение: Ошибка при добавлении профильной строки в $printer_cfg"
        fi
        if ! grep -q "^\[include change_profile.cfg\]$" "$printer_cfg"; then
            if ! sed -i '2i[include change_profile.cfg]' "$printer_cfg"; then
                echo "⚠️  Предупреждение: Ошибка при добавлении include в $printer_cfg"
            fi
        fi
    fi
    
    # Создаем/обновляем макрос с динамическим названием профиля в change_profile.cfg
    local cfg_file="$CONFIG_DIR/change_profile.cfg"
    if [ -f "$cfg_file" ]; then
        # Удаляем старую секцию макроса ACTIVE_PROFILE
        if ! sed -i "/^\[gcode_macro ACTIVE_PROFILE\]/,/^\[.*\]/d" "$cfg_file"; then
            echo "⚠️  Предупреждение: Ошибка при удалении старого макроса ACTIVE_PROFILE"
        fi
        
        # Добавляем новую секцию с динамическим названием в конец файла
        echo "" >> "$cfg_file"
        echo "[gcode_macro ACTIVE_PROFILE]" >> "$cfg_file"
        echo "description: АКТИВНЫЙ ПРОФИЛЬ $profile_num" >> "$cfg_file"
        echo "gcode:" >> "$cfg_file"
        echo "    RESPOND PREFIX=\"info\" MSG=\"Текущий профиль: $profile_num\"" >> "$cfg_file"
    fi
    
    echo "Профиль $profile_name активирован."
}

delete_all_profiles() {
    echo "⚠️  ВНИМАНИЕ: Все профили будут удалены!"
    echo "Это действие НЕЛЬЗЯ отменить. Все данные в профилях будут потеряны."
    read -p "Для подтверждения введите 'DELETE': " confirmation </dev/tty
    if [ "$confirmation" = "DELETE" ]; then
        local existing_profiles=($(get_existing_profiles))
        for profile in "${existing_profiles[@]}"; do
            if ! rm -rf "$CONFIG_DIR/$profile"; then
                echo "⚠️  Предупреждение: Ошибка при удалении профиля: $profile"
            else
                echo "Удален профиль: $profile"
            fi
        done
        if [ -f "$CONFIG_DIR/active_profile" ]; then
            if ! rm "$CONFIG_DIR/active_profile"; then
                echo "⚠️  Предупреждение: Ошибка при удалении active_profile"
            fi
        fi
        if [ -f "$CONFIG_DIR/change_profile.cfg" ]; then
            if ! rm "$CONFIG_DIR/change_profile.cfg"; then
                echo "⚠️  Предупреждение: Ошибка при удалении change_profile.cfg"
            fi
        fi
        if [ -f "$CONFIG_DIR/change_profile.sh" ]; then
            if ! rm "$CONFIG_DIR/change_profile.sh"; then
                echo "⚠️  Предупреждение: Ошибка при удалении change_profile.sh"
            fi
        fi
        
        # Очищаем printer.cfg от строк профиля и include
        local printer_cfg="$CONFIG_DIR/printer.cfg"
        if [ -f "$printer_cfg" ]; then
            # Удаляем строки с #Profile_
            if ! sed -i '/^#Profile_/d' "$printer_cfg"; then
                echo "⚠️  Предупреждение: Ошибка при очистке профильных строк в $printer_cfg"
            fi
            # Удаляем строку [include change_profile.cfg]
            if ! sed -i '/^\[include change_profile.cfg\]$/d' "$printer_cfg"; then
                echo "⚠️  Предупреждение: Ошибка при удалении include строки в $printer_cfg"
            fi
            echo "Файл printer.cfg очищен от профильных строк и include."
        fi
        
        echo "Все профили удалены."
        echo "Перезапускаем Klipper..."
        sudo systemctl restart klipper || echo "⚠️ Не удалось перезапустить Klipper, сделайте это вручную."
        echo "Klipper перезапущен."
    else
        echo "Удаление отменено."
    fi
}

delete_single_profile() {
    local existing_profiles=($(get_existing_profiles))
    if [ ${#existing_profiles[@]} -eq 0 ]; then
        echo "Нет доступных профилей для удаления."
        return
    fi
    
    echo "Доступные профили для удаления:"
    for i in "${!existing_profiles[@]}"; do
        echo "$((i+1)). ${existing_profiles[$i]}"
    done
    
    read -p "Выберите номер профиля для удаления (1-${#existing_profiles[@]}): " choice </dev/tty
    
    if [[ $choice =~ ^[0-9]+$ ]] && [ $choice -ge 1 ] && [ $choice -le ${#existing_profiles[@]} ]; then
        local profile_to_delete="${existing_profiles[$((choice-1))]}"
        echo "⚠️  ВНИМАНИЕ: Профиль $profile_to_delete будет удален!"
        echo "Это действие НЕЛЬЗЯ отменить."
        read -p "Для подтверждения введите 'DELETE': " confirmation </dev/tty
        if [ "$confirmation" = "DELETE" ]; then
            if ! rm -rf "$CONFIG_DIR/$profile_to_delete"; then
                echo "❌ Ошибка при удалении профиля: $profile_to_delete"
                return 1
            else
                echo "Профиль $profile_to_delete удален."
            fi
            
            # Обновляем active_profile если удаляемый был активным
            local active_profile=$(cat "$CONFIG_DIR/active_profile" 2>/dev/null || true)
            if [ "$active_profile" = "$profile_to_delete" ]; then
                if ! rm "$CONFIG_DIR/active_profile"; then
                    echo "⚠️  Предупреждение: Ошибка при удалении active_profile"
                else
                    echo "Активный профиль сброшен."
                fi
            fi
            
            # Пересоздаем конфиг с макросами
            create_change_profile_config
            
            # Перезапускаем Klipper после удаления профиля
            echo "Перезапускаем Klipper..."
            sudo systemctl restart klipper || echo "⚠️ Не удалось перезапустить Klipper, сделайте это вручную."
            echo "Klipper перезапущен."
        else
            echo "Удаление отменено."
        fi
    else
        echo "Неверный выбор."
    fi
}

# === Основная логика ===
echo "=== Управление профилями Klipper ==="
echo "Пользователь: $CURRENT_USER"
echo "Конфигурация: $CONFIG_DIR"

# Проверяем, есть ли уже профили
existing_profiles=($(get_existing_profiles))

if [ ${#existing_profiles[@]} -eq 0 ]; then
    # Первый запуск - создание профилей
    echo "Обнаружен первый запуск. Создание профилей..."
    
    while true; do
        read -p "Сколько профилей создать? (1-5): " num_profiles </dev/tty
        if [[ $num_profiles =~ ^[1-5]$ ]]; then
            break
        else
            echo "Пожалуйста, введите число от 1 до 5."
        fi
    done
    
    # Создаем резервную копию
    create_backup
    
    # Создаем профили
    for ((i=1; i<=num_profiles; i++)); do
        create_profile $i
    done
    
    # Создаем скрипт и конфиг
    create_change_profile_script
    create_change_profile_config
    
    # Добавляем include в основной printer.cfg
    PRINTER_CFG="$CONFIG_DIR/printer.cfg"
    if [ -f "$PRINTER_CFG" ]; then
        if ! grep -q "^\[include change_profile.cfg\]$" "$PRINTER_CFG"; then
            if ! sed -i '1i[include change_profile.cfg]' "$PRINTER_CFG"; then
                echo "❌ Ошибка при добавлении [include change_profile.cfg] в $PRINTER_CFG"
                exit 1
            else
                echo "Добавлен [include change_profile.cfg] в начало printer.cfg"
            fi
        fi
    else
        echo "Файл printer.cfg не найден в $CONFIG_DIR!"
        exit 1
    fi
    
    # Активируем первый профиль
    activate_profile 1
    
    echo "=== Создание профилей завершено ==="
    echo "Создано $num_profiles профилей."
    echo "Перезапускаем Klipper для загрузки макросов..."
    sudo systemctl restart klipper || echo "⚠️ Не удалось перезапустить Klipper, сделайте это вручную."
    
else
    # Повторный запуск - меню выбора
    echo "Обнаружен повторный запуск. Найдены профили:"
    for profile in "${existing_profiles[@]}"; do
        echo "  - $profile"
    done
    echo ""
    echo "Доступные действия:"
    echo "1. Добавить профиль к имеющимся"
    echo "2. Удалить все профили (кроме основного)"
    echo "3. Удалить один профиль"
    echo "4. Создать архив"
    echo "5. Выйти"
    
    while true; do
        read -p "Выберите действие (1-5): " action </dev/tty
        case $action in
            1)
                # Добавить профиль
                current_count=${#existing_profiles[@]}
                if [ $current_count -ge 5 ]; then
                    echo "Достигнуто максимальное количество профилей (5)."
                else
                    next_num=$((current_count + 1))
                    create_profile $next_num
                    create_change_profile_config  # Обновляем макросы
                    
                    # Обновляем основной printer.cfg
                    PRINTER_CFG="$CONFIG_DIR/printer.cfg"
                    if [ -f "$PRINTER_CFG" ]; then
                        if ! grep -q "^\[include change_profile.cfg\]$" "$PRINTER_CFG"; then
                            if ! sed -i '1i[include change_profile.cfg]' "$PRINTER_CFG"; then
                                echo "⚠️  Предупреждение: Ошибка при добавлении include в $PRINTER_CFG"
                            else
                                echo "Добавлен [include change_profile.cfg] в $PRINTER_CFG"
                            fi
                        fi
                    fi
                    echo "Добавлен профиль printer_$next_num"
                fi
                ;;
            2)
                # Удалить все профили
                delete_all_profiles
                ;;
            3)
                # Удалить один профиль
                delete_single_profile
                ;;
            4)
                # Создать архив
                create_backup
                ;;
            5)
                # Выйти
                echo "Выход."
                exit 0
                ;;
            *)
                echo "Неверный выбор. Пожалуйста, введите число от 1 до 5."
                ;;
        esac
    done
fi
