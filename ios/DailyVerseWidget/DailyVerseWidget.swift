import SwiftUI
import WidgetKit

private let appGroupId = "group.com.tahram.gunlukduahadis"
private let widgetKind = "DailyVerseWidget"

struct DailyVerseEntry: TimelineEntry {
    let date: Date
    let verse: String
    let footer: String
    let listIndex: Int

    var destination: URL? {
        URL(string: "hergunislam://widgetVerse?i=\(listIndex)&homeWidget")
    }
}

struct DailyVerseProvider: TimelineProvider {
    private var preferences: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    func placeholder(in context: Context) -> DailyVerseEntry {
        DailyVerseEntry(
            date: Date(),
            verse: "Şüphesiz güçlükle beraber bir kolaylık vardır.",
            footer: "İNŞİRÂH SURESİ, 5. AYET",
            listIndex: 0
        )
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (DailyVerseEntry) -> Void
    ) {
        completion(makeEntry())
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<DailyVerseEntry>) -> Void
    ) {
        let entry = makeEntry()
        let nextRefresh = Calendar.current.date(
            byAdding: .hour,
            value: 6,
            to: Date()
        ) ?? Date().addingTimeInterval(21_600)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func makeEntry() -> DailyVerseEntry {
        let verse = preferences?.string(forKey: "ayah_turkish")
        let footer = preferences?.string(forKey: "ayah_footer")
        let listIndex = preferences?.integer(forKey: "widget_hatim_index") ?? 0

        return DailyVerseEntry(
            date: Date(),
            verse: verse?.isEmpty == false
                ? verse!
                : "Ayetin hazırlanması için uygulamayı bir kez açın.",
            footer: footer?.isEmpty == false
                ? footer!
                : "HER GÜN İSLAM",
            listIndex: listIndex
        )
    }
}

struct DailyVerseWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: DailyVerseEntry

    private var isSmall: Bool { family == .systemSmall }
    private var isLarge: Bool { family == .systemLarge }

    var body: some View {
        widgetContent
            .widgetURL(entry.destination)
            .herGunIslamWidgetBackground()
    }

    private var widgetContent: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x002542), Color(hex: 0x183B5B)],
                startPoint: .leading,
                endPoint: .trailing
            )

            Circle()
                .fill(Color(hex: 0x31685A).opacity(0.22))
                .frame(width: 120, height: 120)
                .offset(x: isSmall ? 70 : 150, y: -70)

            Circle()
                .fill(Color(hex: 0xD5A94E).opacity(0.10))
                .frame(width: 150, height: 150)
                .offset(x: isSmall ? -70 : -160, y: 85)

            VStack(alignment: .leading, spacing: isSmall ? 9 : 11) {
                header

                Rectangle()
                    .fill(Color.white.opacity(0.16))
                    .frame(height: 1)

                Text(entry.verse)
                    .font(.system(size: isSmall ? 13 : 15, weight: .medium))
                    .foregroundColor(Color(hex: 0xF7F5EF))
                    .lineSpacing(3)
                    .lineLimit(isLarge ? 12 : (isSmall ? 5 : 6))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                footer
            }
            .padding(isSmall ? 13 : 16)
        }
    }

    private var header: some View {
        HStack(spacing: 9) {
            Text("☾")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color(hex: 0xD5A94E))
                .frame(width: 31, height: 31)
                .background(
                    Circle().fill(Color(hex: 0x31685A).opacity(0.28))
                )
                .overlay(Circle().stroke(Color(hex: 0xD5A94E).opacity(0.65), lineWidth: 1))

            VStack(alignment: .leading, spacing: 1) {
                Text("HER GÜN İSLAM")
                    .font(.system(size: isSmall ? 9 : 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(Color(hex: 0xF7F5EF))
                if !isSmall {
                    Text("Günün ayeti")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color(hex: 0xB2EBDA))
                }
            }

            Spacer(minLength: 0)

            if !isSmall {
                Text("AÇ")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color(hex: 0xF7F5EF))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(Color(hex: 0x31685A).opacity(0.30))
                    )
                    .overlay(Capsule().stroke(Color(hex: 0xB2EBDA).opacity(0.30), lineWidth: 1))
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: 0xD5A94E))
                .frame(width: 3, height: 14)

            Text(entry.footer)
                .font(.system(size: isSmall ? 8 : 9, weight: .bold))
                .foregroundColor(Color(hex: 0xD5A94E))
                .lineLimit(1)

            Spacer(minLength: 4)

            if !isSmall {
                Text("OKU  ›")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color(hex: 0xB2EBDA))
            }
        }
    }
}

