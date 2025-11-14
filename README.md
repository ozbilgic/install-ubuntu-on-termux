# How to Install Ubuntu on Termux?

Automatic Ubuntu installation script for Termux. No root required.

## Features

- **Dynamic LTS Selection**: Automatically detects the latest 4 released Ubuntu LTS versions
- **Stable Releases Only**: Only fully compatible LTS versions with Termux are offered
- **Smart Fallback**: Offers alternative versions if download fails
- **Auto Repair**: Automatically fixes Termux library issues
- **Auto Start**: Option to automatically start Ubuntu when opening Termux
- **Ubuntu Logo**: Displays colorful Ubuntu logo on startup
- **User Management**: Option to create a secure user during first setup (with first-setup.sh)
  - Automatic sudo privileges
  - Password-protected login
  - Work with a secure user instead of root
- **Easy Installation**: One-command installation

## One-Command Installation

```bash
pkg update && pkg upgrade -y && pkg install -y wget && wget -O - https://raw.githubusercontent.com/ozbilgic/install-ubuntu-on-termux/main/ubuntu-installer.sh | bash
```

**Note:** When using one-command installation, the script runs in automatic mode:
- The newest Ubuntu LTS version is automatically selected
- Alternative versions are automatically tried if download fails
- Auto-start is enabled by default
- Installation completes without user interaction

## Manual Installation

With manual installation, all options are presented to you and you can configure as you wish:

```bash
# Download the script
wget https://raw.githubusercontent.com/ozbilgic/install-ubuntu-on-termux/main/ubuntu-installer.sh

# Make it executable
chmod +x ubuntu-installer.sh

# Start installation
./ubuntu-installer.sh
```

In manual installation:
- You choose which Ubuntu LTS version to install
- You can enable or disable auto-start option
- You get the option to start Ubuntu immediately or later

## Installation Steps

1. Automatic update and repair of Termux packages
2. Ubuntu LTS version selection (choose from 4 dynamically detected LTS versions)
3. Installation of required packages (proot, wget, tar)
4. Download and install Ubuntu rootfs
5. Alternative version selection if download fails
6. Create startup script (start-ubuntu.sh)
7. Prepare first setup script (first-setup.sh)
8. Auto-start option (with Ubuntu logo)
9. First setup: System update, essential packages, and new user creation

## Starting Ubuntu (For Those Who Didn't Choose Auto-Start)

```bash
./start-ubuntu.sh
```

## First Time Setup

When you first enter Ubuntu, run this command:

```bash
bash /root/first-setup.sh
```

This command will:
- Update the system
- Install essential packages (nano, vim, wget, curl, git, sudo)
- Configure locale settings
- **Offer new user creation** (to use instead of root)
  - Set username and password
  - Grant automatic sudo privileges
  - Start with this user every time Termux opens

### Creating a New User (Recommended)

During the first setup, the `first-setup.sh` script offers you the option to create a new user. With this feature:
- You can work with a secure user instead of root
- The user automatically receives sudo privileges
- Termux will automatically start with this user every time it opens
- You can switch between users anytime with `su - username`

## Disabling Auto-Start

If you want to disable auto-start:

```bash
nano ~/.bashrc
# Delete the "Ubuntu logo and auto-start" section at the end
```

## Supported Architectures

- ARM64 (aarch64)
- ARMHF (armv7l, armv8l)

## Requirements

- Termux application
- Internet connection
- At least 1GB free space

## Exiting Ubuntu

```bash
exit
```

## Troubleshooting

### wget Library Error (libandroid-posix-semaphore.so)
The script will try to automatically fix this issue. If it persists:

```bash
# Close Termux completely and reopen it
pkg update && pkg upgrade -y
pkg install --reinstall wget
```

### Download Errors
- Check your internet connection
- The script will automatically offer alternative versions
- Try a different network
- Run the script again

### Installation Errors
To remove existing installation and reinstall:

```bash
rm -rf ~/ubuntu-fs
./ubuntu-installer.sh
```

## License

MIT License

## Contributing

Pull requests are welcome. For major changes, please open an issue first.
