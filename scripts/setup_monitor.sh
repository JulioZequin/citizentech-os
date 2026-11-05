#!/usr/bin/env bash
# Instala o monitoramento como serviço do systemd.
# Uso: sudo bash scripts/setup_monitor.sh

set -euo pipefail
source "$(dirname "$0")/common.sh"

exigir_root
preparar_logs
trap 'log ERRO "Falha na linha $LINENO"' ERR

log INFO "Início da instalação do monitoramento"

# Copia os arquivos para a pasta fixa de instalação
mkdir -p "$INSTALL_DIR/scripts"
cp "$REPO_DIR/config.env" "$INSTALL_DIR/"
cp "$REPO_DIR/scripts/common.sh" "$REPO_DIR/scripts/monitor.sh" "$INSTALL_DIR/scripts/"
log INFO "Scripts copiados para $INSTALL_DIR"

# Instala o serviço no systemd e ativa no boot
cp "$REPO_DIR/systemd/citizentech-monitor.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable citizentech-monitor.service > /dev/null 2>&1
systemctl restart citizentech-monitor.service
log INFO "Serviço citizentech-monitor ativado e iniciado"

log INFO "Instalação do monitoramento concluída"