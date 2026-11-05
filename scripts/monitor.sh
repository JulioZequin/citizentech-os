#!/usr/bin/env bash
# Monitora CPU, memória e disco e gera alertas acima dos limites.
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

registrar INFO "Monitoramento iniciado (intervalo ${MONITOR_INTERVAL}s)"

while true; do
  cpu=$(cpu_uso)
  mem=$(mem_uso)
  disco=$(disco_uso)

  registrar STATUS "CPU=${cpu}% MEM=${mem}% DISCO=${disco}%"
  verificar CPU     "$cpu"   "$LIMITE_CPU"
  verificar MEMORIA "$mem"   "$LIMITE_MEM"
  verificar DISCO   "$disco" "$LIMITE_DISCO"

  sleep "$MONITOR_INTERVAL"
done