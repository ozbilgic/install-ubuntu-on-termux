#!/data/data/com.termux/files/usr/bin/bash

# Ubuntu Termux Manual Installation Script (with PRoot)
# No root required, does not use proot-distro

echo "================================================"
echo "  Ubuntu Termux Manual Installation Script"
echo "================================================"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Error checking function
check_error() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}[ERROR]${NC} $1"
        exit 1
    fi
}

# Info message function
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# Warning message function
warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Installation directory
UBUNTU_DIR="$HOME/ubuntu-fs"
SCRIPT_DIR="$HOME"

# 1. Update and repair Termux packages
info "Updating and repairing Termux packages..."
info "This may take a few minutes..."

# Update package database
pkg update -y 2>/dev/null || {
    warn "Normal update failed, changing repository..."
    termux-change-repo
    pkg update -y
}

# Upgrade critical libraries and packages
info "Upgrading system packages..."
pkg upgrade -y libandroid-posix-semaphore 2>/dev/null || true
pkg upgrade -y 2>/dev/null || {
    warn "Some packages could not be upgraded, continuing..."
}

# 2. Install/reinstall required packages
info "Installing required packages..."
pkg install -y --reinstall proot wget tar -o Dpkg::Options::="--force-confnew"
check_error "Failed to install required packages"

# Test if wget is working
info "Testing wget..."
if ! wget --version >/dev/null 2>&1; then
    echo -e "${RED}[ERROR]${NC} wget is not working properly."
    echo "Please close Termux completely, reopen it, and run the script again."
    exit 1
fi
info "✓ wget is working"

# Check if running via pipe (early detection)
PIPED_INPUT=false
if [ ! -t 0 ]; then
    PIPED_INPUT=true
    warn "Script is running via pipe, default values will be used"
fi

# 3. Check for existing installation
if [ -d "$UBUNTU_DIR" ]; then
    warn "Ubuntu installation already exists: $UBUNTU_DIR"

    # If running via pipe, automatically remove and reinstall
    if [ "$PIPED_INPUT" = true ]; then
        response="y"
        info "Default choice: Existing installation will be removed and reinstalled"
    else
        read -p "Do you want to remove the existing installation and reinstall? (y/n): " response
    fi

    if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
        info "Removing existing installation..."
        rm -rf "$UBUNTU_DIR"
        check_error "Failed to remove installation"
    else
        info "Installation cancelled."
        exit 0
    fi
fi

# 4. Create installation directory
info "Creating installation directory: $UBUNTU_DIR"
mkdir -p "$UBUNTU_DIR"
check_error "Failed to create directory"

# 5. Download Ubuntu base rootfs
info "Downloading Ubuntu base rootfs..."
info "This may take a few minutes, please wait..."

# Architecture detection
case $(uname -m) in
    aarch64|arm64)
        ARCH="arm64"
        ;;
    armv7l|armv8l)
        ARCH="armhf"
        ;;
    *)
        echo -e "${RED}[ERROR]${NC} Unsupported architecture: $(uname -m)"
        exit 1
        ;;
esac

info "Architecture: $ARCH"

# Dynamically detect the latest 4 LTS versions
info "Checking available Ubuntu LTS versions..."

# Fetch the latest 4 LTS versions from Ubuntu releases page
# LTS versions end with .04 and ONLY release on even years (20.04, 22.04, 24.04, 26.04...)
AVAILABLE_VERSIONS=$(wget -qO- https://cdimage.ubuntu.com/ubuntu-base/releases/ 2>/dev/null | \
    grep -oP 'href="\K[0-9]{2}\.04(?=/)' | \
    awk '{year=int(substr($1,1,2)); if(year%2==0) print $1}' | \
    sort -Vru | \
    head -n 4)

if [ -z "$AVAILABLE_VERSIONS" ]; then
    echo -e "${RED}[ERROR]${NC} Could not detect Ubuntu versions. Check your internet connection."
    warn "Using fallback known versions..."
    AVAILABLE_VERSIONS="24.04
