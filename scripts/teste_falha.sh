#!/usr/bin/env bash
# Teste de falha controlada: executa um comando que falha de propósito
# para provar que o erro é registrado no log de auditoria.
# Uso: sudo bash scripts/teste_falha.sh

set -euo pipefail
source "$(dirname "$0")/common.sh"

exigir_root
preparar_logs
trap 'log ERRO "Falha na linha $LINENO: o comando \"$BASH_COMMAND\" falhou"' ERR

log INFO "Início do teste de falha controlada"
log INFO "Tentando ler um arquivo de configuração que não existe..."
cat /etc/citizentech/arquivo_inexistente.conf
log INFO "Esta linha nunca deve aparecer no log"