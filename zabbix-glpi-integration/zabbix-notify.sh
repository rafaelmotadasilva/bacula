#!/bin/bash
# Bacula → Zabbix notification script
# Called via RunScript after each backup job (success and failure)
# Args: %i (JobID) %l (Level) %b (Bytes) %f (Files)
#
# Each job gets its own Zabbix item and trigger via LLD discovery.
# The trigger for a specific job only recovers when THAT job succeeds,
# not when any other job of the same type runs.

JOBID="$1"
LEVEL="$2"
BYTES="${3:-0}"
FILES="${4:-0}"

# Sanitizar: garantir que BYTES e FILES sejam numéricos.
# Para jobs que falham antes de iniciar, o Bacula pode passar
# valores não-numéricos nesses campos.
[[ ! "$BYTES" =~ ^[0-9]+$ ]] && BYTES=0
[[ ! "$FILES" =~ ^[0-9]+$ ]] && FILES=0

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

# Consultar nome e status do job no catálogo
DBINFO=$(PGPASSWORD="$PGPASS" psql -h "$PG_HOST" -U "$PG_USER" -d "$PG_DB" -t -A -F'|' \
    -c "SELECT name, jobstatus FROM job WHERE jobid=$JOBID LIMIT 1;" 2>/dev/null)
JOBNAME=$(echo "$DBINFO" | cut -d'|' -f1)
JOBSTATUS=$(echo "$DBINFO" | cut -d'|' -f2)

# Chaves por job — cada job tem seu próprio item e trigger no Zabbix (via LLD)
STATUS_KEY="bacula.job.status[$JOBNAME]"
LASTFAIL_KEY="bacula.job.lastfail[$JOBNAME]"

# Mapear status → valor numérico
# T=OK, C=OK com avisos, qualquer outro=FALHOU
case "$JOBSTATUS" in
    "T") VALUE=0; STATUS_TEXT="OK" ;;
    "C") VALUE=1; STATUS_TEXT="OK (com avisos)" ;;
    *)   VALUE=2; STATUS_TEXT="FALHOU ($JOBSTATUS)" ;;
esac

log "Job $JOBID [$JOBNAME] Level=$LEVEL Status=$JOBSTATUS -> $STATUS_KEY=$VALUE (${FILES} arqs, ${BYTES} bytes)"

# Enviar discovery para o Zabbix criar o item/trigger automaticamente
# O Zabbix LLD processa o JSON e cria bacula.job.status[JOBNAME] e
# bacula.job.lastfail[JOBNAME] como itens individuais para este job.
DISCOVERY_JSON='[{"{#JOBNAME}":"'"$JOBNAME"'","{#JOBLEVEL}":"'"$LEVEL"'"}]'
/usr/bin/zabbix_sender -z "$ZABBIX_SERVER" -s "$ZABBIX_HOST" \
    -k "bacula.job.discovery" -o "$DISCOVERY_JSON" >> "$LOGFILE" 2>&1

# Em caso de falha: enviar texto detalhado ANTES do status numérico
# O item bacula.job.lastfail[JOBNAME] é usado na expressão do trigger
if [ "$VALUE" -gt 0 ]; then
    DETAIL="JobID ${JOBID}: ${JOBNAME} (${LEVEL}) - ${STATUS_TEXT} - Arquivos: ${FILES} - Bytes: ${BYTES}"
    /usr/bin/zabbix_sender -z "$ZABBIX_SERVER" -s "$ZABBIX_HOST" \
        -k "$LASTFAIL_KEY" -o "$DETAIL" >> "$LOGFILE" 2>&1
    log "Detalhe enviado: $DETAIL"
    sleep 1
fi

# Enviar status numérico (dispara ou resolve o trigger deste job específico)
/usr/bin/zabbix_sender -z "$ZABBIX_SERVER" -s "$ZABBIX_HOST" \
    -k "$STATUS_KEY" -o "$VALUE" >> "$LOGFILE" 2>&1

exit 0
