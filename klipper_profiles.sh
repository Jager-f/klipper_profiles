#!/bin/bash
set -euo pipefail

# === Language Selection ===
echo "Choose language / Выберите язык:"
echo "1 - Russian / Русский"
echo "2 - English / Английский"
read -p "Your choice / Ваш выбор (1/2): " lang_choice </dev/tty

if [ "$lang_choice" = "1" ]; then
    LANGUAGE="RU"
elif [ "$lang_choice" = "2" ]; then
    LANGUAGE="EN"
else
    echo "Invalid choice. Defaulting to Russian. / Неверный выбор. По умолчанию Русский."
    LANGUAGE="RU"
fi

# === Define Messages ===
declare -A MSG

if [ "$LANGUAGE" = "RU" ]; then
    MSG=(
        [missing_tools]="❌ Не найдены следующие утилиты:"
        [install_cmd]="Установите их командой:"
        [found_config]="Найдена конфигурация:"
        [no_auto_config]="Не удалось автоматически найти конфигурацию Klipper."
        [possible_reasons]="Возможные причины:"
        [non_standard_path]="  - Конфигурация находится в нестандартном пути"
        [root_run]="  - Скрипт запущен с правами root"
        [enter_config_path]="Введите полный путь к папке config:"
        [dir_not_exist]="Ошибка: Папка не существует!"
        [creating_backup]="Создаём резервную копию в"
        [backup_error_tar]="❌ Ошибка при создании резервной копии с помощью tar"
        [backup_error_mv]="❌ Ошибка при перемещении резервной копии"
        [backup_created]="Резервная копия создана:"
        [creating_profile]="=== Создаём профиль"
        [mkdir_error]="❌ Ошибка при создании директории профиля:"
        [rsync_error_copy]="❌ Ошибка при копировании файлов в профиль:"
        [sed_clear_error]="⚠️  Предупреждение: Ошибка при очистке профильной строки в"
        [sed_add_error]="⚠️  Предупреждение: Ошибка при добавлении профильной строки в"
        [sed_include_error]="⚠️  Предупреждение: Ошибка при добавлении include в"
        [no_printer_cfg]="В профиле отсутствует printer.cfg!"
        [cp_cfg_error]="⚠️  Предупреждение: Ошибка при копировании change_profile.cfg в профиль"
        [script_created]="Скрипт change_profile.sh создан и стал исполняемым."
        [activating_profile]="Активируем профиль"
        [profile_not_exist]="Ошибка: Профиль не существует!"
        [write_active_error]="❌ Ошибка при записи активного профиля в"
        [rsync_error_activate]="❌ Ошибка при активации профиля: rsync завершился с ошибкой"
        [profile_activated]="Профиль активирован."
        [delete_warning]="⚠️  ВНИМАНИЕ: Все профили будут удалены!"
        [delete_irreversible]="Это действие НЕЛЬЗЯ отменить. Все данные в профилях будут потеряны."
        [confirm_delete]="Для подтверждения введите 'DELETE':"
        [deleted_profile]="Удален профиль:"
        [delete_error]="⚠️  Предупреждение: Ошибка при удалении профиля:"
        [delete_active_error]="⚠️  Предупреждение: Ошибка при удалении active_profile"
        [delete_cfg_error]="⚠️  Предупреждение: Ошибка при удалении change_profile.cfg"
        [delete_sh_error]="⚠️  Предупреждение: Ошибка при удалении change_profile.sh"
        [printer_cfg_cleared]="Файл printer.cfg очищен от профильных строк и include."
        [all_deleted]="Все профили удалены."
        [restarting_klipper]="Перезапускаем Klipper..."
        [restart_failed]="⚠️ Не удалось перезапустить Klipper, сделайте это вручную."
        [klipper_restarted]="Klipper перезапущен."
        [delete_canceled]="Удаление отменено."
        [no_profiles_delete]="Нет доступных профилей для удаления."
        [available_profiles]="Доступные профили для удаления:"
        [choose_delete]="Выберите номер профиля для удаления"
        [invalid_choice]="Неверный выбор."
        [single_delete_warning]="⚠️  ВНИМАНИЕ: Профиль будет удален!"
        [single_delete_error]="❌ Ошибка при удалении профиля:"
        [single_deleted]="Профиль удален."
        [active_reset]="Активный профиль сброшен."
        [management_title]="=== Управление профилями Klipper ==="
        [user]="Пользователь:"
        [config]="Конфигурация:"
        [first_run]="Обнаружен первый запуск. Создание профилей..."
        [how_many_profiles]="Сколько профилей создать? (1-5):"
        [invalid_num]="Пожалуйста, введите число от 1 до 5."
        [include_added]="Добавлен [include change_profile.cfg] в начало printer.cfg"
        [no_printer_cfg_main]="Файл printer.cfg не найден в"
        [creation_complete]="=== Создание профилей завершено ==="
        [profiles_created]="Создано профилей."
        [restarting_for_macros]="Перезапускаем Klipper для загрузки макросов..."
        [repeat_run]="Обнаружен повторный запуск. Найдены профили:"
        [available_actions]="Доступные действия:"
        [add_profile]="1. Добавить профиль к имеющимся"
        [delete_all]="2. Удалить все профили (кроме основного)"
        [delete_one]="3. Удалить один профиль"
        [create_archive]="4. Создать архив"
        [exit]="5. Выйти"
        [choose_action]="Выберите действие (1-5):"
        [max_profiles]="Достигнуто максимальное количество профилей (5)."
        [profile_added]="Добавлен профиль"
        [exit_msg]="Выход."
        [change_sh_no_profile]="Укажите профиль: printer_1, printer_2, printer_3, etc."
        [change_sh_not_found]="Профиль не найден!"
        [change_sh_saving]="Сохраняем изменения текущего профиля"
        [change_sh_loading]="Загружаем профиль"
        [change_sh_switching]="Профиль 🟡 переключается. Ожидайте загрузку (~10 сек)"
        [change_sh_status_updated]="Статус профиля обновлён в интерфейсе."
        [change_cfg_macro_desc]="АКТИВНЫЙ ПРОФИЛЬ"
        [change_cfg_macro_msg]="Текущий профиль:"
        [change_cfg_switch_desc]="Переключиться на профиль"
        [change_cfg_switch_msg]="Переключение на профиль завершено"
        [chmod_error]="❌ Ошибка при установке прав на выполнение для"
        [sed_include_warning]="⚠️  Предупреждение: Ошибка при добавлении include в"
        [sed_clear_warning]="⚠️  Предупреждение: Ошибка при очистке профильных строк в"
        [sed_delete_include_warning]="⚠️  Предупреждение: Ошибка при удалении include строки в"
        [sed_delete_old_macro_warning]="⚠️  Предупреждение: Ошибка при удалении старого макроса ACTIVE_PROFILE"
    )
