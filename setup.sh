#!/usr/bin/env bash
# Provisionamento completo do servidor CitizenTech.
# Uso: sudo bash setup.sh
# A rede é aplicada por último porque muda o IP e derruba o SSH.

set -euo pipefail
cd "$(dirname "$0")"

if [[ $EUID -ne 0 ]]; then
  echo "Erro: execute com sudo bash setup.sh"
  exit 1
fi

chronyc makestep > /dev/null 2>&1 || true
sleep 2

# Fuso horário primeiro, para todos os logs ficarem no horário local
source config.env
timedatectl set-timezone "$TIMEZONE"

echo "=== 1/3 Aplicação ==="
bash scripts/provision_app.sh

echo "=== 2/3 Monitoramento ==="
bash scripts/setup_monitor.sh

echo "=== 3/3 Infraestrutura (rede) ==="
bash scripts/provision_infra.sh