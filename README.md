# Instalação do Bacula Community no Ubuntu

Este guia fornece instruções passo a passo para instalar o Bacula Community no Ubuntu, permitindo que você configure um sistema de backup robusto e confiável.

## Visão Geral

O Bacula Community é uma solução de backup de código aberto que oferece recursos avançados de backup, restauração e verificação de dados e é adequado para empresas de todos os tamanhos. Este tutorial o guiará desde a instalação dos pacotes necessários até a configuração do Bacula Community em seu servidor Ubuntu.

## Requisitos

* Conexão com a internet.
* Permissões de superusuário (sudo).

## Instruções

1. [Instalação de Pacotes Adicionais](#instalação-de-pacotes-adicionais)
2. [Importar a Chave GPG](#importar-a-chave-gpg)
3. [Configuração do Gerenciador de Pacotes apt](#configuração-do-gerenciador-de-pacotes-apt)
4. [Instalação de Pacotes](#instalação-de-pacotes)
5. [Considerações de Segurança e Permissões](#considerações-de-segurança-e-permissões)
6. [Conclusão](#conclusão)

## Instalação de Pacotes Adicionais

Para utilizar os repositórios da Comunidade Bacula, é necessário instalar o seguinte pacote:

```
sudo apt-get update
sudo apt-get install apt-transport-https
```

## Importar a Chave GPG

Os pacotes são assinados com uma assinatura de chave GPG que você pode encontrar na raiz da sua área de download:

```
cd /tmp
wget https://www.bacula.org/downloads/Bacula-4096-Distribution-Verification-key.asc
sudo apt-key add Bacula-4096-Distribution-Verification-key.asc
rm Bacula-4096-Distribution-Verification-key.asc
```

## Configuração do Gerenciador de Pacotes apt

Adicione as seguintes entradas a um novo arquivo chamado `/etc/apt/sources.list.d/Bacula-Community.list`, adaptando a URL para apontar para sua Área de Download. Além disso, preste atenção para usar a versão e a plataforma corretas da Comunidade Bacula na URL.

Onde:

@access-key@ se refere à sua string de área personalizada. Esta é a parte final do caminho enviada no e-mail de registro. Copiar a URL desse e-mail será uma das maneiras mais simples de configurar isso corretamente.
@bacula-version@ deve ser substituído pela versão da Comunidade Bacula que você está usando (por exemplo, 11.0.6).
@ubuntu-version@ é o nome do código da distribuição (por exemplo, "focal" para o Ubuntu 20.04).

```
echo "# Bacula Community
deb http://www.bacula.org/packages/60c994751ce94/debs/11.0.6/focal/amd64/ focal main" | sudo tee /etc/apt/sources.list.d/Bacula-Community.list
```

## Instalação de Pacotes

Atualize o gerenciador de pacotes:

```
sudo apt-get update
```

Se o PostgreSQL ainda não estiver instalado, execute este comando para instalá-lo:

```
sudo apt-get install postgresql postgresql-client
```

Instale o Software da Comunidade Bacula:

Execute este comando para instalar os pacotes:

```
sudo apt-get install bacula-postgresql
```

O apt perguntará se você deseja "Configurar o banco de dados para bacula-postgresql com dbconfig-common?" Escolha "Yes", depois insira uma senha e confirme-a.

## Considerações de Segurança e Permissões

Agora, vá para o capítulo "Considerações de Segurança e Permissões" e continue a instalação a partir daí.

## Conclusão

Após seguir este guia, você terá o Bacula Community instalado e pronto para uso em seu servidor Ubuntu. Você poderá configurar e gerenciar backups de forma eficiente, garantindo a segurança e integridade dos seus dados.

## Contribuição

Se você tiver sugestões de melhorias ou correções para este guia, sinta-se à vontade para enviar uma pull request.

## Referências

* [Bacula Community](https://www.bacula.org/whitepapers/CommunityInstallationGuide.pdf)

* [Script de instalação do Bacula Community](https://www.bacula.lat/community/script-instalacao-bacula-community-9-x-pacotes-oficiais/)

## Licença

Este projeto está licenciado sob a [Licença MIT](LICENSE).