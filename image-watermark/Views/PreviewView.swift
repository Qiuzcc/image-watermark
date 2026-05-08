import SwiftUI

struct PreviewView: View {
    let viewModel: WatermarkViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("预览")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if let image = viewModel.generatePreview() {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(12)
            } else if viewModel.selectedImage != nil {
                VStack(spacing: 8) {
                    Image(systemName: "eye.slash")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    if viewModel.selectedImage?.exifDate == nil {
                        Text("该图片没有 EXIF 日期信息")
                            .foregroundStyle(.orange)
                    } else {
                        Text("无法生成预览")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("选择一张图片查看预览")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