22.04
20.04
18.04"
fi

# Store 4 versions in array
VERSION_ARRAY=($AVAILABLE_VERSIONS)

VERSION_1="${VERSION_ARRAY[0]}"
VERSION_2="${VERSION_ARRAY[1]}"
VERSION_3="${VERSION_ARRAY[2]}"
VERSION_4="${VERSION_ARRAY[3]}"

# Find the latest point release for each version
info "Checking for latest updates..."

# Success message
if [ ${#VERSION_ARRAY[@]} -ge 4 ]; then
    info "✓ Successfully detected the latest 4 Ubuntu LTS versions"
fi

get_latest_point_release() {
    local base_version=$1
    local latest_point=$(wget -qO- "https://cdimage.ubuntu.com/ubuntu-base/releases/${base_version}/release/" 2>/dev/null | \
        grep -oP "ubuntu-base-${base_version}\.\K[0-9]+" | \
        sort -n | \
        tail -n 1)

    if [ -z "$latest_point" ]; then
        # Use base version if no point release (for new versions)
        echo "${base_version}"
    else
        # Use point release if available
        echo "${base_version}.${latest_point}"
    fi
}

VERSION_1_FULL=$(get_latest_point_release "$VERSION_1")
VERSION_2_FULL=$(get_latest_point_release "$VERSION_2")
VERSION_3_FULL=$(get_latest_point_release "$VERSION_3")
VERSION_4_FULL=$(get_latest_point_release "$VERSION_4")

# Let user choose
echo ""
echo -e "${BLUE}Which Ubuntu LTS version would you like to install?${NC}"
echo -e "${YELLOW}(LTS versions are fully compatible with Termux and supported for 5 years)${NC}"
echo ""
echo "  1) Ubuntu ${VERSION_1_FULL} LTS"
echo "  2) Ubuntu ${VERSION_2_FULL} LTS"
echo "  3) Ubuntu ${VERSION_3_FULL} LTS"
echo "  4) Ubuntu ${VERSION_4_FULL} LTS"
echo ""

# If running via pipe, use default choice
if [ "$PIPED_INPUT" = true ]; then
    version_choice=1
    info "Default choice: Ubuntu ${VERSION_1_FULL} LTS"
else
    read -p "Your choice (1, 2, 3, or 4): " version_choice
fi

# Set selected version and alternatives
case $version_choice in
    1)
        UBUNTU_VERSION="$VERSION_1_FULL"
        UBUNTU_BASE_VERSION="$VERSION_1"
        ALTERNATIVES=("$VERSION_2_FULL:$VERSION_2" "$VERSION_3_FULL:$VERSION_3" "$VERSION_4_FULL:$VERSION_4")
        info "Ubuntu ${VERSION_1_FULL} selected"
        ;;
    2)
        UBUNTU_VERSION="$VERSION_2_FULL"
        UBUNTU_BASE_VERSION="$VERSION_2"
        ALTERNATIVES=("$VERSION_1_FULL:$VERSION_1" "$VERSION_3_FULL:$VERSION_3" "$VERSION_4_FULL:$VERSION_4")
        info "Ubuntu ${VERSION_2_FULL} selected"
        ;;
    3)
        UBUNTU_VERSION="$VERSION_3_FULL"
        UBUNTU_BASE_VERSION="$VERSION_3"
        ALTERNATIVES=("$VERSION_1_FULL:$VERSION_1" "$VERSION_2_FULL:$VERSION_2" "$VERSION_4_FULL:$VERSION_4")
        info "Ubuntu ${VERSION_3_FULL} selected"
        ;;
    4)
        UBUNTU_VERSION="$VERSION_4_FULL"
        UBUNTU_BASE_VERSION="$VERSION_4"
        ALTERNATIVES=("$VERSION_1_FULL:$VERSION_1" "$VERSION_2_FULL:$VERSION_2" "$VERSION_3_FULL:$VERSION_3")
        info "Ubuntu ${VERSION_4_FULL} selected"
        ;;
    *)
        echo -e "${RED}[ERROR]${NC} Invalid choice. You must select 1, 2, 3, or 4."
        exit 1
        ;;
