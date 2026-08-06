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

@main
struct DailyVerseWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyVerseWidget()
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
