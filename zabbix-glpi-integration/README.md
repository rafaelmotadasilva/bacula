# Integração Bacula → Zabbix → GLPI

Automação completa de alertas de backup: o Bacula notifica o Zabbix ao final de cada job (sucesso ou falha), o Zabbix dispara triggers e abre chamados automaticamente no GLPI. Quando o backup se recupera, o chamado é resolvido automaticamente.

## Fluxo

```
Bacula Job finaliza
       ↓
  zabbix-notify.sh (RunScript)
       ↓
  zabbix_sender → Zabbix trapper items
       ↓
  Trigger Zabbix PROBLEM/RECOVERY
       ↓
  Webhook GLPI → Abre / Resolve chamado
```

## Componentes

| Arquivo | Descrição |
|---|---|
| `zabbix-notify.sh` | Script chamado pelo Bacula após cada job |
| `bacula-dir-runscript.conf` | Snippet de configuração para `bacula-dir.conf` |
| [`../zabbix-glpi-integration/`](.) | Este diretório |
| Webhook GLPI | Ver repositório [glpi-docker-compose](https://github.com/rafaelmotadasilva/glpi-docker-compose) |

## Pré-requisitos

- Bacula Community instalado com catálogo PostgreSQL
- `zabbix-sender` instalado no servidor Bacula (`apt install zabbix-sender`)
- Zabbix Server acessível a partir do servidor Bacula
- GLPI com API REST habilitada

## Instalação

### 1. Script de notificação

```bash
cp zabbix-notify.sh /opt/bacula/scripts/
chmod +x /opt/bacula/scripts/zabbix-notify.sh

# Criar arquivo de log
touch /var/log/bacula-zabbix.log
chown root:bacula /var/log/bacula-zabbix.log
chmod 664 /var/log/bacula-zabbix.log
```

Edite as variáveis no topo do script:

```bash
ZABBIX_HOST="nome-do-host-no-zabbix"   # Nome técnico, não o display name
ZABBIX_SERVER="ip-do-zabbix-server"
PG_HOST="127.0.0.1"
PG_USER="bacula"
PG_DB="bacula"
PGPASS="sua-senha-postgresql"
```

### 2. Configuração do Bacula Director

Adicione o bloco `RunScript` em cada `JobDefs` ou `Job` que deseja monitorar.
Veja o exemplo em `bacula-dir-runscript.conf`.

```bash
# Verificar sintaxe após editar
bacula-dir -tc /opt/bacula/etc/bacula-dir.conf

# Recarregar o Director (sem reiniciar)
echo -e 'reload\nquit' | bconsole
```

### 3. Itens Trapper no Zabbix

Crie os seguintes itens como **Trapper** no host do Bacula:

| Chave | Tipo de dado | Descrição |
|---|---|---|
| `bacula.full.job.status` | Numérico (0=OK, 1=avisos, 2=falha) | Status do último Full |
| `bacula.diff.job.status` | Numérico | Status do último Differential |
| `bacula.incr.job.status` | Numérico | Status do último Incremental |
| `bacula.job.lastfail` | Texto | Detalhe do último job com falha |

### 4. Triggers no Zabbix

Crie uma trigger para cada tipo de backup. Use expressão macro no nome para que o detalhe apareça no chamado GLPI:

```
Nome:       Backup Full FAIL em {HOST.NAME}: {?last(/nome-do-host/bacula.job.lastfail)}
Expressão:  last(/nome-do-host/bacula.full.job.status) > 0
Severidade: High
```

Repita para `bacula.diff.job.status` e `bacula.incr.job.status`.

> **Importante:** Use `{?last(...)}` (expressão macro) no nome do trigger.
> O parâmetro `trigger_name` do webhook GLPI deve usar `{EVENT.NAME}`, não `{TRIGGER.NAME}`,
> para que a macro de expressão seja resolvida corretamente.

### 5. Webhook GLPI no Zabbix

Configure um Media Type do tipo Webhook com o script disponível em
[glpi-docker-compose → zabbix-webhook](https://github.com/rafaelmotadasilva/glpi-docker-compose).

Parâmetros obrigatórios do media type:

| Parâmetro | Valor |
|---|---|
| `glpi_url` | URL base do GLPI (ex: `http://glpi.empresa.local`) |
| `glpi_login` | Usuário GLPI com acesso à API |
| `glpi_password` | Senha do usuário |
| `glpi_requester_id` | ID do usuário solicitante padrão |
| `glpi_assignee_id` | ID do técnico responsável padrão |
| `trigger_name` | `{EVENT.NAME}` |
| `event_id` | `{EVENT.ID}` |
| `event_value` | `{EVENT.VALUE}` |
| `event_update` | `{EVENT.UPDATE.STATUS}` |
| `event_update_message` | `{EVENT.UPDATE.MESSAGE}` |
| `event_date` | `{EVENT.DATE}` |
| `event_time` | `{EVENT.TIME}` |
| `host_name` | `{HOST.NAME}` |
| `host_ip` | `{HOST.IP}` |
| `host_groups` | `{TRIGGER.HOSTGROUP.NAME}` |
| `severity` | `{TRIGGER.SEVERITY}` |
| `severity_id` | `{TRIGGER.NSEVERITY}` |
| `trigger_id` | `{TRIGGER.ID}` |
| `zabbix_url` | URL do Zabbix |

## Como funciona

### Job com falha

1. Bacula finaliza o job com status diferente de `T`
2. `RunScript` executa `zabbix-notify.sh %i %l %b %f`
3. Script consulta o catálogo PostgreSQL para obter nome e status
4. Envia `bacula.job.lastfail` com texto descritivo (ex: `JobID 1234: Backup-Win (Full) - FALHOU (f) - Arquivos: 0 - Bytes: 0`)
5. Aguarda 1 segundo (garante que o texto está disponível quando a trigger avaliar)
6. Envia `bacula.full.job.status = 2`
7. Trigger dispara → webhook abre chamado no GLPI com o detalhe no título

### Job com sucesso (recuperação)

1. Bacula finaliza o job com status `T`
2. Script envia `bacula.full.job.status = 0`
3. Trigger entra em RECOVERY → webhook resolve o chamado aberto no GLPI

## Dicas de troubleshooting

```bash
# Acompanhar log em tempo real
tail -f /var/log/bacula-zabbix.log

# Testar o script manualmente (substitua pelo JobID real)
/opt/bacula/scripts/zabbix-notify.sh 1234 Full 0 0

# Testar envio manual com zabbix_sender
zabbix_sender -z <zabbix-server> -s <hostname> -k bacula.incr.job.status -o 2
```

## Códigos de status do Bacula

| Status | Significado |
|---|---|
| `T` | Terminado com sucesso |
| `C` | Terminado com avisos |
| `f` | Falhou |
| `A` | Cancelado pelo usuário |
| `e` | Erro interno |
| `D` | Diferenças encontradas |
