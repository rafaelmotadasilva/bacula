#!/bin/bash
# Bacula → Zabbix notification script
# Called via RunScript after each backup job (success and failure)
# Args: %i (JobID) %l (Level) %b (Bytes) %f (Files)

JOBID="$1"
LEVEL="$2"
BYTES="${3:-0}"
FILES="${4:-0}"

# ── Configuração ─────────────────────────────────────────────────
ZABBIX_HOST="bacula-fd"          # Nome técnico do host no Zabbix
ZABBIX_SERVER="127.0.0.1"        # IP ou hostname do Zabbix Server
LOGFILE="/var/log/bacula-zabbix.log"

# Credenciais do PostgreSQL (catalog do Bacula)
PG_HOST="127.0.0.1"
PG_USER="bacula"
PG_DB="bacula"
PGPASS="sua_senha_aqui"
# ─────────────────────────────────────────────────────────────────

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [bacula-zabbix] $*" >> "$LOGFILE"; }

# Processar apenas backups reais (ignorar restore, verify, etc.)
if [[ "$LEVEL" != "Full" && "$LEVEL" != "Differential" && "$LEVEL" != "Incremental" ]]; then
    exit 0
fi

case "$LEVEL" in
    "Full")         ITEM="bacula.full.job.status" ;;
    "Differential") ITEM="bacula.diff.job.status" ;;
    "Incremental")  ITEM="bacula.incr.job.status" ;;
esac

# Consultar nome e status do job no catálogo
DBINFO=$(PGPASSWORD="$PGPASS" psql -h "$PG_HOST" -U "$PG_USER" -d "$PG_DB" -t -A -F'|' \
    -c "SELECT name, jobstatus FROM job WHERE jobid=$JOBID LIMIT 1;" 2>/dev/null)
JOBNAME=$(echo "$DBINFO" | cut -d'|' -f1)
JOBSTATUS=$(echo "$DBINFO" | cut -d'|' -f2)

# Mapear status → valor numérico
# T=OK, C=OK com avisos, qualquer outro=FALHOU
case "$JOBSTATUS" in
    "T") VALUE=0; STATUS_TEXT="OK" ;;
    "C") VALUE=1; STATUS_TEXT="OK (com avisos)" ;;
    *)   VALUE=2; STATUS_TEXT="FALHOU ($JOBSTATUS)" ;;
esac

log "Job $JOBID [$JOBNAME] Level=$LEVEL Status=$JOBSTATUS -> $ITEM=$VALUE (${FILES} arqs, ${BYTES} bytes)"

# Em caso de falha: enviar texto detalhado ANTES do status numérico
# O item bacula.job.lastfail é usado nas expressões dos triggers do Zabbix
if [ "$VALUE" -gt 0 ]; then
    DETAIL="JobID ${JOBID}: ${JOBNAME} (${LEVEL}) - ${STATUS_TEXT} - Arquivos: ${FILES} - Bytes: ${BYTES}"
    /usr/bin/zabbix_sender -z "$ZABBIX_SERVER" -s "$ZABBIX_HOST" -k "bacula.job.lastfail" -o "$DETAIL" >> "$LOGFILE" 2>&1
    log "Detalhe enviado: $DETAIL"
    sleep 1
fi

# Enviar status numérico (dispara trigger e notificação no Zabbix)
/usr/bin/zabbix_sender -z "$ZABBIX_SERVER" -s "$ZABBIX_HOST" -k "$ITEM" -o "$VALUE" >> "$LOGFILE" 2>&1

exit 0
