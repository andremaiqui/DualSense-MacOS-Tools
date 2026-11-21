# DS Updater 1.0.0

Versão estável inicial com leitura dos dados do DualSense e uma interface Liquid Glass fixa e compacta.

## Recursos e melhorias

- Exibe o modelo, o número de série e a bateria quando os dados estão disponíveis.
- Tenta novamente consultas HID ocupadas e orienta o usuário caso outro app ou processo do macOS esteja usando o controle.
- Mantém cartões e botões fixos, sem rolagem na interface principal, preservando os tamanhos dos botões.
- Janela com altura de 760 pontos para reduzir o espaço vazio.
- Interface e mensagens de erro disponíveis nos idiomas incluídos no app.

## Requisitos e observações

- macOS 26 ou posterior.
- Mac com Apple Silicon (arm64).
- Conecte o controle por um cabo USB de dados para consultar número de série e dados HID.
- O app é distribuído com assinatura ad hoc, sem notarização da Apple. Na primeira abertura, use o menu de contexto do Finder e escolha **Abrir**.
- O app é independente e não oficial. O firmware pertence à Sony.

## Validação

- Build do projeto concluído com sucesso no Xcode.
