import SwiftUI

struct AboutView: View {
    private let dataSourceURL = URL(string: "https://open-meteo.com")!

    private var version: String {
        let info = Bundle.main.infoDictionary ?? [:]
        return "\(info["CFBundleShortVersionString"] as? String ?? "2.0.0") (\(info["CFBundleVersion"] as? String ?? "1"))"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundTop.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        brand
                        InfoCard(icon: "cloud.sun.rain.fill", title: "Weather Intelligence", text: "Dự báo thời tiết theo vị trí hoặc thành phố, biểu đồ 24 giờ, 7 ngày, bản đồ và các chỉ số chi tiết.")
                        InfoCard(icon: "network", title: "Nguồn dữ liệu", text: "Dữ liệu thời tiết được cung cấp bởi Open-Meteo.")
                        Link(destination: dataSourceURL) {
                            HStack {
                                Image(systemName: "globe")
                                Text("Mở Open-Meteo")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                            }
                            .foregroundStyle(.cyan)
                            .vipCard()
                        }
                        VStack(spacing: 5) {
                            Text("Version \(version)")
                            Text("Developer : By Anh Khôi")
                        }
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.34))
                    }
                    .padding(18)
                }
            }
            .navigationTitle("Ứng dụng")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var brand: some View {
        VStack(spacing: 10) {
            Image(systemName: "cloud.sun.rain.fill")
                .font(.system(size: 54))
                .symbolRenderingMode(.multicolor)
            Text("WEATHERSHARE")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .tracking(3)
                .foregroundStyle(.white)
            Text("VIP Weather Experience")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.cyan)
        }
        .padding(.vertical, 25)
        .frame(maxWidth: .infinity)
    }
}

private struct InfoCard: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .font(.title3.bold())
                .foregroundStyle(.cyan)
                .frame(width: 34, height: 34)
                .background(.cyan.opacity(0.10), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 15, weight: .black, design: .rounded)).foregroundStyle(.white)
                Text(text).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.45))
            }
            Spacer(minLength: 0)
        }
        .vipCard()
    }
}