else
    MSG=(
        [missing_tools]="❌ The following utilities not found:"
        [install_cmd]="Install them with the command:"
        [found_config]="Found configuration:"
        [no_auto_config]="Failed to automatically find Klipper configuration."
        [possible_reasons]="Possible reasons:"
        [non_standard_path]="  - Configuration is in a non-standard path"
        [root_run]="  - Script run with root privileges"
        [enter_config_path]="Enter full path to config folder:"
        [dir_not_exist]="Error: Folder does not exist!"
        [creating_backup]="Creating backup in"
        [backup_error_tar]="❌ Error creating backup with tar"
        [backup_error_mv]="❌ Error moving backup"
        [backup_created]="Backup created:"
        [creating_profile]="=== Creating profile"
        [mkdir_error]="❌ Error creating profile directory:"
        [rsync_error_copy]="❌ Error copying files to profile:"
        [sed_clear_error]="⚠️  Warning: Error clearing profile line in"
        [sed_add_error]="⚠️  Warning: Error adding profile line in"
        [sed_include_error]="⚠️  Warning: Error adding include in"
        [no_printer_cfg]="Profile missing printer.cfg!"
        [cp_cfg_error]="⚠️  Warning: Error copying change_profile.cfg to profile"
        [script_created]="Script change_profile.sh created and made executable."
        [activating_profile]="Activating profile"
        [profile_not_exist]="Error: Profile does not exist!"
        [write_active_error]="❌ Error writing active profile to"
        [rsync_error_activate]="❌ Error activating profile: rsync failed"
        [profile_activated]="Profile activated."
        [delete_warning]="⚠️  WARNING: All profiles will be deleted!"
        [delete_irreversible]="This action CANNOT be undone. All data in profiles will be lost."
        [confirm_delete]="To confirm, enter 'DELETE':"
        [deleted_profile]="Deleted profile:"
        [delete_error]="⚠️  Warning: Error deleting profile:"
        [delete_active_error]="⚠️  Warning: Error deleting active_profile"
        [delete_cfg_error]="⚠️  Warning: Error deleting change_profile.cfg"
        [delete_sh_error]="⚠️  Warning: Error deleting change_profile.sh"
        [printer_cfg_cleared]="File printer.cfg cleared of profile lines and include."
        [all_deleted]="All profiles deleted."
        [restarting_klipper]="Restarting Klipper..."
        [restart_failed]="⚠️ Failed to restart Klipper, do it manually."
        [klipper_restarted]="Klipper restarted."
        [delete_canceled]="Deletion canceled."
        [no_profiles_delete]="No available profiles to delete."
        [available_profiles]="Available profiles for deletion:"
        [choose_delete]="Choose profile number to delete"
        [invalid_choice]="Invalid choice."
        [single_delete_warning]="⚠️  WARNING: Profile will be deleted!"
        [single_delete_error]="❌ Error deleting profile:"
        [single_deleted]="Profile deleted."
        [active_reset]="Active profile reset."
        [management_title]="=== Klipper Profile Management ==="
        [user]="User:"
        [config]="Configuration:"
        [first_run]="Detected first run. Creating profiles..."
        [how_many_profiles]="How many profiles to create? (1-5):"
        [invalid_num]="Please enter a number from 1 to 5."
        [include_added]="Added [include change_profile.cfg] to the beginning of printer.cfg"
        [no_printer_cfg_main]="File printer.cfg not found in"
        [creation_complete]="=== Profile creation completed ==="
        [profiles_created]="Created profiles."
        [restarting_for_macros]="Restarting Klipper to load macros..."
        [repeat_run]="Detected repeat run. Found profiles:"
        [available_actions]="Available actions:"
        [add_profile]="1. Add profile to existing"
        [delete_all]="2. Delete all profiles (except main)"
        [delete_one]="3. Delete one profile"
        [create_archive]="4. Create archive"
        [exit]="5. Exit"
        [choose_action]="Choose action (1-5):"
        [max_profiles]="Maximum number of profiles reached (5)."
        [profile_added]="Added profile"
        [exit_msg]="Exiting."
        [change_sh_no_profile]="Specify profile: printer_1, printer_2, printer_3, etc."
        [change_sh_not_found]="Profile not found!"
        [change_sh_saving]="Saving changes to current profile"
        [change_sh_loading]="Loading profile"
        [change_sh_switching]="Profile 🟡 switching. Wait for loading (~10 sec)"
        [change_sh_status_updated]="Profile status updated in interface."
        [change_cfg_macro_desc]="ACTIVE PROFILE"
        [change_cfg_macro_msg]="Current profile:"
        [change_cfg_switch_desc]="Switch to profile"
        [change_cfg_switch_msg]="Switching to profile completed"
        [chmod_error]="❌ Error setting execute permissions for"
        [sed_include_warning]="⚠️  Warning: Error adding include to"
        [sed_clear_warning]="⚠️  Warning: Error clearing profile lines in"
        [sed_delete_include_warning]="⚠️  Warning: Error deleting include line in"
        [sed_delete_old_macro_warning]="⚠️  Warning: Error deleting old ACTIVE_PROFILE macro"
    )