esac

# Dynamically build download URLs
UBUNTU_URL="https://cdimage.ubuntu.com/ubuntu-base/releases/${UBUNTU_BASE_VERSION}/release/ubuntu-base-${UBUNTU_VERSION}-base-${ARCH}.tar.gz"

echo ""

cd "$HOME"

# Attempt download
info "Download URL: $UBUNTU_URL"
wget --timeout=30 --tries=3 --continue "${UBUNTU_URL}" -O ubuntu.tar.gz

# Check download
if [ $? -ne 0 ] || [ ! -f ubuntu.tar.gz ] || [ ! -s ubuntu.tar.gz ]; then
    echo -e "${RED}[ERROR]${NC} Failed to download Ubuntu ${UBUNTU_VERSION}."
    rm -f ubuntu.tar.gz

    # Offer alternative versions
    echo ""
    warn "Download failed for Ubuntu ${UBUNTU_VERSION}."
    echo ""
    echo -e "${BLUE}Would you like to try one of the alternative versions?${NC}"
    echo ""

    # Show alternatives
    for i in "${!ALTERNATIVES[@]}"; do
        ALT_FULL=$(echo "${ALTERNATIVES[$i]}" | cut -d: -f1)
        echo "  $((i+1))) Ubuntu ${ALT_FULL}"
    done
    echo "  $((${#ALTERNATIVES[@]}+1))) Cancel installation"
    echo ""

    # If running via pipe, automatically try first alternative
    if [ "$PIPED_INPUT" = true ]; then
        alt_choice=1
        info "Default choice: Trying first alternative version"
    else
        read -p "Your choice: " alt_choice
    fi

    # Validate choice
    if [ "$alt_choice" -ge 1 ] && [ "$alt_choice" -le "${#ALTERNATIVES[@]}" ] 2>/dev/null; then
        selected_index=$((alt_choice-1))
        UBUNTU_VERSION=$(echo "${ALTERNATIVES[$selected_index]}" | cut -d: -f1)
        UBUNTU_BASE_VERSION=$(echo "${ALTERNATIVES[$selected_index]}" | cut -d: -f2)
        UBUNTU_URL="https://cdimage.ubuntu.com/ubuntu-base/releases/${UBUNTU_BASE_VERSION}/release/ubuntu-base-${UBUNTU_VERSION}-base-${ARCH}.tar.gz"

        info "Trying Ubuntu ${UBUNTU_VERSION}..."
        info "Download URL: $UBUNTU_URL"
        wget --timeout=30 --tries=3 --continue "${UBUNTU_URL}" -O ubuntu.tar.gz

        # Check alternative download
        if [ $? -ne 0 ] || [ ! -f ubuntu.tar.gz ] || [ ! -s ubuntu.tar.gz ]; then
            echo -e "${RED}[ERROR]${NC} Failed to download Ubuntu ${UBUNTU_VERSION} as well."
            echo "Check your internet connection and try again."
            rm -f ubuntu.tar.gz
            exit 1
        fi
    else
        echo "Installation cancelled."
        exit 1
    fi
fi

info "Ubuntu rootfs downloaded successfully ($(du -h ubuntu.tar.gz | cut -f1))"

# 6. Extract rootfs
info "Extracting Ubuntu rootfs..."
info "This may take a few minutes..."

cd "$UBUNTU_DIR"

# Validate tar file
info "Validating tar file..."
tar -tzf "$HOME/ubuntu.tar.gz" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "${RED}[ERROR]${NC} Tar file is corrupted, re-downloading..."
    rm -f "$HOME/ubuntu.tar.gz"
    cd "$HOME"
    wget --timeout=30 --tries=3 --continue "${UBUNTU_URL}" -O ubuntu.tar.gz
    check_error "Re-download failed"
