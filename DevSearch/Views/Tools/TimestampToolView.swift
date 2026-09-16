import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct TimestampToolView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var toolbox: ToolboxModel
    @State private var result: TimestampConversion?
    @State private var error: String?
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("转换方向", selection: model.toolPreference(\.timestampDirection)) {
                ForEach(TimestampDirection.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)

            GroupBox("输入") {
                VStack(alignment: .leading, spacing: 12) {
                    if prefs.timestampDirection == .timestampToDate {
                        HStack {
                            TextField("例如 1723723200", text: $toolbox.timestampInput)
                                .textFieldStyle(.roundedBorder)
                                .font(.body.monospaced())
                                .accessibilityIdentifier("toolbox-primary-input")
                                .focused($isInputFocused)
                            Picker("单位", selection: model.toolPreference(\.timestampUnit)) {
                                ForEach(TimestampUnit.allCases) { Text($0.title).tag($0) }
                            }
                            .frame(width: 150)
                            Button("使用剪贴板") {
                                if let value = model.toolboxClipboardText() { toolbox.timestampInput = value }
                            }
                        }
                    } else {
                        DatePicker(
                            "日期与时间",
                            selection: $toolbox.timestampDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .accessibilityIdentifier("toolbox-primary-input")
                        .focused($isInputFocused)
                    }
                    HStack {
                        Picker("时区", selection: model.toolPreference(\.timestampTimeZoneIdentifier)) {
                            ForEach(timeZoneIdentifiers, id: \.self) { identifier in
                                Text(timeZoneName(identifier)).tag(identifier)
                            }
                        }
                        .frame(maxWidth: 320)
                        Button("使用当前时间") {
                            if prefs.timestampDirection == .timestampToDate {
                                toolbox.timestampInput = String(Int(Date().timeIntervalSince1970))
                            } else {
                                toolbox.timestampDate = Date()
                            }
                        }
                    }
                }
                .padding(4)
            }

            if let error { ToolErrorLabel(error) }

            GroupBox("换算结果") {
                VStack(spacing: 0) {
                    TimestampResultRow(title: "Unix 秒", value: result?.seconds ?? "—")
                    Divider()
                    TimestampResultRow(title: "Unix 毫秒", value: result?.milliseconds ?? "—")
                    Divider()
                    TimestampResultRow(title: "ISO 8601", value: result?.iso8601 ?? "—")
                    Divider()
                    TimestampResultRow(title: "可读日期", value: result?.readable ?? "—")
                }
            }
            Spacer()
        }
        .padding(20)
        .onReceive(NotificationCenter.default.publisher(for: .toolboxFocusInput)) { _ in
            isInputFocused = true
        }
        .task(id: TimestampRequest(
            input: toolbox.timestampInput,
            date: toolbox.timestampDate,
            direction: prefs.timestampDirection,
            unit: prefs.timestampUnit,
            timeZoneIdentifier: prefs.timestampTimeZoneIdentifier
        )) {
            let timeZone = TimeZone(identifier: prefs.timestampTimeZoneIdentifier) ?? .current
            do {
                if prefs.timestampDirection == .timestampToDate {
                    guard !toolbox.timestampInput.isEmpty else { result = nil; error = nil; return }
                    result = try TimestampService.convert(
                        timestamp: toolbox.timestampInput,
                        unit: prefs.timestampUnit,
                        timeZone: timeZone
                    )
                } else {
                    result = TimestampService.convert(date: toolbox.timestampDate, timeZone: timeZone)
                }
                error = nil
            } catch {
                result = nil
                self.error = error.localizedDescription
            }
        }
    }

    private var prefs: ToolboxPreferences { model.data.toolboxPreferences }
    private var timeZoneIdentifiers: [String] {
        let values = [TimeZone.current.identifier, "UTC", "Asia/Shanghai", "America/Los_Angeles", "Europe/London"]
        var seen: Set<String> = []
        return values.filter { seen.insert($0).inserted }
    }

    private func timeZoneName(_ identifier: String) -> String {
        if identifier == TimeZone.current.identifier { return "本地（\(identifier)）" }
        return identifier
    }

}
