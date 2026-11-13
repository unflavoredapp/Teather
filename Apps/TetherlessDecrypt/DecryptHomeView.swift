import SwiftUI

struct DecryptHomeView: View {
    @State private var appName = "Select an app"
    @State private var version = "—"
    @State private var status = "Waiting to start…"
    @State private var isRunning = false
    @State private var showingPicker = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 26) {
                HStack {
                    Spacer()
                    Text("Tetherless Decrypt").font(.headline)
                    Spacer()
                    Image(systemName: "square.and.arrow.up").foregroundStyle(.blue)
                }.padding(.top, 12)

                HStack(spacing: 14) {
                    Image(systemName: "app.fill")
                        .font(.system(size: 34)).foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .background(.blue, in: RoundedRectangle(cornerRadius: 13))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(appName).font(.headline)
                        Text("Version \(version)").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(16)
                .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 18))

                HStack(spacing: 10) {
                    Image(systemName: isRunning ? "arrow.triangle.2.circlepath" : "hourglass")
                    Text(status)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 18))

                Spacer()

                Button {
                    isRunning = true
                    status = "Preparing request…"
                    // The job API is connected when the TetherlessHelper job endpoint is enabled.
                } label: {
                    Text(isRunning ? "Preparing…" : "Start Decryption")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRunning)
                .padding(.bottom, 16)
            }
            .padding(.horizontal, 20)
        }
        .preferredColorScheme(.dark)
    }
}
