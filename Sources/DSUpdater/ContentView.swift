import SwiftUI

struct ContentView: View {
    @ObservedObject var model = UpdaterModel.shared
    @State private var confirming = false

    var body: some View {
        VStack(spacing: 20) {
            header
            content
            Spacer(minLength: 0)
            Text("Software independente e não oficial. Firmware pertence à Sony.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 28)
        .padding(.top, 40)
        .padding(.bottom, 16)
        .frame(width: 480, height: 640)
        .animation(.smooth, value: model.phase)
        .animation(.smooth, value: model.availability)
        .task {
            model.startWatching()
            await model.refresh()
        }
        .alert("Instalar firmware?", isPresented: $confirming) {
            Button("Cancelar", role: .cancel) {}
            Button("Instalar") { Task { await model.install() } }
        } message: {
            Text("Mantenha o cabo USB conectado e o Mac ligado até o fim. Pode levar vários minutos. Não desconecte o controle durante a gravação.")
        }
    }

    // MARK: Cabeçalho

    private var header: some View {
        VStack(spacing: 14) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(.primary)
                .symbolEffect(.pulse, isActive: model.isUpdating || model.phase == .loading)
                .frame(width: 92, height: 92)
                .glassEffect(.regular, in: .circle)
            VStack(spacing: 3) {
                Text("Firmware do controle")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text(model.info?.name ?? "DualSense")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Conteúdo por estado

    @ViewBuilder private var content: some View {
        switch model.phase {
        case .loading:
            VStack(spacing: 12) {
                ProgressView().controlSize(.large)
                Text("Procurando o controle…").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .glassEffect(.regular, in: .rect(cornerRadius: 24))

        case .noController(let detail):
            VStack(spacing: 10) {
                Label("Nenhum controle encontrado", systemImage: "cable.connector.slash")
                    .font(.headline)
                Text("Conecte o DualSense com um cabo USB de dados (cabos só de carga não funcionam) e feche jogos ou outras ferramentas que usem o controle.")
                    .font(.callout).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Text(detail).font(.caption.monospaced()).foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Aguardando você conectar o controle…").font(.callout)
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .glassEffect(.regular, in: .rect(cornerRadius: 24))
            Button("Procurar de novo") { Task { await model.refresh() } }
                .buttonStyle(.glass)

        case .ready, .finished, .failed:
            infoCard
            statusArea
            resultBanner
            logView

        case .updating:
            infoCard
            progressCard
            logView
        }
    }

    private var infoCard: some View {
        VStack(spacing: 10) {
            if let i = model.info {
                row("Firmware atual", i.versionHex)
                Divider()
                row("Compilação", i.buildDate.split(separator: " ").joined(separator: " ") + " " + i.buildTime)
                Divider()
                row("Disponível na Sony", model.latest ?? "—")
                if i.isEdge {
                    Text("Atualizações no DualSense Edge ainda não foram testadas pelo projeto.")
                        .font(.caption).foregroundStyle(.orange)
                }
            }
        }
        .glassCard()
    }

    @ViewBuilder private var statusArea: some View {
        GlassEffectContainer(spacing: 12) {
            VStack(spacing: 12) {
                switch model.availability {
                case .available:
                    Button { confirming = true } label: {
                        Label("Instalar firmware mais recente", systemImage: "arrow.down.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent).controlSize(.extraLarge)
                case .upToDate:
                    Label {
                        Text("Seu controle está atualizado")
                    } icon: {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                    }
                    .font(.headline)
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .glassEffect(.regular, in: .capsule)
                case .unknown:
                    if let note = model.checkNote {
                        Text(note).font(.caption).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                Button("Verificar de novo") { Task { await model.refresh() } }
                    .buttonStyle(.glass)
            }
        }
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(Int(model.progress * 100))%")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.smooth, value: model.progress)
            GlassProgressBar(value: model.progress)
            Text(model.status).font(.callout)
            Label("Não desconecte o cabo nem feche o app.", systemImage: "exclamationmark.triangle.fill")
                .font(.caption).foregroundStyle(.orange)
        }
        .glassCard()
    }

    @ViewBuilder private var resultBanner: some View {
        switch model.phase {
        case .finished(let text):
            banner("Atualização concluída", text, "checkmark.circle.fill", .green)
        case .failed(let text):
            banner("A atualização falhou",
                   "\(text)\n\nReconecte o controle e confira a versão antes de tentar de novo.",
                   "xmark.octagon.fill", .red)
        default: EmptyView()
        }
    }

    @ViewBuilder private var logView: some View {
        if !model.log.isEmpty {
            DisclosureGroup("Detalhes") {
                ScrollView {
                    Text(model.log.joined(separator: "\n"))
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 100)
            }
            .glassCard(radius: 20)
        }
    }

    // MARK: Peças

    private func row(_ k: String, _ v: String) -> some View {
        HStack { Text(k).foregroundStyle(.secondary); Spacer(); Text(v).monospaced() }
    }

    private func banner(_ title: String, _ body: String, _ icon: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: icon).foregroundStyle(color)
            }
            .font(.headline)
            Text(body).font(.callout).foregroundStyle(.secondary)
        }
        .glassCard()
    }
}