fi

# Try different tar parameters
info "Extracting files (method 1)..."
proot --link2symlink tar -xf "$HOME/ubuntu.tar.gz" --exclude='dev'||true 2>/dev/null

# Try alternative method if failed
if [ ! -d "$UBUNTU_DIR/usr" ]; then
    info "Trying alternative method..."
    tar --warning=no-unknown-keyword --delay-directory-restore --preserve-permissions -xpf "$HOME/ubuntu.tar.gz" 2>/dev/null || \
    tar -xpf "$HOME/ubuntu.tar.gz" 2>/dev/null || \
    tar -xf "$HOME/ubuntu.tar.gz" 2>/dev/null
fi

# Check
if [ ! -d "$UBUNTU_DIR/usr" ] || [ ! -d "$UBUNTU_DIR/etc" ]; then
    echo -e "${RED}[ERROR]${NC} Rootfs was not extracted properly."
    echo "Please check manually: ls -la $UBUNTU_DIR"
    exit 1
fi

info "Rootfs extracted successfully"

# Clean up downloaded file
rm "$HOME/ubuntu.tar.gz"
info "Temporary files cleaned up"

# 7. Configure DNS settings
info "Configuring DNS..."
echo "nameserver 8.8.8.8" > "$UBUNTU_DIR/etc/resolv.conf"
echo "nameserver 8.8.4.4" >> "$UBUNTU_DIR/etc/resolv.conf"

# 8. Create startup script
info "Creating startup script..."
cat > "$SCRIPT_DIR/start-ubuntu.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash

# Disable termux-exec
unset LD_PRELOAD

UBUNTU_DIR="$HOME/ubuntu-fs"

# Create required directories
mkdir -p "$UBUNTU_DIR/dev"
mkdir -p "$UBUNTU_DIR/proc"
mkdir -p "$UBUNTU_DIR/sys"
mkdir -p "$UBUNTU_DIR/tmp"
mkdir -p "$UBUNTU_DIR/root"

# Check for username
UBUNTU_USER=""
if [ -f "$UBUNTU_DIR/root/.ubuntu-user" ]; then
    UBUNTU_USER=$(cat "$UBUNTU_DIR/root/.ubuntu-user")
fi

# Start Ubuntu with PRoot
if [ -n "$UBUNTU_USER" ]; then
    # If user exists, start with that user
    proot \
        --root-id \
        --link2symlink \
        --kill-on-exit \
        --rootfs="$UBUNTU_DIR" \
        --bind=/dev \
        --bind=/proc \
        --bind=/sys \
        --bind=/sdcard \
        --cwd=/home/$UBUNTU_USER \
        --mount=/proc \
        --mount=/sys \
        --mount=/dev \
        /usr/bin/env -i \
        HOME=/home/$UBUNTU_USER \
        USER=$UBUNTU_USER \
        TERM="$TERM" \
        LANG=C.UTF-8 \
        PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
        /bin/bash -c "/bin/su -l $UBUNTU_USER"
else
    # If no user, start with root
    proot \
        --root-id \
        --link2symlink \
        --kill-on-exit \
        --rootfs="$UBUNTU_DIR" \
        --bind=/dev \
        --bind=/proc \
        --bind=/sys \
        --bind=/sdcard \
        --cwd=/root \
        --mount=/proc \
        --mount=/sys \
        --mount=/dev \
        /usr/bin/env -i \
        HOME=/root \
        TERM="$TERM" \
        LANG=C.UTF-8 \
        PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
        /bin/bash --login
fi
EOF

chmod +x "$SCRIPT_DIR/start-ubuntu.sh"

