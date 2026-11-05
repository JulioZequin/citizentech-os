#!/usr/bin/env bash
# Funções compartilhadas por todos os scripts do projeto.

# Descobre a pasta raiz do repositório e carrega as configurações
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_DIR/config.env"

AUDIT_LOG="$LOG_DIR/auditoria.log"

# Escreve uma linha na tela e no log de auditoria.
# Uso: log INFO "mensagem"
log() {
  local nivel="$1"; shift
  local linha
  linha="$(date '+%Y-%m-%d %H:%M:%S') [$nivel] [$(basename "$0")] [usuario=${SUDO_USER:-$USER}] $*"
  echo "$linha"
  echo "$linha" >> "$AUDIT_LOG"
}

# Interrompe o script se não estiver rodando com sudo
exigir_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "Erro: execute com sudo."
    exit 1
  fi
}

# Cria a pasta e o arquivo de log, se ainda não existirem
preparar_logs() {
  mkdir -p "$LOG_DIR"
  touch "$AUDIT_LOG"
  chmod 640 "$AUDIT_LOG"
}