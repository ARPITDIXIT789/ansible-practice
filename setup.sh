#!/usr/bin/env bash
# Ansible quick setup for iximiuz / any Ubuntu-Debian playground
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "[1/5] Ansible install check..."
if ! command -v ansible >/dev/null 2>&1; then
  sudo apt-get update -y
  if ! sudo apt-get install -y ansible python3-pip sshpass git; then
    echo "apt fail hua, pip se install kar raha hoon..."
    sudo apt-get install -y python3-pip git || true
    python3 -m pip install --user --break-system-packages ansible \
      || python3 -m pip install --user ansible
    export PATH="$PATH:$HOME/.local/bin"
  fi
else
  echo "Ansible already installed."
fi

echo "[2/5] Python kubernetes library + collections..."
python3 -m pip install --user --break-system-packages kubernetes 2>/dev/null \
  || python3 -m pip install --user kubernetes || true
ansible-galaxy collection install kubernetes.core community.general ansible.posix

echo "[3/5] ansible.cfg bana raha hoon..."
cat > ansible.cfg << 'CFG'
[defaults]
inventory = ./inventory.ini
host_key_checking = False
interpreter_python = auto_silent
retry_files_enabled = False
stdout_callback = yaml

[privilege_escalation]
become = False
CFG

echo "[4/5] inventory.ini generate kar raha hoon..."
if command -v kubectl >/dev/null 2>&1 && kubectl get nodes >/dev/null 2>&1; then
  CP=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[*].metadata.name}')
  WK=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[*].metadata.name}')
  {
    echo "[controlplane]"; for n in $CP; do echo "$n"; done
    echo; echo "[workers]";  for n in $WK; do echo "$n"; done
    echo; echo "[k8s:children]"; echo "controlplane"; echo "workers"
    echo; echo "[all:vars]"
    echo "ansible_user=$(whoami)"
    echo "ansible_ssh_common_args='-o StrictHostKeyChecking=no'"
  } > inventory.ini
else
  echo "kubectl nahi mila, default inventory bana raha hoon (nodes edit kar lena)."
  cat > inventory.ini << 'INV'
[controlplane]
cplane-01

[workers]
node-01
node-02

[k8s:children]
controlplane
workers

[all:vars]
ansible_user=laborant
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
INV
fi

echo "[5/5] Connectivity test..."
ansible --version | head -n 1
ansible all -m ping || echo "Ping fail: SSH check karo (ssh node-01 hostname)"

echo "Done. Ab chalao: ansible-playbook first-playbook.yml"
