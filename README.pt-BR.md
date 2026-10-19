<p align="center">
  <img src="assets/readme/icon.png" width="88" height="88" alt="Ícone do aplicativo WindTorrent">
</p>

<h1 align="center">WindTorrent</h1>

<p align="center"><strong>Seus gerenciadores de download. Um só app Android.</strong></p>
<p align="center">Gerencie Aria2, qBittorrent e Transmission pelo celular.</p>

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=com.hienao.windtorrent">Versão gratuita no Google Play</a> ·
  <a href="https://play.google.com/store/apps/details?id=com.hienao.windtorrent.pro">Obter Pro</a> ·
  <a href="https://hienao-apps.pages.dev/windtorrent/">Site oficial</a>
</p>

<p align="center"><a href="README.md">English</a> · <a href="README.zh-CN.md">简体中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.de.md">Deutsch</a><br>
  <a href="README.es.md">Español</a> · <a href="README.fr.md">Français</a> · Português (Brasil) · <a href="README.ru.md">Русский</a></p>

O WindTorrent se conecta aos gerenciadores de download que você já executa em um NAS, servidor ou computador. Acompanhe o progresso, adicione tarefas e pause ou retome downloads em um só lugar. Os arquivos são baixados e salvos no equipamento em que o gerenciador conectado está sendo executado.

<p align="center">
  <a href="assets/readme/overview.webp"><img src="assets/readme/overview.webp" width="31%" alt="Imagem do Google Play com a visão geral das conexões e tarefas"></a>
  <a href="assets/readme/downloaders.webp"><img src="assets/readme/downloaders.webp" width="31%" alt="Imagem do Google Play com conexões ao Aria2, qBittorrent e Transmission"></a>
  <a href="assets/readme/tasks.webp"><img src="assets/readme/tasks.webp" width="31%" alt="Imagem do Google Play com busca, filtros de status e progresso das tarefas"></a>
</p>

<p align="center"><sub>Imagens oficiais do Google Play em inglês. Toque para ampliar; a interface pode variar conforme a versão instalada.</sub></p>

## Menos trocas de aplicativo, mais controle

- **Reúna seus gerenciadores.** Conecte várias instâncias do Aria2, qBittorrent e Transmission.
- **Veja o que está acontecendo.** Acompanhe o status, o progresso e as velocidades de download e upload das tarefas.
- **Cuide das tarefas do dia a dia.** Adicione links ou arquivos torrent, depois pause, retome ou remova tarefas. Os formatos aceitos dependem do gerenciador conectado.
- **Confira os detalhes quando precisar.** Veja arquivos, trackers, peers e opções das tarefas nos gerenciadores compatíveis.
- **Use do seu jeito.** Escolha o tema e o idioma e transfira configurações com exportação e importação local em JSON.

## Como conectar

1. Instale o [WindTorrent Free](https://play.google.com/store/apps/details?id=com.hienao.windtorrent) ou o [WindTorrent Pro](https://play.google.com/store/apps/details?id=com.hienao.windtorrent.pro).
2. Ative a interface de acesso remoto do seu gerenciador de download e confirme que ela pode ser acessada pelo celular.
3. Abra **Downloaders**, toque em **+**, escolha o tipo e informe o host, a porta e as credenciais. Ajuste o HTTPS de acordo com o servidor e salve.

| Gerenciador | Interface remota | Porta comum | Guia em inglês |
| --- | --- | --- | --- |
| Aria2 | JSON-RPC | `6800` | [Conectar Aria2](docs/aria2.md) |
| qBittorrent | WebUI API | `8080` | [Conectar qBittorrent](docs/qbittorrent.md) |
| Transmission | RPC | `9091` | [Conectar Transmission](docs/transmission.md) |

Use a porta realmente acessível, considerando o mapeamento de portas do Docker, se houver. No campo de endereço, informe um nome de host ou IP; o app acrescenta o caminho da API automaticamente. Consulte os guias para os requisitos de proxy reverso.

## Free ou Pro?

| | WindTorrent Free | WindTorrent Pro |
| --- | --- | --- |
| Funções principais de gerenciamento | Incluídas | Incluídas |
| Anúncios | Após sete dias de experiência inicial, conforme suas escolhas de privacidade | Sem SDK de anúncios |
| Compra | Instalação gratuita | Aplicativo pago separado |
| Instalação | [Google Play](https://play.google.com/store/apps/details?id=com.hienao.windtorrent) | [Google Play](https://play.google.com/store/apps/details?id=com.hienao.windtorrent.pro) |

Os dois apps podem ser instalados ao mesmo tempo. Transfira as configurações usando um arquivo JSON local. O Pro é comprado separadamente, e não por uma compra dentro do Free. As duas versões usam o Firebase Analytics; veja a [política de privacidade em inglês e chinês](https://hienao-apps.pages.dev/windtorrent/privacy/) para mais detalhes.

## Idiomas e ajuda

A interface do app está disponível em inglês, chinês simplificado e japonês. Este repositório oferece uma apresentação em oito idiomas. Os guias detalhados e as perguntas frequentes estão disponíveis em [inglês](docs/faq.md) e [chinês simplificado](docs/zh-CN/faq.md).

[Relate um problema](https://github.com/hienao/WindTorrent/issues/new?template=bug_report.yml) ou [sugira uma funcionalidade](https://github.com/hienao/WindTorrent/issues/new?template=feature_request.yml). Os formulários, as [orientações para contribuir](CONTRIBUTING.md) e as [notas de versão](CHANGELOG.md) estão em inglês e chinês.

Antes de compartilhar capturas de tela ou logs, remova senhas, segredos RPC, URLs privadas e informações pessoais das tarefas. Os backups contêm credenciais e não devem ser anexados a issues públicas. Para assuntos sensíveis, entre em contato com o [suporte por e-mail](mailto:shiwentao666@gmail.com).

## Sobre este repositório

Este é o repositório público oficial de documentação e feedback do WindTorrent. O aplicativo tem código fechado; seu código-fonte não é distribuído aqui. Aria2, qBittorrent e Transmission são projetos independentes, sem vínculo com o WindTorrent.

[Site oficial (inglês/chinês)](https://hienao-apps.pages.dev/windtorrent/) · [Privacidade (inglês/chinês)](https://hienao-apps.pages.dev/windtorrent/privacy/) · [Suporte](mailto:shiwentao666@gmail.com)
