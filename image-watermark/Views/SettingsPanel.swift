import SwiftUI

struct SettingsPanel: View {
    @Bindable var settings: WatermarkSettings
    var outputFolderName: String
    var onSelectFolder: () -> Void

    var body: some View {
        Form {
            Section("水印设置") {
                TextField("日期格式", text: $settings.dateFormat)
                    .textFieldStyle(.roundedBorder)

                Picker("位置", selection: $settings.position) {
                    ForEach(WatermarkPosition.allCases, id: \.self) { pos in
                        Text(pos.rawValue).tag(pos)
                    }
                }

                HStack {
                    Text("字号")
                    Slider(value: $settings.fontSize, in: 0...200, step: 1)
                    Text(settings.fontSize == 0 ? "自动" : "\(Int(settings.fontSize))pt")
                        .frame(width: 50, alignment: .trailing)
                        .monospacedDigit()
                }

                ColorPicker("文字颜色", selection: $settings.textColor)

                Toggle("文字阴影", isOn: $settings.shadowEnabled)

                Toggle("显示设备信息", isOn: $settings.showDeviceInfo)

                Toggle("显示地理位置", isOn: $settings.showLocationInfo)

                HStack {
                    Text("透明度")
                    Slider(value: $settings.opacity, in: 0.1...1.0, step: 0.05)
                    Text("\(Int(settings.opacity * 100))%")
                        .frame(width: 40, alignment: .trailing)
                        .monospacedDigit()
                }
            }

            Section("输出") {
                HStack {
                    Label(outputFolderName, systemImage: "folder")
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("选择...") {
                        onSelectFolder()
                    }
                }

                HStack {
                    Text("压缩质量")
                    Slider(value: $settings.compressionQuality, in: 0.1...1.0, step: 0.05)
                    Text(settings.compressionQuality >= 1.0 ? "无压缩" : "\(Int(settings.compressionQuality * 100))%")
                        .frame(width: 55, alignment: .trailing)
                        .monospacedDigit()
                }
            }

            Section("格式说明") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("yyyy = 年, MM = 月, dd = 日")
                    Text("HH = 时, mm = 分, ss = 秒")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