struct DailyVerseWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: widgetKind, provider: DailyVerseProvider()) { entry in
            DailyVerseWidgetView(entry: entry)
        }
        .configurationDisplayName("Her Gün İslam • Günlük Ayet")
        .description("Günün ayetini ana ekranınızda okuyun.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private let prayerTimesWidgetKind = "PrayerTimesWidget"

struct PrayerWidgetMoment: Codable, Identifiable {
    let name: String
    let time: String
    let at: Int64

    var id: Int64 { at }

    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(at) / 1_000)
    }
}

struct PrayerTimesEntry: TimelineEntry {
    let date: Date
    let city: String
    let schedule: [PrayerWidgetMoment]

    var destination: URL? {
        URL(string: "hergunislam://prayer")
    }
}

struct PrayerTimesProvider: TimelineProvider {
    private var preferences: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    func placeholder(in context: Context) -> PrayerTimesEntry {
        PrayerTimesEntry(
            date: Date(),
            city: "İstanbul",
            schedule: Self.previewSchedule
        )
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (PrayerTimesEntry) -> Void
    ) {
        completion(makeEntry(at: Date()))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<PrayerTimesEntry>) -> Void
    ) {
        let now = Date()
        let schedule = loadSchedule()
        let city = preferences?.string(forKey: "prayer_widget_city") ?? "Şehir seçilmedi"
        let cutoff = Calendar.current.date(byAdding: .hour, value: 26, to: now)
            ?? now.addingTimeInterval(93_600)
        let transitionDates = schedule
            .map(\.date)
            .filter { $0 > now && $0 <= cutoff }
            .map { $0.addingTimeInterval(1) }
        let dates = [now] + transitionDates
        let entries = dates.map {
            PrayerTimesEntry(date: $0, city: city, schedule: schedule)
        }
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? cutoff
        let nextDayStart = Calendar.current.startOfDay(for: tomorrow)
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 1, to: nextDayStart)
            ?? nextDayStart

        completion(Timeline(entries: entries, policy: .after(refreshDate)))
    }

    private func makeEntry(at date: Date) -> PrayerTimesEntry {
        PrayerTimesEntry(
            date: date,
            city: preferences?.string(forKey: "prayer_widget_city") ?? "Şehir seçilmedi",
            schedule: loadSchedule()
        )
    }

    private func loadSchedule() -> [PrayerWidgetMoment] {
        guard
            let json = preferences?.string(forKey: "prayer_widget_schedule_json"),
            let data = json.data(using: .utf8),
            let schedule = try? JSONDecoder().decode([PrayerWidgetMoment].self, from: data)
        else {
            return []
        }
        return schedule.sorted { $0.at < $1.at }
    }

    private static var previewSchedule: [PrayerWidgetMoment] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let values: [(String, Int, Int)] = [
            ("İmsak", 5, 18),
            ("Güneş", 6, 42),
            ("Öğle", 13, 8),
            ("İkindi", 16, 52),
            ("Akşam", 20, 12),
            ("Yatsı", 21, 43),
        ]
        return values.compactMap { name, hour, minute in
            guard let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: start) else {
                return nil
            }
            return PrayerWidgetMoment(
                name: name,
                time: String(format: "%02d:%02d", hour, minute),
                at: Int64(date.timeIntervalSince1970 * 1_000)
            )
        }
    }
}