# 9. Create first setup script (to run inside Ubuntu)
info "Preparing first setup script..."
cat > "$UBUNTU_DIR/root/first-setup.sh" << 'EOF'
#!/bin/bash

echo "Starting Ubuntu first setup. This may take a while, please wait..."

echo "Updating package lists..."
apt update
apt upgrade -y

echo "Configuring locale settings..."
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

echo "Installing essential packages..."
apt install -y nano vim wget curl git sudo locales tzdata

echo "Configuring locale settings..."
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8

# Fix hosts file
echo '127.0.0.1 localhost' > /etc/hosts
echo '127.0.1.1 localhost.localdomain' >> /etc/hosts

echo "Configuring packages..."
sudo dpkg --configure -a

# Fix group files
sudo groupadd -g 3003 termux_gid3003 2>/dev/null || true
sudo groupadd -g 9997 termux_gid9997 2>/dev/null || true
sudo groupadd -g 20427 termux_gid20427 2>/dev/null || true
sudo groupadd -g 50427 termux_gid50427 2>/dev/null || true

echo ""
echo "================================================"
echo "  Ubuntu basic setup completed!"
echo "================================================"
echo ""

# New user creation option
read -p "Would you like to create a new non-root user? (y/n): " create_user

if [ "$create_user" = "y" ] || [ "$create_user" = "Y" ]; then
    echo ""
    echo "Creating new user..."
    echo ""

    # Get username
    while true; do
        read -p "Username: " username

        # Username validation
        if [ -z "$username" ]; then
            echo "Error: Username cannot be empty."
            continue
        fi

        if id "$username" &>/dev/null; then
            echo "Error: User '$username' already exists."
            continue
        fi

        if ! [[ "$username" =~ ^[a-z][-a-z0-9]*$ ]]; then
            echo "Error: Invalid username. Must start with a lowercase letter and contain only letters, numbers, and hyphens."
            continue
        fi

        break
    done

    # Create user
    useradd -m -s /bin/bash "$username"

    if [ $? -eq 0 ]; then
        echo "✓ User '$username' created"

        # Set password
        echo ""
        echo "Set password:"
        passwd "$username"

        # Grant sudo privileges (automatic)
        echo ""
        echo "Granting sudo privileges..."

        # Add user to sudo group
        usermod -aG sudo "$username"

        # Create configuration for user in /etc/sudoers.d/
        # NOPASSWD is optional, sudo will work without password
        echo "$username ALL=(ALL:ALL) NOPASSWD: ALL" > "/etc/sudoers.d/$username"
        chmod 0440 "/etc/sudoers.d/$username"

        echo "✓ Sudo privileges granted to '$username'"

        # Add additional groups
        usermod -aG termux_gid3003,termux_gid9997,termux_gid20427,termux_gid50427 "$username" 2>/dev/null || true

        # Save username (for start-ubuntu.sh)
        echo "$username" > /root/.ubuntu-user

        echo ""
        echo "✓ User created successfully!"
        echo ""
        echo "Termux will automatically start with user '$username' every time it opens."
        echo ""
        echo "To switch to the new user:"
        echo "  su - $username"
        echo ""
    else
        echo "✗ Failed to create user"
    fi
else
    echo "New user not created."
fi

echo ""
echo "================================================"
echo "  Setup completed!"
echo "================================================"
echo ""
echo "First setup script completed."
echo "You can delete this file: rm /root/first-setup.sh"
echo ""
EOF

chmod +x "$UBUNTU_DIR/root/first-setup.sh"

# 10. Installation completed
echo ""
echo "================================================"
info "Ubuntu installed successfully!"
echo "================================================"
echo ""
echo -e "${BLUE}Installation Directory:${NC} $UBUNTU_DIR"
echo ""
echo -e "${GREEN}To start Ubuntu:${NC}"
echo "  ./start-ubuntu.sh"
echo ""
echo -e "${GREEN}On first login, run:${NC}"
echo "  bash /root/first-setup.sh"
echo ""
echo "This command will update the system and install essential packages."
echo ""
echo -e "${YELLOW}Note:${NC} To exit Ubuntu, type 'exit'"
echo ""

