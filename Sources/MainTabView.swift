import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            WeatherView()
                .tabItem { Label("Thời tiết", systemImage: "cloud.sun.fill") }
            WorldClockView()
                .tabItem { Label("Giờ thế giới", systemImage: "globe.americas.fill") }
            FeedbackView()
                .tabItem { Label("Phản hồi", systemImage: "bubble.left.and.bubble.right.fill") }
            AboutView()
                .tabItem { Label("Ứng dụng", systemImage: "sparkles") }
        }
        .tint(Theme.accent)
    }
}

#Preview { MainTabView().preferredColorScheme(.dark) }