struct PrayerTimesWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PrayerTimesEntry
    private var nextMoment: PrayerWidgetMoment? { entry.schedule.first { $0.date > entry.date } }
    private var todaysMoments: [PrayerWidgetMoment] {
        entry.schedule.filter { Calendar.current.isDate($0.date, inSameDayAs: entry.date) }
    }
    private let names = ["İmsak", "Güneş", "Öğle", "İkindi", "Akşam", "Yatsı"]
    private func clock(_ name: String) -> String {
        todaysMoments.first { $0.name == name || (name == "İmsak" && $0.name == "Sabah") }?.time ?? "--:--"
    }
    var body: some View {
        GeometryReader { geometry in
            let small = family == .systemSmall
            let large = family == .systemLarge
            let compact = geometry.size.height < (small ? 170 : 135)
            VStack(alignment: .leading, spacing: compact ? 4 : 8) {
                HStack(spacing: 5) {
                    Image(systemName: "moon.stars.fill").foregroundColor(Color(hex: 0xD5A94E))
                    Text(entry.city).font(.system(size: compact ? 10 : 13, weight: .semibold))
                        .lineLimit(1).minimumScaleFactor(0.75)
                    Spacer(minLength: 0)
                }
                if let moment = nextMoment {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(moment.name == "Sabah" ? "İmsak" : moment.name)
                            .font(.system(size: compact ? 15 : 20, weight: .bold))
                        Spacer(minLength: 0)
                        Text(moment.time).font(.system(size: compact ? 18 : 24, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: 0xD5A94E))
                    }.lineLimit(1).minimumScaleFactor(0.7)
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                        Text(moment.date, style: .timer).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                    }.font(.system(size: compact ? 10 : 12)).foregroundColor(Color(hex: 0xB2EBDA))
                } else {
                    Text("Vakitleri yenilemek için uygulamayı açın.")
                        .font(.system(size: 11)).lineLimit(2).minimumScaleFactor(0.8)
                }
                if large { Spacer(minLength: 0) }
                if small && compact {
                    HStack {
                        Text("İmsak " + clock("İmsak"))
                        Spacer(minLength: 0)
                        Text("Güneş " + clock("Güneş"))
                    }.font(.system(size: 9, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
                } else {
                    let columns = small || large ? 3 : 6
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: columns), spacing: large ? 16 : 4) {
                        ForEach(names, id: \.self) { name in
                            VStack(spacing: 2) {
                                Text(name).font(.system(size: large ? 13 : 9, weight: .medium))
                                    .foregroundColor(Color(hex: 0xB2EBDA))
                                Text(clock(name)).font(.system(size: large ? 19 : 11, weight: .bold, design: .rounded))
                            }.lineLimit(1).minimumScaleFactor(0.7).frame(maxWidth: .infinity)
                        }
                    }
                }
                if large { Spacer(minLength: 0) }
            }
            .foregroundColor(Color(hex: 0xF7F5EF))
            .padding(compact ? 7 : 12)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .background(LinearGradient(colors: [Color(hex: 0x002542), Color(hex: 0x183B5B)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .widgetURL(entry.destination)
        .herGunIslamWidgetBackground()
    }
}

struct PrayerTimesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: prayerTimesWidgetKind, provider: PrayerTimesProvider()) { entry in
            PrayerTimesWidgetView(entry: entry)
        }
        .configurationDisplayName("Her Gün İslam • Namaz Vakitleri")
        .description("Sıradaki namazı, vakitleri ve canlı geri sayımı ana ekranınızda görün.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct DailyVerseWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyVerseWidget()
        PrayerTimesWidget()
    }
}

private extension View {
    @ViewBuilder
    func herGunIslamWidgetBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(.clear, for: .widget)
        } else {
            self
        }
    }
}

private extension Color {
    init(hex: UInt) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
