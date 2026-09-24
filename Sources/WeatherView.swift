import SwiftUI
import MapKit

struct WeatherView: View {
    @State private var model = WeatherViewModel()
    @State private var showUnits = false
    @State private var showDetails = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.sky(for: model.result).ignoresSafeArea()
                ambientGlow
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        topBar
                        searchBar
                        if !model.suggestions.isEmpty { suggestionPanel }

                        switch model.state {
                        case .idle:
                            EmptyState()
                        case .loading:
                            LoadingState()
                        case .failed(let message):
                            ErrorCard(message: message) { Task { await model.reload() } }
                            if let result = model.result { dashboard(result) }
                        case .loaded(let result):
                            dashboard(result)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }
                .refreshable { await model.reload() }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showUnits) {
                UnitPicker(current: model.unitSystem) { units in
                    Task { await model.changeUnits(units) }
                }
                .presentationDetents([.height(250)])
                .presentationDragIndicator(.visible)
            }
        }
        .task {
            if model.result == nil { await model.locateMe() }
        }
        .onChange(of: model.query) { _, newValue in
            model.updateSuggestions(for: newValue)
        }
    }

    private var ambientGlow: some View {
        GeometryReader { proxy in
            Circle()
                .fill(.cyan.opacity(0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 55)
                .offset(x: proxy.size.width * 0.58, y: -80)
            Circle()
                .fill(.blue.opacity(0.10))
                .frame(width: 300, height: 300)
                .blur(radius: 65)
                .offset(x: -120, y: proxy.size.height * 0.42)
        }
        .allowsHitTesting(false)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("WEATHERSHARE")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .tracking(2.2)
                    .foregroundStyle(.white.opacity(0.62))
                Text("Weather Intelligence")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            Spacer()
            Button { showUnits = true } label: {
                Text(model.unitSystem == .metric ? "°C" : "°F")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.08), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.10), lineWidth: 1))
            }
            Button { Task { await model.locateMe() } } label: {
                Image(systemName: "location.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.08), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.10), lineWidth: 1))
            }
            .accessibilityLabel("Dùng vị trí hiện tại")
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.45))
            TextField("Tìm thành phố, quốc gia…", text: $model.query)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .foregroundStyle(.white)
                .onSubmit { Task { await model.search() } }
            if model.isSearching {
                ProgressView().tint(.cyan)
            } else if !model.query.isEmpty {
                Button { model.query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            Button { Task { await model.search() } } label: {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(.black)
                    .frame(width: 32, height: 32)
                    .background(.cyan, in: Circle())
            }
            .disabled(model.isLoading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 19, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 1))
    }

    private var suggestionPanel: some View {
        VStack(spacing: 0) {
            ForEach(model.suggestions) { place in
                Button { Task { await model.select(place) } } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(.cyan)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(place.name)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text([place.admin1, place.country].compactMap { $0 }.joined(separator: " • "))
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.42))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2.bold())
                            .foregroundStyle(.white.opacity(0.25))
                    }
                    .padding(12)
                    .contentShape(Rectangle())
                }
                if place.id != model.suggestions.last?.id { Divider().overlay(.white.opacity(0.06)) }
            }
        }
        .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))
    }

    @ViewBuilder
    private func dashboard(_ result: WeatherResult) -> some View {
        HeroCard(result: result)
        MetricGrid(result: result)
        HourlyCard(result: result)
        DailyCard(result: result)
        SunriseCard(result: result)
        DetailsCard(result: result, expanded: $showDetails)
        MapCard(result: result)
        FooterCard(result: result)
    }
}

private struct HeroCard: View {
    let result: WeatherResult

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10, weight: .black))
                        Text(result.place.name)
                            .font(.system(size: 18, weight: .black, design: .rounded))
                    }
                    Text([result.place.admin1, result.place.country].compactMap { $0 }.joined(separator: " • "))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.48))
                }
                Spacer()
                Image(systemName: result.condition.symbol)
                    .font(.system(size: 48, weight: .medium))
                    .symbolRenderingMode(.multicolor)
            }

            HStack(alignment: .lastTextBaseline, spacing: 1) {
                Text(Int(result.current.temperature.rounded()), format: .number)
                    .font(.system(size: 92, weight: .thin, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text(result.units.temperature)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.52))
            }

            HStack(spacing: 8) {
                Text(result.condition.label)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text("•").foregroundStyle(.white.opacity(0.25))
                Text("Cảm giác \(Int(result.current.apparentTemperature.rounded()))°")
                    .foregroundStyle(.white.opacity(0.56))
            }

            Divider().overlay(.white.opacity(0.10))

            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                Text(localTime)
                Spacer()
                Text("Cập nhật \(relativeUpdate)")
                    .foregroundStyle(.white.opacity(0.40))
            }
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.66))
        }
        .vipCard(padding: 20)
        .background(LinearGradient(colors: [.white.opacity(0.10), .white.opacity(0.025)], startPoint: .topLeading, endPoint: .bottomTrailing), in: Theme.cardShape)
    }

    private var localTime: String {
        Date().formatted(.dateTime.weekday(.abbreviated).hour().minute().locale(Locale(identifier: "vi_VN")))
    }

    private var relativeUpdate: String {
        let seconds = max(0, Int(Date().timeIntervalSince(result.fetchedAt)))
        if seconds < 60 { return "vừa xong" }
        return "\(seconds / 60) phút trước"
    }
}

