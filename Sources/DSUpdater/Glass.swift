import SwiftUI

extension View {
    /// Cartão de Liquid Glass padrão do sistema.
    /// Sem tinta nem cores próprias: assim ele segue sozinho o claro/escuro e o ajuste
    /// de transparência (Transparente ↔ Colorido) de Ajustes do Sistema > Aparência.
    func glassCard(radius: CGFloat = 24) -> some View {
        self.padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: .rect(cornerRadius: radius))
    }
}

/// Barra de progresso: trilho de vidro e preenchimento na cor de destaque do sistema.
struct GlassProgressBar: View {
    let value: Double

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(.clear).glassEffect(.regular, in: .capsule)
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: max(14, g.size.width * min(max(value, 0), 1)))
                    .padding(2)
            }
        }
        .frame(height: 16)
        .animation(.smooth, value: value)
    }
}
