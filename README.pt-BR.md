# LiveSession

[Read in English](README.md)

O LiveSession é um plugin do Roblox Studio que roda o seu jogo enquanto você ainda está no modo de edição. Em vez de apertar Play e esperar uma sessão de teste separada, você inicia uma sessão ao vivo e os scripts começam a rodar dentro do próprio place que está sendo editado, então dá para ver tudo funcionando enquanto você continua construindo.

Para isso o plugin hospeda os scripts de servidor e de cliente por conta própria e troca os serviços que normalmente não funcionam fora do Play, como RunService, MarketplaceService, MessagingService, TeleportService e TextChatService, por versões compatíveis. Ele também controla a física e as animações, faz a ponte dos remotes entre o lado do servidor e o do cliente e recarrega os scripts quando você altera algum. Um painel de fidelidade mostra o quanto cada parte se aproxima do comportamento real, e os avisos aparecem no painel de status quando algo precisa de atenção.

Antes de a sessão começar o plugin tira um snapshot do mundo, e toda mudança feita enquanto o jogo roda vai para um journal. Quando você para, uma tela de revisão mostra o que mudou e o mundo volta ao estado anterior, mantendo só o que você decidir manter. Ele também funciona com o Team Create, usando travas para duas pessoas não rodarem sessões uma por cima da outra, e pode ser controlado por agentes de IA através do meu Roblox Studio MCP.

## Como usar

Leve a pasta LiveSession para o Studio mantendo a estrutura, usando o Rojo ou outra ferramenta de sincronização. A pasta tem o script Main e as pastas de módulos ao lado dele. Selecione a pasta LiveSession, clique com o botão direito e escolha Save as Local Plugin. A barra de ferramentas ganha botões para iniciar e parar a sessão, abrir o painel de status e abrir a saída da sessão.

## Tempo de desenvolvimento

O LiveSession foi feito em cinco dias e funciona no estado atual.

## Licença

GNU General Public License versão 3. O texto completo está no arquivo LICENSE.