private struct MetricGrid: View {
    let result: WeatherResult

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            MetricCard(icon: "humidity.fill", title: "Độ ẩm", value: "\(result.current.humidity)%", tint: .cyan)
            MetricCard(icon: "wind", title: "Gió", value: "\(Int(result.current.windSpeed.rounded())) \(result.units.windSpeed)", tint: .mint)
            MetricCard(icon: "drop.fill", title: "Mưa hiện tại", value: "\(result.current.precipitation, specifier: "%.1f") \(result.units.precipitation)", tint: .blue)
            MetricCard(icon: "sun.max.fill", title: "UV", value: String(format: "%.1f %@", result.current.uvIndex, result.units.uvIndex), tint: .yellow)
        }
    }
}

private struct MetricCard: View {
    let icon: String
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.42))
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Spacer(minLength: 0)
        }
        .vipCard(padding: 13)
    }
}

private struct HourlyCard: View {
    let result: WeatherResult

    var body: some View {
        SectionCard(title: "24 GIỜ TỚI", subtitle: "Nhiệt độ • mưa • UV") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(result.hourly.prefix(24))) { hour in
                        VStack(spacing: 8) {
                            Text(label(hour.date))
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.43))
                            Image(systemName: hour.condition.symbol)
                                .font(.system(size: 20))
                                .symbolRenderingMode(.multicolor)
                            Text("\(Int(hour.temperature.rounded()))°")
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                            HStack(spacing: 2) {
                                Image(systemName: "drop.fill").font(.system(size: 7))
                                Text("\(hour.precipitationProbability)%")
                            }
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(.cyan)
                        }
                        .frame(width: 64)
                        .padding(.vertical, 12)
                        .background(hour.id == result.hourly.first?.id ? .cyan.opacity(0.12) : .white.opacity(0.035), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
        }
    }

    private func label(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)).locale(Locale(identifier: "vi_VN")))
    }
}

private struct DailyCard: View {
    let result: WeatherResult

    var body: some View {
        SectionCard(title: "7 NGÀY", subtitle: "Dự báo nhiệt độ và xác suất mưa") {
            VStack(spacing: 0) {
                ForEach(Array(result.daily.enumerated()), id: \.element.id) { index, day in
                    HStack(spacing: 10) {
                        Text(index == 0 ? "Hôm nay" : day.date.formatted(.dateTime.weekday(.abbreviated).locale(Locale(identifier: "vi_VN"))))
                            .font(.system(size: 12, weight: index == 0 ? .black : .medium, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 52, alignment: .leading)
                        Image(systemName: day.condition.symbol)
                            .font(.system(size: 18))
                            .symbolRenderingMode(.multicolor)
                            .frame(width: 26)
                        Text("\(day.precipitationProbability)%")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.cyan)
                        Spacer()
                        Text("\(Int(day.minTemperature.rounded()))°")
                            .foregroundStyle(.white.opacity(0.35))
                        Text("\(Int(day.maxTemperature.rounded()))°")
                            .fontWeight(.black)
                            .foregroundStyle(.white)
                    }
                    .font(.system(size: 13, design: .rounded))
                    .padding(.vertical, 11)
                    if index < result.daily.count - 1 { Divider().overlay(.white.opacity(0.06)) }
                }
            }
        }
    }
}

private struct SunriseCard: View {
    let result: WeatherResult

    var body: some View {
        HStack(spacing: 10) {
            SolarItem(title: "Bình minh", icon: "sunrise.fill", date: result.daily.first?.sunrise, timezone: result.timeZone)
            Divider().frame(height: 42).overlay(.white.opacity(0.08))
            SolarItem(title: "Hoàng hôn", icon: "sunset.fill", date: result.daily.first?.sunset, timezone: result.timeZone)
        }
        .vipCard(padding: 14)
    }
}

