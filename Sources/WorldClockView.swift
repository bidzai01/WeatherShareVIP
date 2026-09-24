import SwiftUI
import Foundation
import Observation

struct WorldCity: Identifiable, Codable, Hashable {
    let name: String
    let country: String
    let timeZoneID: String
    var id: String { timeZoneID }
    var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }
}

enum WorldCityCatalog {
    static let all: [WorldCity] = [
        .init(name: "Singapore", country: "Singapore", timeZoneID: "Asia/Singapore"),
        .init(name: "Kuala Lumpur", country: "Malaysia", timeZoneID: "Asia/Kuala_Lumpur"),
        .init(name: "Jakarta", country: "Indonesia", timeZoneID: "Asia/Jakarta"),
        .init(name: "Bangkok", country: "Thailand", timeZoneID: "Asia/Bangkok"),
        .init(name: "Hong Kong", country: "Hong Kong", timeZoneID: "Asia/Hong_Kong"),
        .init(name: "Tokyo", country: "Japan", timeZoneID: "Asia/Tokyo"),
        .init(name: "Seoul", country: "South Korea", timeZoneID: "Asia/Seoul"),
        .init(name: "Dubai", country: "UAE", timeZoneID: "Asia/Dubai"),
        .init(name: "Paris", country: "France", timeZoneID: "Europe/Paris"),
        .init(name: "London", country: "United Kingdom", timeZoneID: "Europe/London"),
        .init(name: "New York", country: "United States", timeZoneID: "America/New_York"),
        .init(name: "Los Angeles", country: "United States", timeZoneID: "America/Los_Angeles"),
        .init(name: "Sydney", country: "Australia", timeZoneID: "Australia/Sydney"),
    ]

    static let defaults = ["Asia/Singapore", "Asia/Tokyo", "Europe/London", "America/New_York", "Australia/Sydney"]
}

@MainActor
@Observable
final class WorldClockStore {
    private static let key = "worldClock.cityIDs"
    var cities: [WorldCity] { didSet { save() } }

    init() {
        let ids = UserDefaults.standard.stringArray(forKey: Self.key) ?? WorldCityCatalog.defaults
        cities = ids.compactMap { id in WorldCityCatalog.all.first { $0.timeZoneID == id } }
    }

    func add(_ city: WorldCity) { guard !cities.contains(city) else { return }; cities.append(city) }
    func remove(at offsets: IndexSet) { cities.remove(atOffsets: offsets) }
    func move(from source: IndexSet, to destination: Int) { cities.move(fromOffsets: source, toOffset: destination) }

    private func save() { UserDefaults.standard.set(cities.map(\.timeZoneID), forKey: Self.key) }
}

struct WorldClockView: View {
    @State private var store = WorldClockStore()
    @State private var showPicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundTop.ignoresSafeArea()
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    List {
                        Section {
                            ForEach(store.cities) { city in
                                WorldClockRow(city: city, now: context.date)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                            .onDelete(perform: store.remove)
                            .onMove(perform: store.move)
                        } header: {
                            Text("GIỜ THẾ GIỚI")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundStyle(.white.opacity(0.42))
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Giờ thế giới")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton().tint(.cyan) }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showPicker = true } label: { Image(systemName: "plus") }
                        .tint(.cyan)
                }
            }
            .sheet(isPresented: $showPicker) { CityPicker(store: store) }
        }
    }
}

private struct WorldClockRow: View {
    let city: WorldCity
    let now: Date

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: isDay ? "sun.max.fill" : "moon.stars.fill")
                .foregroundStyle(isDay ? .yellow : .indigo)
                .frame(width: 30, height: 30)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(city.name).font(.system(size: 15, weight: .black, design: .rounded)).foregroundStyle(.white)
                Text("\(city.country) • \(offset)").font(.system(size: 10, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.38))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(time).font(.system(size: 18, weight: .black, design: .rounded)).monospacedDigit().foregroundStyle(.white)
                Text(day).font(.system(size: 9, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.38))
            }
        }
        .padding(13)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 19, style: .continuous).stroke(.white.opacity(0.07), lineWidth: 1))
        .padding(.vertical, 4)
    }

    private var isDay: Bool {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = city.timeZone
        return (6..<18).contains(calendar.component(.hour, from: now))
    }
    private var time: String {
        var style = Date.FormatStyle.dateTime.hour().minute().second(); style.timeZone = city.timeZone
        return now.formatted(style)
    }
    private var day: String {
        var style = Date.FormatStyle.dateTime.weekday(.abbreviated).month(.abbreviated).day(); style.timeZone = city.timeZone
        return now.formatted(style)
    }
    private var offset: String {
        let seconds = city.timeZone.secondsFromGMT(for: now) - TimeZone.current.secondsFromGMT(for: now)
        if seconds == 0 { return "cùng giờ" }
        let hours = Double(seconds) / 3600
        return String(format: "%+.1fh", hours).replacingOccurrences(of: ".0h", with: "h")
    }
}

private struct CityPicker: View {
    let store: WorldClockStore
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var cities: [WorldCity] {
        let remaining = WorldCityCatalog.all.filter { !store.cities.contains($0) }
        guard !search.isEmpty else { return remaining }
        return remaining.filter { $0.name.localizedCaseInsensitiveContains(search) || $0.country.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            List(cities) { city in
                Button {
                    store.add(city)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(city.name).foregroundStyle(.primary)
                        Text(city.country).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .searchable(text: $search, prompt: "Tìm thành phố")
            .navigationTitle("Thêm thành phố")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Xong") { dismiss() } } }
        }
    }
}

#Preview { WorldClockView().preferredColorScheme(.dark) }
