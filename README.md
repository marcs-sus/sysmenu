# sysmenu

sysmenu is an interactive `systemd` service manager for the command line. It uses `fzf`, `gum`, and `bat` to provide a simple and efficient way to manage `systemd` units.

## Demo Video

[![asciicast](https://asciinema.org/a/FHSdVYqBtkB8eRKm.svg)](https://asciinema.org/a/FHSdVYqBtkB8eRKm)

## Features

- **Interactive management:** Easily start, stop, restart, enable, and disable `systemd` services.
- **System and user units:** Lists both system and user `systemd` units.
- **Service status and logs:** View the status and logs of any service.
- **Favorites:** Mark services as favorites for quick access.
- **Fuzzy search:** Uses `fzf` for quick and easy service searching.
- **Desktop integration:** Can be run as a desktop application.

## Dependencies

sysmenu requires the following commands to be installed on your system:

- [`fzf`](https://github.com/junegunn/fzf)
- `systemctl`
- `journalctl`
- `sudo`
- `awk`

For a better user experience, it is recommended to also install:

- [`gum`](https://github.com/charmbracelet/gum)
- [`bat`](https://github.com/sharkdp/bat)

## Installation

The easiest way to install sysmenu is using the automated installer:

```bash
curl -fsSL https://raw.githubusercontent.com/marcs-sus/sysmenu/master/install.sh | bash
```

> **⚠️ Security Note:** It's generally not recommended to pipe curl commands directly to bash without checking them first. The `install.sh` script simply downloads the sysmenu binary, makes it executable, installs the desktop entry, and updates your desktop database.

### Manual Installation

If you prefer to install manually:

1.  Make the script executable:

    ```bash
    chmod +x sysmenu.sh
    ```

2.  Move the script to a directory in your `$PATH`. A common choice is `$HOME/.local/bin`:
    ```bash
    mkdir -p "$HOME/.local/bin"
    mv sysmenu.sh "$HOME/.local/bin/sysmenu"
    ```

## Usage

To run sysmenu, simply execute the script:

```bash
sysmenu
```

### Command-line options

- `--favorites`, `-f`: Show only favorite services.
- `--app`, `-a`: Run as a desktop application (in a loop).

## Configuration

### Favorites

sysmenu allows you to mark services as "favorites" for quicker access. These favorites are stored at `~/.sysmenu_favorites`. You can add a service to your favorites from within the sysmenu interface.

## Desktop Integration

sysmenu includes a `.desktop` file that allows you to launch it as a desktop application from your application menu. The automated installer handles this for you, but if you installed manually, follow these steps:

1.  Update the `Exec` path in `sysmenu.desktop` to point to the location where you installed the `sysmenu.sh` script. For example, if you installed it to `$HOME/.local/bin/sysmenu`, the `Exec` lines should look like this:

    ```ini
    Exec=$HOME/.local/bin/sysmenu --app
    ```

    and for the favorite action

    ```ini
    Exec=$HOME/.local/bin/sysmenu --app --favorites
    ```

2.  Install the `.desktop` file to your applications directory:
    ```bash
    desktop-file-install --dir="$HOME/.local/share/applications" sysmenu.desktop
    ```

After installation, you should be able to find "System Menu" in your application launcher.

## Uninstallation

To uninstall sysmenu:

```bash
curl -fsSL https://raw.githubusercontent.com/marcs-sus/sysmenu/master/uninstall.sh | bash
```

Or simply remove the files:

```bash
rm ~/.local/bin/sysmenu
rm ~/.local/share/applications/sysmenu.desktop
rm ~/.sysmenu_favorites
```

## Acknowledgements

This project was mainly inspired by [sysz](https://github.com/joehillen/sysz), an excellent systemd service selector that provided the foundation for this tool's concept.

sysmenu also wouldn't be possible without these amazing tools:

- [fzf](https://github.com/junegunn/fzf) - The fuzzy finder that powers service selection
- [bat](https://github.com/sharkdp/bat) - Syntax highlighting for logs and output
- [gum](https://github.com/charmbracelet/gum) - Beautiful TUI components for confirmations and styling
