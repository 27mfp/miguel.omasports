Plano de implementação — OmaSports / Omarchy 4.5

Base: versão 1.5.0, commit 3e4a1ab; análise de 6 de novembro de 2026. Este ficheiro contém trabalho proposto, não certificação de implementação. O alvo inicial é Omarchy 4.5 / Qt 6.12.

**Estado do patch 1.5.1 — 6 de novembro de 2026**

O patch inicial trata OS-01 e as correções imediatas de texto/anti-spoiler de OS-02: Commons.Color explícito, PlainText, notificações escapadas, cor do ticker neutra e vencedores/pódio/sessões de F1 ocultos até revelar. Notícias ficam ocultas no modo anti-spoiler. Aplica também a política de background ao painel atual: cancelar workers/retries ao suspender, não deixar alertas/jogos em direto ultrapassar a preferência, criar baseline na retoma e retirar o fallback remoto de Image dos emblemas. Os testes de funções do controlador e componentes nativos não substituem a matriz completa de integração. Serviço único, arquitetura/UI nova, deadlines globais, persistência e restante backlog mantêm-se por implementar/validar.

**Comportamento pretendido**

Ao abrir, o utilizador vê rapidamente o que se passa com as equipas/pilotos que segue. Consegue consultar agenda, diretos e classificações sem atravessar vários filtros redundantes. Uma falha num provider não apaga os dados úteis dos restantes. Vários monitores mostram o mesmo estado, sem multiplicar pedidos ou notificações.

Mantêm-se Football, NBA, F1, NFL, MLB e NHL e as fontes existentes. Não se acrescentam contas, novos providers ou um daemon externo nesta atualização.

**Arquitetura proposta**

- `Service.qml`: entry point único para a shell e coordenação dos módulos; estado disponível antes de qualquer painel abrir.
- `SportsStore.qml`: dados normalizados, seleções e snapshots por modalidade. Estado por fonte inclui dados, atualização, erro e validade.
- `RefreshCoordinator.qml`: filas, gerações, política de atualização, coalescência, prioridades e backoff.
- `StateStore.qml`: carregamento, migração e escrita serializada de favoritos/preferências de domínio.
- `NotificationController.qml`: deteção de eventos, deduplicação, fila e política anti-spoiler.
- Adaptadores FotMob, ESPN e F1: pedidos e transformação para o contrato existente. Extrair incrementalmente de Panel.qml, sem reescrever todos os parsers.
- `SportsModel.js` permanece como fachada compatível durante a extração de módulos puros de parsers, seletores, apresentação e notificações.
- `Panel.qml`, separadores e linhas ficam com composição, navegação e ações sobre o serviço. Widget e painel de cada monitor partilham o mesmo store.
- `secure_io.py`, `SecureProcess.qml` e `NetworkProcess.qml` conservam as fronteiras de I/O, processos e limites de dados.

Os nomes são uma proposta de organização, não uma obrigação de criar todos os ficheiros de uma vez. Cada extração deve ter uma responsabilidade e preservar o comportamento antes de o alterar.

**Política de atualização decidida para este plano**

“Atualizar em segundo plano” passa a ser uma opção principal inequívoca. Desligada e com todos os painéis fechados: zero novos pedidos automáticos de resultados, detalhes, notícias ou emblemas; parar retries e cancelar pedidos pendentes. Um jogo em direto não ultrapassa essa preferência.

As notificações continuam como preferência separada. Com atualizações em segundo plano desligadas, o UI indica “Alertas apenas enquanto o painel está aberto”. Ativar notificações não volta a ligar silenciosamente a monitorização. O ticker mostra dados já disponíveis e o estado de atualização; não implica uma autorização extra para pedidos.

Abrir um painel apresenta os dados disponíveis e pede uma ronda, coalescida entre monitores. Atualização manual funciona com o painel aberto. Reabrir/retomar monitorização estabelece uma baseline de eventos para não reproduzir golos antigos como notificações novas. Notícias e classificações têm cadências mais lentas do que resultados em direto.

**Backlog e aceitação**

