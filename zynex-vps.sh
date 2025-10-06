#!/bin/bash
set -euo pipefail

# =============================
# 🚀 ZYNEX VPS MANAGER
# =============================

# Colors
cyan="\033[1;36m"
yellow="\033[1;33m"
green="\033[1;32m"
red="\033[1;31m"
magenta="\033[1;35m"
reset="\033[0m"

# VM directory
VM_DIR="$HOME/ZynexVMs"
mkdir -p "$VM_DIR"

# ----------------------------
# Display ZYNEX Logo
# ----------------------------
display_logo() {
    clear
    echo -e "${cyan}"
    echo "/$$$$$$$$       /$$     /$$       /$$   /$$       /$$$$$$$$       /$$   /$$"
    echo "|_____ $$       |  $$   /$$/      | $$$ | $$      | $$_____/      | $$  / $$"
    echo "     /$$/        \  $$ /$$/       | $$$$| $$      | $$            |  $$/ $$/"
    echo "    /$$/          \  $$$$/        | $$ $$ $$      | $$$$$          \  $$$$/ "
    echo "   /$$/            \  $$/         | $$  $$$$      | $$__/           >$$  $$ "
    echo "  /$$/              | $$          | $$\  $$$      | $$             /$$/\  $$"
    echo " /$$$$$$$$          | $$          | $$ \  $$      | $$$$$$$$      | $$  \ $$"
    echo "|________/          |__/          |__/  \__/      |________/      |__/  |__/"
    echo -e "${yellow}"
    echo "        ⚡ ZYNEX VPS MANAGER ⚡${reset}"
    echo -e "${green}            Powered by ZYNEX CODE${reset}"
    echo
}

# ----------------------------
# Utility functions
# ----------------------------
print_status() {
    local type=$1
    local message=$2
    case $type in
        "INFO") echo -e "${cyan}[INFO]${reset} $message" ;;
        "WARN") echo -e "${yellow}[WARN]${reset} $message" ;;
        "ERROR") echo -e "${red}[ERROR]${reset} $message" ;;
        "SUCCESS") echo -e "${green}[SUCCESS]${reset} $message" ;;
        "INPUT") echo -e "${magenta}[INPUT]${reset} $message" ;;
        *) echo "[$type] $message" ;;
    esac
}

validate_input() {
    local type=$1
    local val=$2
    case $type in
        number) [[ "$val" =~ ^[0-9]+$ ]] ;;
        size) [[ "$val" =~ ^[0-9]+[GgMm]$ ]] ;;
        port) [[ "$val" =~ ^[0-9]+$ ]] && [ "$val" -ge 23 ] && [ "$val" -le 65535 ] ;;
        name) [[ "$val" =~ ^[a-zA-Z0-9_-]+$ ]] ;;
        username) [[ "$val" =~ ^[a-z_][a-z0-9_-]*$ ]] ;;
        *) return 1 ;;
    esac
}

# ----------------------------
# OS options
# ----------------------------
declare -A OS_OPTIONS
OS_OPTIONS["Debian"]="debian|bookworm|https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-genericcloud-amd64.qcow2|debian-vm|debian|debian"
OS_OPTIONS["Ubuntu"]="ubuntu|focal|https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img|ubuntu-vm|ubuntu|ubuntu"

# ----------------------------
# VM functions
# ----------------------------
list_vms() {
    find "$VM_DIR" -maxdepth 1 -name "*.conf" -exec basename {} .conf \; 2>/dev/null
}

load_vm_config() {
    local vm="$1"
    local cfg="$VM_DIR/$vm.conf"
    if [[ -f "$cfg" ]]; then
        source "$cfg"
        return 0
    else
        print_status "ERROR" "VM config $vm not found"
        return 1
    fi
}

save_vm_config() {
    local cfg="$VM_DIR/$VM_NAME.conf"
    cat > "$cfg" <<EOF
VM_NAME="$VM_NAME"
OS_TYPE="$OS_TYPE"
CODENAME="$CODENAME"
IMG_URL="$IMG_URL"
HOSTNAME="$HOSTNAME"
USERNAME="$USERNAME"
PASSWORD="$PASSWORD"
DISK_SIZE="$DISK_SIZE"
MEMORY="$MEMORY"
CPUS="$CPUS"
SSH_PORT="$SSH_PORT"
GUI_MODE="$GUI_MODE"
IMG_FILE="$IMG_FILE"
SEED_FILE="$SEED_FILE"
CREATED="$CREATED"
EOF
    print_status "SUCCESS" "Saved config for $VM_NAME"
}

