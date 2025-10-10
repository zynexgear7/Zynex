#!/bin/bash set -euo pipefail

=============================

Zynex Full Optimized VM Manager

=============================

VM_DIR="$HOME/vms" BRIDGE_NAME="br0"  # Low-ping Minecraft networking

Display header

display_header() { clear cat << "EOF"


---

_________
       /
      /
    /
    __________
POWERED BY ZYNEX

======================================================================== EOF echo }

Colored messages

print_status() { local type=$1 local message=$2 case $type in "INFO") echo -e "\033[1;34m[INFO]\033[0m $message" ;; "WARN") echo -e "\033[1;33m[WARN]\033[0m $message" ;; "ERROR") echo -e "\033[1;31m[ERROR]\033[0m $message" ;; "SUCCESS") echo -e "\033[1;32m[SUCCESS]\033[0m $message" ;; "INPUT") echo -e "\033[1;36m[INPUT]\033[0m $message" ;; *) echo "[$type] $message" ;; esac }

Input validation

validate_input() { local type=$1 local value=$2 case $type in "number") [[ "$value" =~ ^[0-9]+$ ]] || { print_status ERROR "Must be a number"; return 1; } ;; "size") [[ "$value" =~ ^[0-9]+[GgMm]$ ]] || { print_status ERROR "Must be a size (e.g., 20G)"; return 1; } ;; "port") [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -ge 23 ] && [ "$value" -le 65535 ] || { print_status ERROR "Port 23-65535 required"; return 1; } ;; "name") [[ "$value" =~ ^[a-zA-Z0-9_-]+$ ]] || { print_status ERROR "Invalid name"; return 1; } ;; "username") [[ "$value" =~ ^[a-z_][a-z0-9_-]*$ ]] || { print_status ERROR "Invalid username"; return 1; } ;; esac }

Check dependencies

check_dependencies() { local deps=(qemu-system-x86_64 wget cloud-localds qemu-img openssl) for dep in "${deps[@]}"; do command -v $dep >/dev/null || { print_status ERROR "$dep not installed"; exit 1; } done }

Cleanup

cleanup() { rm -f user-data meta-data 2>/dev/null || true; }

Load VM config

load_vm_config() { local vm_name=$1; local file="$VM_DIR/$vm_name.conf"; [[ -f $file ]] && source "$file" || { print_status ERROR "VM $vm_name not found"; return 1; }; }

Save VM config

save_vm_config() { mkdir -p "$VM_DIR" local file="$VM_DIR/$VM_NAME.conf" cat > "$file" <<EOF VM_NAME="$VM_NAME" OS_TYPE="$OS_TYPE" HOSTNAME="$HOSTNAME" USERNAME="$USERNAME" PASSWORD="$PASSWORD" DISK_SIZE="$DISK_SIZE" MEMORY="$MEMORY" CPUS="$CPUS" SSH_PORT="$SSH_PORT" GUI_MODE="$GUI_MODE" PORT_FORWARDS="$PORT_FORWARDS" IMG_FILE="$IMG_FILE" SEED_FILE="$SEED_FILE" CREATED="$CREATED" EOF print_status SUCCESS "Saved config $file" }

Setup VM image

setup_vm_image() { mkdir -p "$VM_DIR" IMG_FILE="$VM_DIR/$VM_NAME.img" SEED_FILE="$VM_DIR/$VM_NAME-seed.iso" CREATED="$(date)" [[ -f $IMG_FILE ]] || wget -O "$IMG_FILE.tmp" "$IMG_URL" && mv "$IMG_FILE.tmp" "$IMG_FILE" qemu-img resize "$IMG_FILE" "$DISK_SIZE" 2>/dev/null || true

# Cloud-init
cat > user-data <<EOF

#cloud-config hostname: $HOSTNAME ssh_pwauth: true disable_root: false users:

name: $USERNAME sudo: ALL=(ALL) NOPASSWD:ALL shell: /bin/bash password: $(openssl passwd -6 "$PASSWORD" | tr -d '\n') chpasswd: list: | root:$PASSWORD $USERNAME:$PASSWORD expire: false EOF

cat > meta-data <<EOF instance-id: iid-$VM_NAME local-hostname: $HOSTNAME EOF

cloud-localds "$SEED_FILE" user-data meta-data cleanup print_status SUCCESS "VM '$VM_NAME' prepared" }


Start VM (low-ping Minecraft)

start_vm() { load_vm_config "$1" print_status INFO "Starting $VM_NAME with low-ping bridged networking" qemu-system-x86_64 -enable-kvm -m "$MEMORY" -smp "$CPUS" -cpu host 
-drive "file=$IMG_FILE,format=qcow2,if=virtio" -drive "file=$SEED_FILE,format=raw,if=virtio" 
-boot order=c -device virtio-net-pci,netdev=n0 -netdev bridge,id=n0,br=$BRIDGE_NAME 
-vga virtio -display gtk,gl=on -device virtio-balloon-pci 
-object rng-random,filename=/dev/urandom,id=rng0 -device virtio-rng-pci,rng=rng0 print_status INFO "VM $VM_NAME stopped" }

Delete VM

delete_vm() { local vm_name=$1 load_vm_config "$vm_name" || return print_status WARN "Deleting VM '$vm_name' permanently!" read -p "Are you sure? (y/N): " confirm [[ $confirm =~ ^[Yy]$ ]] || return rm -f "$IMG_FILE" "$SEED_FILE" "$VM_DIR/$vm_name.conf" print_status SUCCESS "VM '$vm_name' deleted" }

Edit VM

edit_vm() { local vm_name=$1 load_vm_config "$vm_name" || return echo "Edit options: 1) Memory 2) CPU 3) Disk 4) SSH Port 5) GUI 6) Back" read -p "Choice: " opt case $opt in 1) read -p "Memory MB ($MEMORY): " MEMORY ;; 2) read -p "CPUs ($CPUS): " CPUS ;; 3) read -p "Disk Size ($DISK_SIZE): " DISK_SIZE ;; 4) read -p "SSH Port ($SSH_PORT): " SSH_PORT ;; 5) read -p "GUI y/n ($GUI_MODE): " gui; GUI_MODE=$([[ $gui =~ ^[Yy]$ ]] && echo true || echo false) ;; *) return ;; esac save_vm_config }

List VMs

list_vms() { ls "$VM_DIR"/*.conf 2>/dev/null | xargs -n1 basename | sed 's/.conf$//' }

Main menu

display_header check_dependencies while true; do echo "\n1) Create VM" echo "2) Start VM" echo "3) Delete VM" echo "4) Edit VM" echo "5) List VMs" echo "6) Exit" read -p "Choice: " choice case $choice in 1) read -p "VM Name: " VM_NAME read -p "OS Image URL: " IMG_URL read -p "Username: " USERNAME read -s -p "Password: " PASSWORD; echo read -p "Disk Size (e.g., 20G): " DISK_SIZE read -p "Memory MB: " MEMORY read -p "CPUs: " CPUS read -p "SSH Port: " SSH_PORT read -p "GUI y/n: " gui GUI_MODE=$([[ $gui =~ ^[Yy]$ ]] && echo true || echo false) HOSTNAME=$VM_NAME PORT_FORWARDS="" setup_vm_image save_vm_config ;; 2) read -p "VM Name to start: " vm start_vm "$vm" ;; 3) read -p "VM Name to delete: " vm delete_vm "$vm" ;; 4) read -p "VM Name to edit: " vm edit_vm "$vm" ;; 5) echo "Available VMs:" list_vms ;; 6) exit 0 ;; *) echo "Invalid choice";; esac echo done

