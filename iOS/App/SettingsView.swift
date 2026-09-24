import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: TimerModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Color") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 12)], spacing: 16) {
                        ForEach(Theme.presets.indices, id: \.self) { index in
                            let preset = Theme.presets[index]
                            Button {
                                model.theme = preset.theme
                            } label: {
                                VStack(spacing: 6) {
                                    ThemeSwatch(theme: preset.theme, selected: model.theme == preset.theme)
                                    Text(preset.name)
                                        .font(.caption2)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                    ColorPicker("Disk color", selection: colorBinding(\.disk), supportsOpacity: false)
                    ColorPicker("Frame color", selection: colorBinding(\.frame), supportsOpacity: false)
                }

                Section {
                    Toggle("Keep screen awake", isOn: $model.keepAwake)
                    Toggle("Lock Screen & Dynamic Island", isOn: $model.liveActivityEnabled)
                } header: {
                    Text("While running")
                } footer: {
                    Text("Add the Pomodoro widget from your Home Screen or Lock Screen to see the dial at a glance.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func colorBinding(_ keyPath: WritableKeyPath<Theme, RGB>) -> Binding<Color> {
        Binding(
            get: { model.theme[keyPath: keyPath].color },
            set: { newValue in
                if let rgb = RGB(color: newValue) { model.theme[keyPath: keyPath] = rgb }
            }
        )
    }
}

/// Mini clock icon: frame, white face and a disk dot.
struct ThemeSwatch: View {
    let theme: Theme
    let selected: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(theme.bezelGradient)
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Palette.face).padding(5)
            Circle().fill(theme.disk.color).padding(13)
        }
        .frame(width: 52, height: 52)
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.accentColor, lineWidth: selected ? 3 : 0)
                .padding(-4)
        )
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
