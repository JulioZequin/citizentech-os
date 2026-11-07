#!/usr/bin/env bash
# Monitora CPU, memória e disco, verifica se a aplicação e seus serviços
# estão no ar, gera alertas e recupera serviços parados.
# Roda em loop como serviço do systemd (citizentech-monitor.service).

set -u
source "$(dirname "$0")/common.sh"

MONITOR_LOG="$LOG_DIR/monitor.log"
mkdir -p "$LOG_DIR"

# Escreve no arquivo de log e na saída (que vai para o journal do systemd)
registrar() {
  local nivel="$1"; shift
  local linha
  linha="$(date '+%Y-%m-%d %H:%M:%S') [$nivel] $*"
  echo "$linha"
  echo "$linha" >> "$MONITOR_LOG"
}

# Uso de CPU em %: compara duas leituras do /proc/stat com 1s de intervalo
cpu_uso() {
  local u n s i w q sq st
  read -r _ u n s i w q sq st _ < /proc/stat
  local total1=$((u+n+s+i+w+q+sq+st)) ocioso1=$((i+w))
  sleep 1
  read -r _ u n s i w q sq st _ < /proc/stat
  local total2=$((u+n+s+i+w+q+sq+st)) ocioso2=$((i+w))
  local dt=$((total2-total1)) di=$((ocioso2-ocioso1))
  echo $(( 100 * (dt - di) / dt ))
}

# Uso de memória em %: (total - disponível) / total
mem_uso() {
  free | awk '/^Mem:/ { printf "%d", (($2 - $7) / $2) * 100 }'
}

# Memória disponível em MB
mem_livre_mb() {
  free -m | awk '/^Mem:/ { print $7 }'
}

# Uso do disco principal (/) em %
disco_uso() {
  df --output=pcent / | tail -1 | tr -dc '0-9'
}

# Gera um ALERTA se o valor passar do limite
verificar() {
  local nome="$1" valor="$2" limite="$3"
  if (( valor >= limite )); then
    registrar ALERTA "$nome em ${valor}% (limite ${limite}%)"
  fi
}

# Verifica se a aplicação responde pela web
verificar_aplicacao() {
  if ! curl -fsS --max-time 5 "$URL_SAUDE" > /dev/null 2>&1; then
    registrar FALHA "Aplicação não respondeu em $URL_SAUDE"
  fi
}

# Verifica cada serviço; se estiver parado, registra a falha e tenta recuperar
verificar_servicos() {
  local servico
  for servico in $SERVICOS_MONITORADOS; do
    if ! systemctl is-active --quiet "$servico"; then
      registrar FALHA "Serviço $servico está parado"
      if systemctl start "$servico"; then
        registrar RECUPERACAO "Serviço $servico reiniciado com sucesso"
      else
        registrar ERRO "Não foi possível reiniciar o serviço $servico"
      fi
    fi
  done
}

registrar INFO "Monitoramento iniciado (intervalo ${MONITOR_INTERVAL}s)"

while true; do
  cpu=$(cpu_uso)
  mem=$(mem_uso)
  livre=$(mem_livre_mb)
  disco=$(disco_uso)

  registrar STATUS "CPU=${cpu}% MEM=${mem}% (livre ${livre}MB) DISCO=${disco}%"
  verificar CPU     "$cpu"   "$LIMITE_CPU"
  verificar MEMORIA "$mem"   "$LIMITE_MEM"
  verificar DISCO   "$disco" "$LIMITE_DISCO"

  verificar_aplicacao
  verificar_servicos

  sleep "$MONITOR_INTERVAL"
done