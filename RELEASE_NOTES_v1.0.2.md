# DS Updater 1.0.2

Esta atualização corrige um artefato visual que aparecia como um retângulo opaco atrás dos cartões Liquid Glass.

## Correções

- Oculta o fundo padrão da área de rolagem para que os cartões mantenham o acabamento Liquid Glass sem blocos retangulares ao redor.
- Tenta novamente a consulta à Sony quando o acesso HID está temporariamente ocupado e mostra uma orientação localizada se outro app ou processo do macOS continuar usando o controle.
- Não altera os tamanhos dos botões nem o conteúdo funcional do app.

## Requisitos e observações

- macOS 26 ou posterior.
- Mac com Apple Silicon (arm64).
- O app é distribuído com assinatura ad hoc, sem notarização da Apple. Na primeira abertura, use o menu de contexto do Finder e escolha **Abrir**.
- O app continua sendo independente e não oficial. O firmware pertence à Sony.

## Validação

- Build do projeto concluído com sucesso no Xcode.
