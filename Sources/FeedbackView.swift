import SwiftUI
import UIKit

struct FeedbackView: View {
    private let whatsAppNumber = "6588666375"
    @State private var title = ""
    @State private var message = ""
    @State private var showCopied = false

    private var canSend: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundTop.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        intro
                        form
                        Button(action: send) {
                            Label("Gửi qua WhatsApp", systemImage: "paperplane.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.cyan)
                        .disabled(!canSend)
                    }
                    .padding(18)
                }
            }
            .navigationTitle("Phản hồi")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Đã sao chép", isPresented: $showCopied) { Button("OK", role: .cancel) {} }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WEATHERSHARE")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .tracking(2)
                .foregroundStyle(.cyan)
            Text("Góp ý để bản VIP tốt hơn")
                .font(.system(size: 25, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text("Báo lỗi, đề xuất tính năng hoặc gửi ý tưởng giao diện.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Tiêu đề", text: $title)
                .textFieldStyle(.plain)
                .padding(13)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            ZStack(alignment: .topLeading) {
                if message.isEmpty { Text("Nội dung phản hồi…").foregroundStyle(.white.opacity(0.25)).padding(13) }
                TextEditor(text: $message)
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(.white)
                    .frame(minHeight: 170)
                    .padding(7)
            }
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .vipCard()
    }

    private func send() {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let m = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = [t.isEmpty ? nil : "*\(t)*", m.isEmpty ? nil : m].compactMap { $0 }.joined(separator: "\n")
        var components = URLComponents()
        components.scheme = "https"
        components.host = "wa.me"
        components.path = "/\(whatsAppNumber)"
        components.queryItems = [URLQueryItem(name: "text", value: body)]
        guard let url = components.url else { return }
        UIApplication.shared.open(url)
    }
}