fi

# === Проверка зависимостей / Dependency Check ===
MISSING_TOOLS=()
for cmd in rsync tar curl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        MISSING_TOOLS+=("$cmd")
    fi
done

if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
    echo "${MSG[missing_tools]} ${MISSING_TOOLS[*]}"
    echo "${MSG[install_cmd]}"
    echo "  sudo apt update && sudo apt install ${MISSING_TOOLS[*]}"
    exit 1
fi

# === Автоматическое определение путей / Auto Path Detection ===
CURRENT_USER=${SUDO_USER:-$(whoami)}
POSSIBLE_PATHS=(
    "/home/$CURRENT_USER/printer_data/config"
)

CONFIG_DIR=""
for path in "${POSSIBLE_PATHS[@]}"; do
    if [ -d "$path" ]; then
        CONFIG_DIR="$path"
        echo "${MSG[found_config]} $CONFIG_DIR"
        break
    fi
done

if [ -z "$CONFIG_DIR" ]; then
    echo "${MSG[no_auto_config]}"
    echo "${MSG[possible_reasons]}"
    echo "${MSG[non_standard_path]}"
    echo "${MSG[root_run]}"
    echo ""
    read -p "${MSG[enter_config_path]} " USER_CONFIG_DIR </dev/tty

    if [ -d "$USER_CONFIG_DIR" ]; then
        CONFIG_DIR="$USER_CONFIG_DIR"
    else
        echo "${MSG[dir_not_exist]} '$USER_CONFIG_DIR'"
        exit 1
    fi