# 12. Offer auto-start option to user
echo ""
# If running via pipe, enable auto-start by default
if [ "$PIPED_INPUT" = true ]; then
    auto_start="y"
    info "Default choice: Auto-start enabled."
else
    read -p "Would you like to automatically start Ubuntu every time Termux opens? (This option also adds the Ubuntu logo) (y/n): " auto_start
fi

if [ "$auto_start" = "y" ] || [ "$auto_start" = "Y" ]; then
    info "Configuring auto-start setting..."

    # Check .bashrc file
    BASHRC_FILE="$HOME/.bashrc"

    # Add if not already added
    if ! grep -q "start-ubuntu.sh" "$BASHRC_FILE" 2>/dev/null; then
        # Add logo and auto-start
        cat >> "$BASHRC_FILE" << 'BASHRC_EOF'
# Ubuntu logo and auto-start
if [ -f "$HOME/start-ubuntu.sh" ]; then
    ORANGE='\033[38;5;208m'
    RESET='\033[0m'
    clear
    echo ""
    echo -e "${ORANGE}"
    echo "  _   _  _                  _          "
    echo " | | | || |                | |         "
    echo " | | | || |__   _   _ _ __ | |_  _   _ "
    echo " | | | ||  _ \ | | | |  _ \|  _|| | | |"
    echo " | |_| || |_) || |_| | | | | |_ | |_| |"
    echo "  \___/ |____/  \____|_| |_|\__| \____|"
    echo ""
    echo -e "${RESET}"
    ./start-ubuntu.sh
fi
BASHRC_EOF
        info "Auto-start setting added"
        info "Ubuntu will start automatically every time you open Termux"
        echo ""
        echo -e "${YELLOW}Note:${NC} To disable auto-start:"
        echo "  nano ~/.bashrc"
        echo "  (Delete the Ubuntu auto-start section at the end)"
    else
        warn "Auto-start already configured"
    fi

    # Start now
    echo ""
    # If running via pipe, don't start now
    if [ "$PIPED_INPUT" = true ]; then
        start_now="n"
        info "Script completed. Ubuntu will start automatically when you close and reopen Termux."
        info "(Don't forget to run the command: bash /root/first-setup.sh in your Ubuntu session!)"
    else
        read -p "Would you like to start Ubuntu now? (y/n): " start_now
        if [ "$start_now" = "y" ] || [ "$start_now" = "Y" ]; then
            info "Starting Ubuntu..."
            exec "$SCRIPT_DIR/start-ubuntu.sh"
        else
            info "Script completed. Ubuntu will start automatically when you close and reopen Termux."
            info "(Don't forget to run the command: bash /root/first-setup.sh in your Ubuntu session!)"
        fi
    fi
else
    info "Auto-start not configured"

    # 13. Offer user option to start Ubuntu
    echo ""
    # If running via pipe, don't start now
    if [ "$PIPED_INPUT" = true ]; then
        start_ubuntu="n"
        info "Script completed. Happy coding!"
        echo ""
        echo -e "${GREEN}To start Ubuntu:${NC}"
        echo "  ./start-ubuntu.sh"
    else
        read -p "Would you like to start Ubuntu now? (y/n): " start_ubuntu
        if [ "$start_ubuntu" = "y" ] || [ "$start_ubuntu" = "Y" ]; then
            info "Starting Ubuntu..."
            exec "$SCRIPT_DIR/start-ubuntu.sh"
        else
            info "Script completed. Happy coding!"
            info "(Don't forget to run the command: bash /root/first-setup.sh in your Ubuntu session!)"
            echo ""
            echo -e "${GREEN}To start Ubuntu:${NC}"
            echo "  ./start-ubuntu.sh"
        fi
    fi
fi
