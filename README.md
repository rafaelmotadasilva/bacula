# Instalação do Bacula Community no Ubuntu

Guia passo a passo para instalar e configurar o Bacula Community no Ubuntu, cobrindo desde a adição do repositório oficial até a configuração inicial dos daemons Director, Storage e File.

## O que é o Bacula

O Bacula é uma solução open source de backup em nível enterprise, amplamente utilizada em ambientes corporativos. Suporta backup de servidores Linux e Windows, agendamento granular, pools de volumes e relatórios detalhados de jobs.

## Componentes instalados

| Componente | Função |
|---|---|
| `bacula-director` | Orquestra e agenda os jobs de backup |
| `bacula-storage` | Gerencia os volumes de armazenamento |
| `bacula-client` | File Daemon — roda nos hosts a serem copiados |
| `bacula-console` | Interface de linha de comando (`bconsole`) |
| `bacula-catalog` | Banco de dados de catálogo (PostgreSQL/MySQL) |

## Pré-requisitos

- Ubuntu Server (20.04 ou superior)
- Acesso root ou sudo
- Conexão com a internet

## Etapas da instalação

1. Instalação de pacotes adicionais
2. Importar a chave GPG do repositório Bacula
3. Adicionar o repositório oficial
4. Instalar os pacotes do Bacula
5. Configurar o Director (`bacula-dir.conf`)
6. Configurar o Storage Daemon (`bacula-sd.conf`)
7. Configurar o File Daemon (`bacula-fd.conf`)
8. Iniciar e habilitar os serviços
9. Testar com `bconsole`

> Consulte o README completo do repositório para os comandos detalhados de cada etapa.

## Comandos úteis

```bash
# Verificar status dos daemons
systemctl status bacula-director bacula-sd bacula-fd

# Abrir console interativo
bconsole

# Testar configuração do Director
bacula-dir -tc /etc/bacula/bacula-dir.conf
```

## Referências

- [Documentação oficial do Bacula](https://www.bacula.org/documentation/)
- [Repositório oficial Bacula Community](https://www.bacula.org/bacula-binary-package-download/)