setup_vm_image() {
    print_status "INFO" "Setting up VM image..."
    IMG_FILE="$VM_DIR/$VM_NAME.img"
    SEED_FILE="$VM_DIR/$VM_NAME-seed.iso"

    if [[ ! -f "$IMG_FILE" ]]; then
        print_status "INFO" "Downloading VM image..."
        wget -O "$IMG_FILE" "$IMG_URL"
    fi

    # cloud-init
    cat > user-data <<EOF
#cloud-config
hostname: $HOSTNAME
ssh_pwauth: true
disable_root: false
users:
  - name: $USERNAME
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    password: $(openssl passwd -6 "$PASSWORD" | tr -d '\n')
chpasswd:
  list: |
    root:$PASSWORD
    $USERNAME:$PASSWORD
  expire: false
EOF

    cat > meta-data <<EOF
instance-id: iid-$VM_NAME
local-hostname: $HOSTNAME
EOF

    cloud-localds "$SEED_FILE" user-data meta-data
}

create_vm() {
    print_status "INFO" "Creating new VM..."
    echo "Select OS:"
    local i=1
    for os in "${!OS_OPTIONS[@]}"; do
        echo "  $i) $os"
        os_list[$i]="$os"
        ((i++))
    done
    while true; do
        read -p "$(print_status "INPUT" "Choose OS: ")" choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#OS_OPTIONS[@]} ]; then
            OS_NAME="${os_list[$choice]}"
            IFS='|' read -r OS_TYPE CODENAME IMG_URL DEFAULT_HOSTNAME DEFAULT_USERNAME DEFAULT_PASSWORD <<< "${OS_OPTIONS[$OS_NAME]}"
            break
        fi
    done

    read -p "$(print_status "INPUT" "VM Name (default: $DEFAULT_HOSTNAME): ")" VM_NAME
    VM_NAME="${VM_NAME:-$DEFAULT_HOSTNAME}"

    read -p "$(print_status "INPUT" "Hostname (default: $VM_NAME): ")" HOSTNAME
    HOSTNAME="${HOSTNAME:-$VM_NAME}"

    read -p "$(print_status "INPUT" "Username (default: $DEFAULT_USERNAME): ")" USERNAME
    USERNAME="${USERNAME:-$DEFAULT_USERNAME}"

    read -s -p "$(print_status "INPUT" "Password (default: $DEFAULT_PASSWORD): ")" PASSWORD
    PASSWORD="${PASSWORD:-$DEFAULT_PASSWORD}"
    echo

    read -p "$(print_status "INPUT" "Disk size (default: 20G): ")" DISK_SIZE
    DISK_SIZE="${DISK_SIZE:-20G}"

    read -p "$(print_status "INPUT" "Memory in MB (default: 2048): ")" MEMORY
    MEMORY="${MEMORY:-2048}"

    read -p "$(print_status "INPUT" "CPU count (default: 2): ")" CPUS
    CPUS="${CPUS:-2}"

    read -p "$(print_status "INPUT" "SSH port (default: 2222): ")" SSH_PORT
    SSH_PORT="${SSH_PORT:-2222}"

    read -p "$(print_status "INPUT" "Enable GUI? (y/n, default: n): ")" GUI_MODE
    GUI_MODE="${GUI_MODE:-n}"

    CREATED="$(date)"
    setup_vm_image
    save_vm_config
    print_status "SUCCESS" "VM $VM_NAME created!"
}

start_vm() {
    read -p "$(print_status "INPUT" "Enter VM name to start: ")" vm
    load_vm_config "$vm" || return
    print_status "INFO" "Starting VM $VM_NAME..."
    qemu-system-x86_64 -enable-kvm -m "$MEMORY" -smp "$CPUS" \
        -drive "file=$IMG_FILE,format=qcow2,if=virtio" \
        -drive "file=$SEED_FILE,format=raw,if=virtio" \
        -boot order=c -netdev "user,id=n0,hostfwd=tcp::$SSH_PORT-:22" \
        -device virtio-net-pci,netdev=n0 \
        $([[ "$GUI_MODE" == "y" ]] && echo "-vga virtio -display gtk,gl=on" || echo "-nographic -serial mon:stdio")
}

delete_vm() {
    read -p "$(print_status "INPUT" "Enter VM name to delete: ")" vm
    load_vm_config "$vm" || return
    rm -f "$IMG_FILE" "$SEED_FILE" "$VM_DIR/$VM_NAME.conf"
    print_status "SUCCESS" "VM $VM_NAME deleted!"
}

list_vms_menu() {
    echo -e "${yellow}Available VMs:${reset}"
    list_vms
}

# ----------------------------
# Main menu loop
# ----------------------------
while true; do
    display_logo
    echo "1) Create VM"
    echo "2) Start VM"
    echo "3) Delete VM"
    echo "4) List VMs"
    echo "5) Exit"
    read -p "$(print_status "INPUT" "Choose an option: ")" choice
    case $choice in
        1) create_vm ;;
        2) start_vm ;;
        3) delete_vm ;;
        4) list_vms_menu ;;
        5) exit 0 ;;
        *) print_status "ERROR" "Invalid choice" ;;
    esac
done
