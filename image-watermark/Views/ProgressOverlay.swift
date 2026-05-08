import SwiftUI

struct ProgressOverlay: View {
    let processedCount: Int
    let totalCount: Int
    let onCancel: () -> Void

    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(processedCount) / Double(totalCount)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("正在处理图片...")
                .font(.headline)

            ProgressView(value: progress)
                .frame(width: 300)

            Text("\(processedCount) / \(totalCount)")
                .monospacedDigit()
                .foregroundStyle(.secondary)

            Button("取消") {
                onCancel()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(32)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
