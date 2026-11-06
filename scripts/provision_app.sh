#!/usr/bin/env bash
# Provisionamento da aplicação: dependências, usuário, variáveis,
# serviço systemd, Nginx e firewall.
# Uso: sudo bash scripts/provision_app.sh

set -euo pipefail
source "$(dirname "$0")/common.sh"

exigir_root
preparar_logs
trap 'log ERRO "Falha na linha $LINENO"' ERR

log INFO "Início do provisionamento da aplicação"
APP_DIR="$INSTALL_DIR/app"

# --- 1. Dependências do sistema ---
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq python3 python3-venv nginx ufw curl > /dev/null
log INFO "Dependências instaladas: python3, venv, nginx, ufw, curl"

# --- 2. Usuário de sistema (a app não roda como root) ---
if ! id "$APP_USER" &> /dev/null; then
  useradd --system --no-create-home --shell /usr/sbin/nologin "$APP_USER"
  log INFO "Usuário de sistema criado: $APP_USER"
fi

# --- 3. Código da aplicação + ambiente virtual Python ---
mkdir -p "$APP_DIR"
cp -r "$REPO_DIR/app/." "$APP_DIR/"
python3 -m venv "$APP_DIR/venv"
"$APP_DIR/venv/bin/pip" install -q -r "$APP_DIR/requirements.txt"
chown -R "$APP_USER:$APP_USER" "$APP_DIR"
log INFO "Aplicação instalada em $APP_DIR"

# --- 4. Variáveis de ambiente da aplicação ---
mkdir -p /etc/citizentech
cat > /etc/citizentech/app.env <<EOF
APP_NAME="$APP_NAME"
CIDADE="$CIDADE"
LATITUDE="$LATITUDE"
LONGITUDE="$LONGITUDE"
EOF
chown root:"$APP_USER" /etc/citizentech/app.env
chmod 640 /etc/citizentech/app.env
log INFO "Variáveis de ambiente gravadas em /etc/citizentech/app.env"

# --- 5. Serviço systemd da aplicação ---
cp "$REPO_DIR/systemd/citizentech-app.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable citizentech-app.service > /dev/null 2>&1
systemctl restart citizentech-app.service
log INFO "Serviço citizentech-app ativado e iniciado"

# --- 6. Nginx (proxy reverso na porta 80) ---
cp "$REPO_DIR/nginx/citizentech.conf" /etc/nginx/sites-available/citizentech
ln -sf /etc/nginx/sites-available/citizentech /etc/nginx/sites-enabled/citizentech
rm -f /etc/nginx/sites-enabled/default
nginx -t > /dev/null 2>&1
systemctl reload nginx
log INFO "Nginx configurado como proxy reverso"

# --- 7. Firewall: libera só SSH e HTTP ---
ufw allow OpenSSH > /dev/null
ufw allow 'Nginx HTTP' > /dev/null
ufw --force enable > /dev/null
log INFO "Firewall ativo: liberados SSH (22) e HTTP (80)"

# --- 8. Teste: a aplicação responde? ---
for tentativa in {1..10}; do
  if curl -fsS http://localhost/health > /dev/null 2>&1; then
    log INFO "Aplicação respondendo em http://localhost (tentativa $tentativa)"
    log INFO "Provisionamento da aplicação concluído"
    exit 0
  fi
  sleep 2
done
log ERRO "Aplicação não respondeu ao teste de saúde"
exit 1