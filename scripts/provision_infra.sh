#!/usr/bin/env bash
# Provisionamento da infraestrutura: hostname, DNS e IP fixo.
# Uso: sudo bash scripts/provision_infra.sh

set -euo pipefail                      # para no primeiro erro
source "$(dirname "$0")/common.sh"

exigir_root
preparar_logs
trap 'log ERRO "Falha na linha $LINENO"' ERR   # registra erros no log

log INFO "Início do provisionamento da infraestrutura"

# --- 1. Hostname ---
hostnamectl set-hostname "$SERVER_HOSTNAME"
log INFO "Hostname definido: $SERVER_HOSTNAME"

# --- 1b. Fuso horário ---
timedatectl set-timezone "$TIMEZONE"
log INFO "Fuso horário definido: $TIMEZONE"

# --- 2. Resolução local de nomes (/etc/hosts) ---
# Remove linhas antigas do projeto para o script poder rodar várias vezes
sed -i '/# citizentech$/d' /etc/hosts
sed -i '/^127\.0\.1\.1/d' /etc/hosts
cat >> /etc/hosts <<EOF
127.0.1.1 $SERVER_HOSTNAME # citizentech
$STATIC_IP $SERVER_DOMAIN # citizentech
EOF
log INFO "/etc/hosts atualizado ($SERVER_DOMAIN -> $STATIC_IP)"

# --- 3. Servidores DNS ---
mkdir -p /etc/systemd/resolved.conf.d
cat > /etc/systemd/resolved.conf.d/citizentech.conf <<EOF
[Resolve]
DNS=${DNS_SERVERS//,/ }
EOF
systemctl restart systemd-resolved
log INFO "DNS configurado: $DNS_SERVERS"

# --- 4. IP fixo na interface Host-only (Netplan) ---
NETPLAN_FILE="/etc/netplan/60-citizentech.yaml"
cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  ethernets:
    $NET_INTERFACE:
      dhcp4: false
      addresses:
        - $STATIC_IP/$NETMASK_CIDR
EOF
chmod 600 "$NETPLAN_FILE"
netplan generate                       # valida o arquivo antes de aplicar
log INFO "Netplan configurado: $NET_INTERFACE = $STATIC_IP/$NETMASK_CIDR"

# Aplica a rede em 3 segundos, depois que o script terminar.
# A conexão SSH atual vai cair porque o IP muda.
systemd-run --on-active=3s /usr/sbin/netplan apply > /dev/null 2>&1
log AVISO "Rede será aplicada em 3s. Reconecte com: ssh ${SUDO_USER:-$USER}@$STATIC_IP"
log INFO "Provisionamento da infraestrutura concluído"