private struct SolarItem: View {
    let title: String
    let icon: String
    let date: Date?
    let timezone: TimeZone

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: icon).foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 10, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.42))
                Text(time).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var time: String {
        guard let date else { return "—" }
        var style = Date.FormatStyle.dateTime.hour().minute()
        style.timeZone = timezone
        return date.formatted(style)
    }
}

private struct DetailsCard: View {
    let result: WeatherResult
    @Binding var expanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { expanded.toggle() }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("CHI TIẾT THỜI TIẾT")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                        Text("Áp suất • UV • gió • lượng mưa")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.38))
                    }
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.white.opacity(0.45))
                }
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            if expanded {
                Divider().overlay(.white.opacity(0.08)).padding(.vertical, 14)
                VStack(spacing: 12) {
                    DetailRow(icon: "gauge.with.dots.needle.bottom.50percent", title: "Áp suất", value: "\(result.current.surfacePressure, specifier: "%.0f") \(result.units.surfacePressure)")
                    DetailRow(icon: "sun.max.fill", title: "UV hiện tại", value: String(format: "%.1f", result.current.uvIndex))
                    DetailRow(icon: "cloud.rain.fill", title: "Mưa hôm nay", value: "\(result.daily.first?.precipitationSum ?? 0, specifier: "%.1f") \(result.units.precipitation)")
                    DetailRow(icon: "wind", title: "Gió tối đa hôm nay", value: "\(Int((result.daily.first?.windSpeedMax ?? 0).rounded())) \(result.units.windSpeed)")
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .vipCard()
    }
}

private struct DetailRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).frame(width: 24).foregroundStyle(.cyan)
            Text(title).foregroundStyle(.white.opacity(0.50))
            Spacer()
            Text(value).fontWeight(.bold).foregroundStyle(.white)
        }
        .font(.system(size: 12, design: .rounded))
    }
}

private struct MapCard: View {
    let result: WeatherResult
    @State private var position: MapCameraPosition

    init(result: WeatherResult) {
        self.result = result
        _position = State(initialValue: .region(MKCoordinateRegion(center: result.place.coordinate, span: .init(latitudeDelta: 0.35, longitudeDelta: 0.35))))
    }

    var body: some View {
        SectionCard(title: "VỊ TRÍ", subtitle: "Khu vực dự báo hiện tại") {
            Map(position: $position) {
                Marker(result.place.name, systemImage: result.condition.symbol, coordinate: result.place.coordinate)
                    .tint(.cyan)
            }
            .mapStyle(.standard(elevation: .realistic))
            .frame(height: 190)
            .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
        }
    }
}

private struct FooterCard: View {
    let result: WeatherResult
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.shield.fill").foregroundStyle(.green)
            Text("Dữ liệu thời tiết: Open-Meteo • \(result.timeZone.identifier)")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.36))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }
}

private struct SectionCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .black, design: .rounded)).foregroundStyle(.white)
                Text(subtitle).font(.system(size: 10, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.35))
            }
            content
        }
        .vipCard()
    }
}

private struct EmptyState: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "cloud.sun.rain.fill")
                .font(.system(size: 54))
                .symbolRenderingMode(.multicolor)
            Text("Weather Intelligence")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text("Cho phép vị trí hoặc tìm một thành phố để bắt đầu.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.46))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }
}

private struct LoadingState: View {
    var body: some View {
        VStack(spacing: 14) {
            ProgressView().tint(.cyan).scaleEffect(1.2)
            Text("Đang lấy dữ liệu thời tiết…")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.56))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }
}

private struct ErrorCard: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text("Không tải được thời tiết").font(.system(size: 15, weight: .black, design: .rounded)).foregroundStyle(.white)
            }
            Text(message).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.55))
            Button("Thử lại", action: retry)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.cyan, in: Capsule())
        }
        .vipCard()
    }
}

private struct UnitPicker: View {
    let current: WeatherUnitSystem
    let onSelect: (WeatherUnitSystem) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Đơn vị hiển thị").font(.system(size: 20, weight: .black, design: .rounded))
            ForEach(WeatherUnitSystem.allCases) { unit in
                Button {
                    onSelect(unit)
                    dismiss()
                } label: {
                    HStack {
                        Text(unit.title).foregroundStyle(.primary)
                        Spacer()
                        if unit == current { Image(systemName: "checkmark.circle.fill").foregroundStyle(.cyan) }
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(24)
    }
}

#Preview { WeatherView().preferredColorScheme(.dark) }