fi

# === Вспомогательные функции / Helper Functions ===
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
    echo "0"  # Нет активного профиля / No active profile
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
    
    echo "${MSG[creating_backup]} $final_backup..."
    
    # Создаем резервную копию с контролем ошибок / Create backup with error control
    if ! tar -czf "$tmp_backup" \
        "${rsync_excludes[@]}" \
        -C "$(dirname "$CONFIG_DIR")" "$(basename "$CONFIG_DIR")"; then
        echo "${MSG[backup_error_tar]}"
        rm -f "$tmp_backup"  # Удаляем временный файл при ошибке / Delete temp file on error
        exit 1
    fi
    
    # Перемещаем архив в конечное место / Move archive to final location
    if ! mv "$tmp_backup" "$final_backup"; then
        echo "${MSG[backup_error_mv]}"
        rm -f "$tmp_backup"  # Удаляем временный файл при ошибке / Delete temp file on error
        exit 1
    fi
    
    echo "${MSG[backup_created]} $final_backup"
}

create_profile() {
    local profile_num=$1
    local profile_name="printer_$profile_num"
    local profile_dir="$CONFIG_DIR/$profile_name"
    
    echo "${MSG[creating_profile]} $profile_name ==="
    
    # Создаем директорию профиля / Create profile directory
    if ! mkdir -p "$profile_dir"; then
        echo "${MSG[mkdir_error]} $profile_dir"
        exit 1
    fi
    
    local rsync_excludes=(
        --exclude="printer_*" --exclude="active_profile" 
        --exclude="change_profile.sh" --exclude="change_profile.cfg" 
        --exclude="*.tar.gz"
    )
    
    # Копируем файлы с контролем ошибок / Copy files with error control
    if ! rsync -a --delete "${rsync_excludes[@]}" "$CONFIG_DIR/" "$profile_dir/"; then
        echo "${MSG[rsync_error_copy]} $profile_dir"
        exit 1
    fi
    
    local profile_cfg="$profile_dir/printer.cfg"
    if [ -f "$profile_cfg" ]; then
        if ! sed -i '/^#Profile_/d' "$profile_cfg"; then
            echo "${MSG[sed_clear_error]} $profile_cfg"
        fi
        if ! sed -i "1i#Profile_$profile_num" "$profile_cfg"; then
            echo "${MSG[sed_add_error]} $profile_cfg"
        fi
        
        if ! grep -q "^\[include change_profile.cfg\]$" "$profile_cfg"; then
            if ! sed -i '2i[include change_profile.cfg]' "$profile_cfg"; then
                echo "${MSG[sed_include_error]} $profile_cfg"
            fi
        fi
    else
        echo "${MSG[no_printer_cfg]} $profile_name"
    fi
    
    local profile_cfg_file="$CONFIG_DIR/change_profile.cfg"
    if [ -f "$profile_cfg_file" ]; then
        if ! cp "$profile_cfg_file" "$profile_dir/change_profile.cfg"; then
            echo "${MSG[cp_cfg_error]} $profile_name"
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
  echo "${MSG[change_sh_no_profile]}"
  exit 1
fi

PROF_DIR="\$CONFIG_DIR/\$PROFILE"
if [ ! -d "\$PROF_DIR" ]; then
  echo "${MSG[change_sh_not_found]} \$PROFILE"
  exit 1
fi

ACTIVE_PROFILE_FILE="\$CONFIG_DIR/active_profile"
ACTIVE_PROFILE=\$(cat "\$ACTIVE_PROFILE_FILE" 2>/dev/null || true)

# --- Сохраняем текущий профиль / Save current profile ---
if [ -n "\$ACTIVE_PROFILE" ] && [ -d "\$CONFIG_DIR/\$ACTIVE_PROFILE" ]; then
  echo "${MSG[change_sh_saving]} \$ACTIVE_PROFILE..."
  rsync -a --delete $rsync_excludes_str "\$CONFIG_DIR/" "\$CONFIG_DIR/\$ACTIVE_PROFILE/"
fi

# --- Загружаем новый профиль / Load new profile ---
echo "${MSG[change_sh_loading]} \$PROFILE..."
rsync -a --delete $rsync_excludes_str "\$PROF_DIR/" "\$CONFIG_DIR/"

echo "\$PROFILE" > "\$ACTIVE_PROFILE_FILE"

# Обновляем printer.cfg / Update printer.cfg
PRINTER_CFG="\$CONFIG_DIR/printer.cfg"
if [ -f "\$PRINTER_CFG" ]; then
  sed -i '/^#Profile_/d' "\$PRINTER_CFG"
  PROFILE_NUM=\${PROFILE#printer_}
  sed -i "1i#Profile_\$PROFILE_NUM" "\$PRINTER_CFG"

  if ! grep -q "^\\[include change_profile.cfg\\]\$" "\$PRINTER_CFG"; then
    sed -i '2i[include change_profile.cfg]' "\$PRINTER_CFG"
  fi
fi

# Обновляем макрос с динамическим названием профиля в change_profile.cfg / Update macro with dynamic profile name
CHANGE_PROFILE_CFG="\$CONFIG_DIR/change_profile.cfg"
if [ -f "\$CHANGE_PROFILE_CFG" ]; then
  # Удаляем старую секцию макроса ACTIVE_PROFILE / Delete old ACTIVE_PROFILE macro section
  sed -i "/^\[gcode_macro ACTIVE_PROFILE\]/,/^\[.*\]/d" "\$CHANGE_PROFILE_CFG"
  
  # Добавляем новую секцию с динамическим названием в конец файла / Add new section with dynamic name at the end
  echo "" >> "\$CHANGE_PROFILE_CFG"
  echo "[gcode_macro ACTIVE_PROFILE]" >> "\$CHANGE_PROFILE_CFG"
  echo "description: ${MSG[change_cfg_macro_desc]} \$PROFILE_NUM" >> "\$CHANGE_PROFILE_CFG"
  echo "gcode:" >> "\$CHANGE_PROFILE_CFG"
  echo "    RESPOND PREFIX=\"info\" MSG=\"${MSG[change_cfg_macro_msg]} \$PROFILE_NUM\"" >> "\$CHANGE_PROFILE_CFG"
fi

echo "${MSG[change_sh_switching]} \$PROFILE"

if command -v curl >/dev/null 2>&1; then
    curl -s -X POST http://localhost:7125/printer/gcode/script \\
         -H "Content-Type: application/json" \\
         -d "{\\"script\\": \\"M117 🟢 Profile: \$PROFILE\\"}" >/dev/null && \\
    echo "${MSG[change_sh_status_updated]}"
fi

(
    sleep 1
    sudo systemctl restart klipper || echo "${MSG[restart_failed]}"
) >/dev/null 2>&1 &

exit 0
EOF

    # Делаем скрипт исполняемым / Make script executable
    if ! chmod +x "$script_path"; then
        echo "${MSG[chmod_error]} $script_path"
        exit 1
    fi
    
    echo "${MSG[script_created]}"
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

    # Динамически создаем макросы для всех профилей / Dynamically create macros for all profiles
    local existing_profiles=($(get_existing_profiles))
    for profile in "${existing_profiles[@]}"; do
        local num=${profile#printer_}
        if [[ $num =~ ^[0-9]+$ ]]; then
            cat >> "$cfg_file" << EOF

[gcode_macro SWITCH_PROFILE_$num]
gcode:
    RUN_SHELL_COMMAND CMD=change_profile PARAMS=printer_$num
    RESPOND PREFIX="info" MSG="${MSG[change_cfg_switch_msg]} $num"
    RESTART

[gcode_macro Profile_$num]
description: ${MSG[change_cfg_switch_desc]} $num
gcode:
    SWITCH_PROFILE_$num
EOF
        fi
    done
    
    # Добавляем макрос с динамическим названием профиля / Add macro with dynamic profile name
    echo "" >> "$cfg_file"
    echo "[gcode_macro ACTIVE_PROFILE]" >> "$cfg_file"
    echo "description: ${MSG[change_cfg_macro_desc]} $active_profile_num" >> "$cfg_file"
    echo "gcode:" >> "$cfg_file"
    echo "    RESPOND PREFIX=\"info\" MSG=\"${MSG[change_cfg_macro_msg]} $active_profile_num\"" >> "$cfg_file"
}

activate_profile() {
    local profile_num=$1
    local profile_name="printer_$profile_num"
    local profile_dir="$CONFIG_DIR/$profile_name"
    
    if [ ! -d "$profile_dir" ]; then
        echo "${MSG[profile_not_exist]} $profile_name"
        return 1
    fi
    
    echo "${MSG[activating_profile]} $profile_name..."
    if ! echo "$profile_name" > "$CONFIG_DIR/active_profile"; then
        echo "${MSG[write_active_error]} $CONFIG_DIR/active_profile"
        exit 1
    fi
    
    local rsync_excludes=(
        --exclude="printer_*" --exclude="active_profile" 
        --exclude="change_profile.sh" --exclude="change_profile.cfg" 
        --exclude="*.tar.gz"
    )
    
    # Копируем файлы с контролем ошибок / Copy files with error control
    if ! rsync -a --delete "${rsync_excludes[@]}" "$profile_dir/" "$CONFIG_DIR/"; then
        echo "${MSG[rsync_error_activate]}"
        exit 1
    fi
    
    local printer_cfg="$CONFIG_DIR/printer.cfg"
    if [ -f "$printer_cfg" ]; then
        if ! sed -i '/^#Profile_/d' "$printer_cfg"; then
            echo "${MSG[sed_clear_error]} $printer_cfg"
        fi
        if ! sed -i "1i#Profile_$profile_num" "$printer_cfg"; then
            echo "${MSG[sed_add_error]} $printer_cfg"
        fi
        if ! grep -q "^\[include change_profile.cfg\]$" "$printer_cfg"; then
            if ! sed -i '2i[include change_profile.cfg]' "$printer_cfg"; then
                echo "${MSG[sed_include_error]} $printer_cfg"
            fi
        fi
    fi
    
    # Создаем/обновляем макрос с динамическим названием профиля в change_profile.cfg / Create/update macro
    local cfg_file="$CONFIG_DIR/change_profile.cfg"
    if [ -f "$cfg_file" ]; then
        # Удаляем старую секцию макроса ACTIVE_PROFILE / Delete old section
        if ! sed -i "/^\[gcode_macro ACTIVE_PROFILE\]/,/^\[.*\]/d" "$cfg_file"; then
            echo "${MSG[sed_delete_old_macro_warning]}"
        fi
        
        # Добавляем новую секцию с динамическим названием в конец файла / Add new section
        echo "" >> "$cfg_file"
        echo "[gcode_macro ACTIVE_PROFILE]" >> "$cfg_file"
        echo "description: ${MSG[change_cfg_macro_desc]} $profile_num" >> "$cfg_file"
        echo "gcode:" >> "$cfg_file"
        echo "    RESPOND PREFIX=\"info\" MSG=\"${MSG[change_cfg_macro_msg]} $profile_num\"" >> "$cfg_file"
    fi
    
    echo "${MSG[profile_activated]} $profile_name"
}

delete_all_profiles() {
    echo "${MSG[delete_warning]}"
    echo "${MSG[delete_irreversible]}"
    read -p "${MSG[confirm_delete]} " confirmation </dev/tty
    if [ "$confirmation" = "DELETE" ]; then
        local existing_profiles=($(get_existing_profiles))
        for profile in "${existing_profiles[@]}"; do
            if ! rm -rf "$CONFIG_DIR/$profile"; then
                echo "${MSG[delete_error]} $profile"
            else
                echo "${MSG[deleted_profile]} $profile"
            fi
        done
        if [ -f "$CONFIG_DIR/active_profile" ]; then
            if ! rm "$CONFIG_DIR/active_profile"; then
                echo "${MSG[delete_active_error]}"
            fi
        fi
        if [ -f "$CONFIG_DIR/change_profile.cfg" ]; then
            if ! rm "$CONFIG_DIR/change_profile.cfg"; then
                echo "${MSG[delete_cfg_error]}"
            fi
        fi
        if [ -f "$CONFIG_DIR/change_profile.sh" ]; then
            if ! rm "$CONFIG_DIR/change_profile.sh"; then
                echo "${MSG[delete_sh_error]}"
            fi
        fi
        
        # Очищаем printer.cfg от строк профиля и include / Clear printer.cfg
        local printer_cfg="$CONFIG_DIR/printer.cfg"
        if [ -f "$printer_cfg" ]; then
            # Удаляем строки с #Profile_ / Delete #Profile_ lines
            if ! sed -i '/^#Profile_/d' "$printer_cfg"; then
                echo "${MSG[sed_clear_warning]} $printer_cfg"
            fi
            # Удаляем строку [include change_profile.cfg] / Delete include line
            if ! sed -i '/^\[include change_profile.cfg\]$/d' "$printer_cfg"; then
                echo "${MSG[sed_delete_include_warning]} $printer_cfg"
            fi
            echo "${MSG[printer_cfg_cleared]}"
        fi
        
        echo "${MSG[all_deleted]}"
        echo "${MSG[restarting_klipper]}"
        sudo systemctl restart klipper || echo "${MSG[restart_failed]}"
        echo "${MSG[klipper_restarted]}"
    else
        echo "${MSG[delete_canceled]}"
    fi
}

delete_single_profile() {
    local existing_profiles=($(get_existing_profiles))
    if [ ${#existing_profiles[@]} -eq 0 ]; then
        echo "${MSG[no_profiles_delete]}"
        return
    fi
    
    echo "${MSG[available_profiles]}"
    for i in "${!existing_profiles[@]}"; do
        echo "$((i+1)). ${existing_profiles[$i]}"
    done
    
    read -p "${MSG[choose_delete]} (1-${#existing_profiles[@]}): " choice </dev/tty
    
    if [[ $choice =~ ^[0-9]+$ ]] && [ $choice -ge 1 ] && [ $choice -le ${#existing_profiles[@]} ]; then
        local profile_to_delete="${existing_profiles[$((choice-1))]}"
        echo "${MSG[single_delete_warning]} $profile_to_delete"
        echo "${MSG[delete_irreversible]}"
        read -p "${MSG[confirm_delete]} " confirmation </dev/tty
        if [ "$confirmation" = "DELETE" ]; then
            if ! rm -rf "$CONFIG_DIR/$profile_to_delete"; then
                echo "${MSG[single_delete_error]} $profile_to_delete"
                return 1
            else
                echo "${MSG[single_deleted]} $profile_to_delete"
            fi
            
            # Обновляем active_profile если удаляемый был активным / Update active_profile if deleted was active
            local active_profile=$(cat "$CONFIG_DIR/active_profile" 2>/dev/null || true)
            if [ "$active_profile" = "$profile_to_delete" ]; then
                if ! rm "$CONFIG_DIR/active_profile"; then
                    echo "${MSG[delete_active_error]}"
                else
                    echo "${MSG[active_reset]}"
                fi
            fi
            
            # Пересоздаем конфиг с макросами / Recreate config with macros
            create_change_profile_config
            
            # Перезапускаем Klipper после удаления профиля / Restart Klipper after deletion
            echo "${MSG[restarting_klipper]}"
            sudo systemctl restart klipper || echo "${MSG[restart_failed]}"
            echo "${MSG[klipper_restarted]}"
        else
            echo "${MSG[delete_canceled]}"
        fi
    else
        echo "${MSG[invalid_choice]}"
    fi
}

# === Основная логика / Main Logic ===
echo "${MSG[management_title]}"
echo "${MSG[user]} $CURRENT_USER"
echo "${MSG[config]} $CONFIG_DIR"

# Проверяем, есть ли уже профили / Check if profiles exist
existing_profiles=($(get_existing_profiles))

if [ ${#existing_profiles[@]} -eq 0 ]; then
    # Первый запуск - создание профилей / First run - create profiles
    echo "${MSG[first_run]}"
    
    while true; do
        read -p "${MSG[how_many_profiles]} " num_profiles </dev/tty
        if [[ $num_profiles =~ ^[1-5]$ ]]; then
            break
        else
            echo "${MSG[invalid_num]}"
        fi
    done
    
    # Создаем резервную копию / Create backup
    create_backup
    
    # Создаем профили / Create profiles
    for ((i=1; i<=num_profiles; i++)); do
        create_profile $i
    done
    
    # Создаем скрипт и конфиг / Create script and config
    create_change_profile_script
    create_change_profile_config
    
    # Добавляем include в основной printer.cfg / Add include to main printer.cfg
    PRINTER_CFG="$CONFIG_DIR/printer.cfg"
    if [ -f "$PRINTER_CFG" ]; then
        if ! grep -q "^\[include change_profile.cfg\]$" "$PRINTER_CFG"; then
            if ! sed -i '1i[include change_profile.cfg]' "$PRINTER_CFG"; then
                echo "${MSG[sed_include_warning]} $PRINTER_CFG"
                exit 1
            else
                echo "${MSG[include_added]}"
            fi
        fi
    else
        echo "${MSG[no_printer_cfg_main]} $CONFIG_DIR!"
        exit 1
    fi
    
    # Активируем первый профиль / Activate first profile
    activate_profile 1
    
    echo "${MSG[creation_complete]}"
    echo "${MSG[profiles_created]} $num_profiles"
    echo "${MSG[restarting_for_macros]}"
    sudo systemctl restart klipper || echo "${MSG[restart_failed]}"
    
else
    # Повторный запуск - меню выбора / Repeat run - menu
    echo "${MSG[repeat_run]}"
    for profile in "${existing_profiles[@]}"; do
        echo "  - $profile"
    done
    echo ""
    echo "${MSG[available_actions]}"
    echo "${MSG[add_profile]}"
    echo "${MSG[delete_all]}"
    echo "${MSG[delete_one]}"
    echo "${MSG[create_archive]}"
    echo "${MSG[exit]}"
    
    while true; do
        read -p "${MSG[choose_action]} " action </dev/tty
        case $action in
            1)
                # Добавить профиль / Add profile
                current_count=${#existing_profiles[@]}
                if [ $current_count -ge 5 ]; then
                    echo "${MSG[max_profiles]}"
                else
                    next_num=$((current_count + 1))
                    create_profile $next_num
                    create_change_profile_config  # Обновляем макросы / Update macros
                    
                    # Обновляем основной printer.cfg / Update main printer.cfg
                    PRINTER_CFG="$CONFIG_DIR/printer.cfg"
                    if [ -f "$PRINTER_CFG" ]; then
                        if ! grep -q "^\[include change_profile.cfg\]$" "$PRINTER_CFG"; then
                            if ! sed -i '1i[include change_profile.cfg]' "$PRINTER_CFG"; then
                                echo "${MSG[sed_include_warning]} $PRINTER_CFG"
                            else
                                echo "${MSG[include_added]}"
                            fi
                        fi
                    fi
                    echo "${MSG[profile_added]} printer_$next_num"
                fi
                ;;
            2)
                # Удалить все профили / Delete all profiles
                delete_all_profiles
                ;;
            3)
                # Удалить один профиль / Delete one profile
                delete_single_profile
                ;;
            4)
                # Создать архив / Create archive
                create_backup
                ;;
            5)
                # Выйти / Exit
                echo "${MSG[exit_msg]}"
                exit 0
                ;;
            *)
                echo "${MSG[invalid_choice]}"
                ;;
        esac
    done
fi
