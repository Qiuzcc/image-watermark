import SwiftUI

struct ContentView: View {
    @State private var viewModel = WatermarkViewModel()

    var body: some View {
        ZStack {
            HSplitView {
                // Left: Image list
                ImageListView(viewModel: viewModel)
                    .frame(minWidth: 300, idealWidth: 500)

                // Right: Preview + Settings
                VSplitView {
                    PreviewView(viewModel: viewModel)
                        .frame(minHeight: 200)

                    SettingsPanel(
                        settings: viewModel.settings,
                        outputFolderName: viewModel.outputFolderName,
                        onSelectFolder: { viewModel.selectOutputFolder() }
                    )
                    .frame(minHeight: 250, idealHeight: 280)
                }
                .frame(minWidth: 300, idealWidth: 400)
            }

            if viewModel.isProcessing {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()

                ProgressOverlay(
                    processedCount: viewModel.processedCount,
                    totalCount: viewModel.totalCount,
                    onCancel: { viewModel.cancelProcessing() }
                )
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    viewModel.importImages()
                } label: {
                    Label("导入图片", systemImage: "photo.badge.plus")
                }
                .help("选择要添加时间水印的图片")

                Button {
                    viewModel.selectOutputFolder()
                } label: {
                    Label("输出文件夹", systemImage: "folder.badge.gearshape")
                }
                .help("选择处理后图片的保存位置")

                Button {
                    viewModel.startBatchProcessing()
                } label: {
                    Label("开始处理", systemImage: "wand.and.stars")
                }
                .disabled(!viewModel.canProcess)
                .help("批量为所有图片添加时间水印并导出")
            }

            ToolbarItemGroup(placement: .secondaryAction) {
                Button {
                    viewModel.removeSelected()
                } label: {
                    Label("移除选中", systemImage: "trash")
                }
                .disabled(viewModel.selectedImageID == nil)
                .help("从列表中移除当前选中的图片")

                Button {
                    viewModel.clearAll()
                } label: {
                    Label("清空列表", systemImage: "xmark.circle")
                }
                .disabled(viewModel.images.isEmpty)
                .help("清空所有已导入的图片")
            }
        }
        .navigationTitle("图片时间水印")
    }
}

#Preview {
    ContentView()
}
