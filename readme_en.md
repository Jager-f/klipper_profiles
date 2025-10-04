# 🖨️ Klipper Multi-Profile Manager

This script creates additional profiles and automates their switching for [Klipper](https://www.klipper3d.org/) — a popular firmware stack for 3D printers.  
With it, you can easily switch between **five independent printer profiles** (each with its own settings) directly from the web interface (Fluidd, Mainsail, etc.).

⚠️ **Important!** All code is provided “as is.” The author is not responsible for any possible damage caused by using these profiles.  
Before starting a print, make sure to check all your printer’s settings!  

---

## 🔧 Features

- 💾 Automatically creates a backup of the current configuration before installation  
- 📁 Creates between 1 and 5 profiles of your choice: `printer_1`, `printer_2`, `printer_3`, `printer_4`, `printer_5` and copies the current configuration files into them  
- 🔄 Allows switching profiles via the printer console:
  - `Profile_1`, `Profile_2`, `Profile_3`, `Profile_4`, `Profile_5`
    
  or by selecting macros:
  - `SWITCH_PROFILE_1`, `SWITCH_PROFILE_2`, `SWITCH_PROFILE_3`, `SWITCH_PROFILE_4`, `SWITCH_PROFILE_5`
- ⚠️ You can check the active profile number with the `ACTIVE_PROFILE` macro  

- 🔄 On re-run, a menu becomes available:

1. Add a profile to existing ones

2. Delete all profiles (except the main one)

3. Delete a single profile

4. Create an archive

5. Exit

- 📝 When switching:
  - Saves changes of the current active profile
  - Loads the new profile into the main config folder
  - Restarts Klipper
  - Displays the current profile on the printer’s screen (if supported)  


```
 📂 Structure after installation

/home/biqu/printer_data/config/
├── printer.cfg # current active configuration
├── active_profile # file with the active profile name (e.g. printer_1)
├── change_profile.sh # profile switching script
├── change_profile.cfg # G-code macros for switching
├── klipper_config_backup_*.tar.gz # backup archive
├── printer_1/ # profile 1
├── printer_2/ # profile 2
├── printer_3/ # profile 3
├── printer_4/ # profile 4
└── printer_5/ # profile 5
```


## 🚀 Installation

1. Connect to the printer via SSH  
2. Install G-Code Shell Commands (using [KIAHU](https://github.com/dw-0/kiauh))  
3. Run the script with:  
```javascript copy
   wget -qO- https://raw.githubusercontent.com/Jager-f/klipper_profiles/main/klipper_profiles.sh | bash
```
4. After installation, Klipper will automatically reboot with profile 1 loaded

## **🔄 How to use**
After installation you can switch profiles via the printer console:

Profile_1, Profile_2, Profile_3, Profile_4, Profile_5

or by selecting macros:

SWITCH_PROFILE_1, SWITCH_PROFILE_2, SWITCH_PROFILE_3, SWITCH_PROFILE_4, SWITCH_PROFILE_5

After executing a profile switch command:

The current configuration is saved back into the active profile folder

The new profile is copied into the main folder

Klipper restarts (~10 sec)

On the printer’s display (if available) a message will appear:🟢 Profile: printer_2

## **🔒 Safety**
Before the first installation, a full backup of your current configuration is created.

When switching profiles, changes to the active profile are automatically saved.

When re-running the installer, deleting profiles requires confirmation to avoid accidental data loss.

💡 Tip: After the script finishes, the printer will boot with profile 1 — this is the state your printer was in before installation and can be kept as the default option.
Other profiles are most convenient to modify by switching to them, all changes will be saved upon switching.
Each profile’s printer.cfg contains a comment with the profile number for visual tracking.
The simplest way to restore the printer to its original state is to rerun the installer and select option 2.

🎉 Happy printing!