| ID | Trabalho | Depende de | Aceitação |
| --- | --- | --- | --- |
| OS-01 | Commons.Color em produção, fixtures e QML gerado pelo harness | — | Imports sem patch no Qt 6.12 carregam a paleta; paletas de teste deixam de escrever no tipo Color ambíguo |
| OS-02 | Texto externo simples e anti-spoiler completo | OS-01 | Headline/nomes com markup aparecem literalmente; ticker, ponto de cor, tooltip, detalhes, nomes acessíveis e notificações não revelam resultados ocultos |
| OS-03 | Testar serviço único, manifesto e IPC num host privado | OS-01 | Uma instância sem UI; widgets tardios ligam ao serviço; comandos/rotas antigos mantêm resultado e monitor correto |
| OS-04 | Extrair store, preferências e notificações do painel | OS-03 | Duas vistas partilham estado; uma escrita/uma notificação por evento; fechar o painel não destrói o modelo |
| OS-05 | Extrair coordenador e adaptadores de providers | OS-04 | Trocas rápidas descartam respostas antigas; pedidos idênticos são coalescidos; falha de uma fonte mantém sucessos das outras |
| OS-06 | Aplicar política de atualização e deadlines globais | OS-05 | Painéis fechados + background off = zero novos pedidos; timeout cobre a vida total do processo; 429 não é repetido antes de Retry-After válido |
| OS-07 | Cache e migração de preferências | OS-04, OS-05 | Dados válidos persistem perante falhas; gravação é atómica e limitada; migração idempotente conserva favoritos; formatos futuros não são sobrescritos |
| OS-08 | Resumo Hoje, navegação e hierarquia das linhas | OS-04 | Favoritos em direto/próximos/resultados fáceis de localizar; destaque não repetido na mesma lista; estados vazios têm ação relevante |
| OS-09 | Conteúdo tardio e listas extensas | OS-08 | Zero conteúdo visual antes da abertura; modelos independentes; lista longa mantém foco/scroll e número de delegates limitado onde virtualizada |
| OS-10 | Idiomas, temas, movimento e acessibilidade | OS-02, OS-08 | pt/en ao vivo, datas/números localizados, sem pulsos com movimento desligado, navegação completa por teclado |
| OS-11 | Diagnóstico, CI nativo, migração e release | OS-06, OS-07, OS-09, OS-10 | Matriz funcional/gráfica e testes reais dos seis desportos registados; upgrade/reversão preservam preferências |

**UI/UX a implementar**

Manter três percursos principais: Hoje, Em direto e Classificações. “Hoje” começa por favoritos em direto, próximos eventos e resultados recentes; a agenda completa continua acessível através de seleção de data/intervalo. Em F1, usar sessões e próxima corrida de forma adequada, sem forçar a metáfora de jogos. Rotas IPC antigas como fixtures, upcoming e results continuam a apontar para a vista/filtro correspondente.

Cabeçalho fixo com modalidade, atualização e definições. Filtros de equipa/competição junto da lista; opções menos frequentes recolhidas. Um destaque aparece uma vez na secção; se houver repetição entre separadores distintos, a função de cada vista permanece clara.

Linhas mostram primeiro equipas/piloto e resultado/horário. Competição, transmissão e estatísticas são secundários. Detalhes expandem a mesma linha ou uma área contextual sem fazer saltar o scroll. Notícias ficam opcionais e secundárias. O primeiro uso sem favoritos explica como seguir equipas e permite consultar uma competição.

O modo anti-spoiler neutraliza qualquer estado baseado no resultado, incluindo vitórias/derrotas, cores, tooltips e textos acessíveis. Revelar um jogo é uma ação explícita e local à sessão, segundo a regra atual a confirmar por testes; não altera a preferência global.

Dados em atualização conservam o conteúdo anterior. Mostrar “A atualizar”, “Guardado — atualizado há …” ou erro parcial sem usar o mesmo estado para vazio, indisponível e carregamento. O ticker tem largura limitada em barra horizontal e representação compacta na vertical; segue fixedEdge para não deslocar os vizinhos desnecessariamente.

**Backend, cache e consistência**

