# DS Updater 1.0.1

Esta versão adiciona informações do controle e melhora a estabilidade da leitura ao conectar o DualSense por USB.

## Novidades

- Exibe o modelo, o número de série e o nível da bateria do DualSense e do DualSense Edge.
- Usa a porcentagem de bateria fornecida pelo GameController do macOS quando disponível; o relatório HID do controle serve como alternativa.
- Remove a identificação de cor, que era inferida a partir do número de série e podia estar incorreta.
- Mantém os últimos dados válidos durante a consulta de atualizações e quando uma nova leitura HID falha.
- Aguarda a interface USB HID inicializar na abertura do app e tenta novamente leituras incompletas.
- Executa a leitura dos detalhes depois da consulta de firmware para reduzir disputas pelo acesso HID.
- Aumenta a altura da janela e permite rolar o conteúdo sem alterar o tamanho dos botões.
- Adiciona traduções dos novos campos às localizações existentes.

## Requisitos e observações

- macOS 26 ou posterior.
- Controle conectado por USB para leitura do número de série e dos dados HID.
- O nível HID tem resolução em faixas; quando o GameController não fornece a porcentagem, o valor pode diferir do exibido pelo macOS.
- O app continua sendo independente e não oficial. O firmware pertence à Sony.

## Validação

- Build do projeto concluído com sucesso no Xcode.
