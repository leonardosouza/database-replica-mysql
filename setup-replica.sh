#!/bin/bash
set -euo pipefail

LOG_FILE="/tmp/replica-setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

wait_for_mysql() {
  local host="$1"
  local port="$2"
  local pass="$3"
  local max_attempts=30
  local attempt=1
  while ! mysqladmin ping -h "$host" -P "$port" -uroot -p"$pass" --silent; do
    if (( attempt >= max_attempts )); then
      log "ERRO: MySQL em $host:$port não respondeu após $max_attempts tentativas. Abortando."
      exit 1
    fi
    log "Aguardando MySQL em $host:$port... (tentativa $attempt)"
    sleep 2
    ((attempt++))
  done
  log "MySQL em $host:$port está pronto."
}

MYSQL_MASTER_HOST="127.0.0.1"
MYSQL_SLAVE_HOST="127.0.0.1"
MYSQL_MASTER_PORT=3306
MYSQL_SLAVE_PORT=3307
MYSQL_ROOT_PASS="rootpass"

log "Aguardando master e slave estarem prontos..."
wait_for_mysql "$MYSQL_MASTER_HOST" "$MYSQL_MASTER_PORT" "$MYSQL_ROOT_PASS"
wait_for_mysql "$MYSQL_SLAVE_HOST" "$MYSQL_SLAVE_PORT" "$MYSQL_ROOT_PASS"

# Sleep extra para garantir que o MySQL está 100% operacional
log "Aguardando 10 segundos extras para garantir que o MySQL está pronto para comandos SQL..."
sleep 10

log "[1/3] Criando usuário de replicação no master..."
docker exec mysql-master mysql -uroot -p"$MYSQL_ROOT_PASS" -e "\
CREATE USER IF NOT EXISTS 'repl'@'%' IDENTIFIED WITH mysql_native_password BY 'replpass';\
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';\
FLUSH PRIVILEGES;" || { log "ERRO ao criar usuário de replicação no master."; exit 1; }

log "[2/3] Capturando status do master..."
MASTER_STATUS=$(docker exec mysql-master mysql -uroot -p"$MYSQL_ROOT_PASS" -e "SHOW MASTER STATUS;") || { log "ERRO ao capturar status do master."; exit 1; }
echo "$MASTER_STATUS"
MASTER_LOG_FILE=$(echo "$MASTER_STATUS" | awk 'NR==2 {print $1}')
MASTER_LOG_POS=$(echo "$MASTER_STATUS" | awk 'NR==2 {print $2}')

if [ -z "$MASTER_LOG_FILE" ] || [ -z "$MASTER_LOG_POS" ]; then
  log "Erro ao capturar File e Position do master. Verifique se o master está configurado corretamente."
  exit 1
fi

log "MASTER_LOG_FILE: $MASTER_LOG_FILE"
log "MASTER_LOG_POS: $MASTER_LOG_POS"

log "[3/3] Configurando o slave..."
docker exec mysql-slave mysql -uroot -p"$MYSQL_ROOT_PASS" -e "\
STOP SLAVE;\
CHANGE MASTER TO\
  MASTER_HOST='mysql-master',\
  MASTER_USER='repl',\
  MASTER_PASSWORD='replpass',\
  MASTER_LOG_FILE='$MASTER_LOG_FILE',\
  MASTER_LOG_POS=$MASTER_LOG_POS;\
START SLAVE;\
SHOW SLAVE STATUS\\G" || { log "ERRO ao configurar o slave."; exit 1; }

log "Replica configurada! Verifique o status acima para garantir que tudo está OK."