- Modelo normalizado por evento com identidade composta de provider/modalidade/ID e timestamps de origem/recolha. Não fundir jogos de fontes distintas apenas por nomes de equipas.
- Geração por contexto de seleção; cada resultado é aplicado apenas ao contexto para que foi pedido. Não invalidar caches válidas de outras modalidades ao cancelar a vista atual.
- Priorizar o dia atual/eventos seguidos. Preservar a estratégia ESPN de um dia por pedido e as cadências mínimas existentes; standings, notícias e enriquecimento não bloqueiam resultados principais.
- Deduplicar trabalho em voo. Limites de concorrência explícitos por provider e globais; backoff com jitter sem violar o intervalo mínimo ou Retry-After. 401/403 não entram em ciclos rápidos.
- `urllib` tem hoje timeout de operação de socket; acrescentar um prazo total de job no coordenador, incluindo DNS/TLS/leitura, com término do grupo de processos. Uma resposta que chega aos poucos não pode prolongar o pedido indefinidamente.
- Acrescentar resultado de erro estruturado na fronteira do helper: tipo, status HTTP e Retry-After quando existir, mantendo a saída raw atual até migrar todos os consumidores/testes. Não classificar falhas por pesquisa de frases de stderr.
- Preservar allowlists HTTPS, validação de redirects, limites de bytes/dimensões e escrita por descritores. Emblemas passam pelo cache validado; monograma enquanto indisponíveis. Evitar que um Image com URL remota contorne a política de atualização e os limites do helper.
- Cache por fonte/seleção com fetchedAt e schema version, TTL e orçamento de tamanho. O último snapshot válido pode ser mostrado offline; dados malformados nunca o substituem. Escrita em disco coalescida e limitada, sem gravar a cada tick do relógio.
- Fontes de verdade: shell.json para opções de widget declaradas no manifesto, incluindo ticker/background/posição; sports-favorites.json para equipas, ligas e preferências de domínio. Migrar as cópias antigas de opções de widget sem as perder se a gravação na shell falhar. Testar precedência e readback antes de eliminar campos antigos.
- Escritor único, publicações atómicas, estado anterior preservado em caso de erro e backup privado antes de migração. Respeitar os limites/symlinks já tratados por secure_io.py.
- Notificações deduplicadas por evento e transição; ordem e fila limitadas. Sem repetição em restart, rescan ou segundo monitor; retoma não envia retrospectiva de resultados.
- Diagnóstico local inclui estado por provider, última atualização, idade do cache, contagem de pedidos/retries e erro sanitizado. Sem telemetria externa implícita.
- Atualizar RUNNING.md e o processo de cópia/instalação para incluir o serviço, módulos e i18n; testar a cópia instalada num diretório limpo. A presença dos ficheiros no checkout não basta para provar que o pacote está completo.

**Testes e ferramentas**

Conservar os testes atuais de parsers e fixtures dos seis desportos. Adaptar os testes que extraem funções de Panel.qml para exercitarem os módulos puros ou as novas fronteiras; evitar deixar funções duplicadas no painel apenas para satisfazer regexes antigas.

Comandos base:

```bash
node tests/run-all.mjs --quick --runtime
omarchy plugin validate .
git diff --check
```

Acrescentar um checker nativo de QML com imports Omarchy e exceções específicas para metadados. O lint de sintaxe de Ubuntu continua útil, mas não prova compatibilidade com Qt 6.12. Incluir verificação dos módulos JS extraídos e dos catálogos de tradução no runner/CI.

Adaptar `tests/ui-session.mjs` para montar serviço + widget + painel num host privado com preferências temporárias. A suite atual monta sobretudo Panel, pelo que não prova a nova arquitetura. Testar imports não remendados, bar API real, registo de serviço/IPC e atraso de carregamento.

Comandos gráficos existentes, a executar numa sessão Wayland de teste depois de adaptar o harness:

```bash
node tests/ui-session.mjs -- node tests/interaction.mjs
node tests/ui-session.mjs --palette=dark -- node tests/visual.mjs --sport=all --tab=all
node tests/ui-session.mjs --palette=light -- node tests/visual.mjs --sport=all --tab=all
```

Os screenshots usam apenas outputs headless, sem roubar foco e sem preferências reais. Atualizar goldens depois de inspecionar os novos ecrãs; não aceitar automaticamente diferenças para tornar a suite verde.

**Integração obrigatória antes da release completa**

1. Carregamento/refresh reais de Football, NBA, F1, NFL, MLB e NHL; dados de agenda e classificações coerentes; registar data/source da observação.
2. Offline/timeout/429/5xx/resposta inválida em fonte controlada, com resultados parciais preservados e recuperação posterior.
3. Alterar modalidade/ligas/equipas rapidamente durante pedidos; nunca mostrar uma resposta antiga na seleção nova.
4. Background off com todos os painéis fechados: verificar contadores durante um intervalo de polling e confirmar zero trabalho novo, incluindo notícias/emblemas.
5. Dois monitores, hotplug, rescan e restart: uma ronda de trabalho, fila única e ausência de alertas repetidos.
6. F1 e jogos perto da meia-noite, fusos/DST, adiado/cancelado e fase final. Relógio estimado não transforma um resultado antigo em informação “ao vivo” sem indicar desatualização.
7. Migração da 1.5.0, escrita falhada, ficheiro corrompido e rollback; favoritos e preferências preservados.
8. Capturas das seis modalidades, estados vazios/erro/parcial, ambas as paletas e fontes/escalas suportadas; teclado e anti-spoiler verificados também na barra.

A correção de compatibilidade e anti-spoiler é um patch independente. A nova arquitetura e UI exigem esta matriz antes de serem apresentadas como suporte completo ao Omarchy 4.5.
