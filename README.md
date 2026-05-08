# Image Watermark

一个 macOS 原生应用，用于批量为照片添加时间水印。时间信息直接从图片文件的 EXIF 二进制数据中读取。

## 功能

- **批量导入** — 支持 JPEG、PNG、HEIC、TIFF 格式
- **EXIF 时间读取** — 从图片二进制数据中提取 DateTimeOriginal
- **时间水印** — 可自定义日期格式、位置（四角）、字号、颜色、透明度
- **设备信息水印** — 可选显示拍摄设备型号、焦距、光圈、ISO
- **地理位置水印** — 可选显示拍摄城市（通过 GPS 坐标反向编码）
- **批量导出** — 选择输出文件夹，并行处理，支持压缩质量调节
- **实时预览** — 所见即所得，水印比例与导出一致
- **保留元数据** — 输出图片保留原始 EXIF 信息

## 系统要求

- macOS 15.7+
- Xcode 26+

## 构建

```bash
xcodebuild -project image-watermark.xcodeproj -scheme image-watermark -destination 'platform=macOS' build
```

或在 Xcode 中打开 `image-watermark.xcodeproj` 直接运行。

## 技术栈

- SwiftUI + @Observable (UI 和状态管理)
- ImageIO / CGImageSource (EXIF 元数据读取，无需解码像素)
- CoreGraphics + Core Text (水印渲染，线程安全)
- CLGeocoder (GPS 坐标反向地理编码)
- Swift Concurrency / TaskGroup (批量并行处理)

## 项目结构

```
image-watermark/
├── image_watermarkApp.swift       App 入口
├── ContentView.swift              主界面布局
├── Models/
│   ├── WatermarkSettings.swift    水印配置模型
│   └── ImageItem.swift            图片数据模型
├── ViewModels/
│   └── WatermarkViewModel.swift   业务逻辑
├── Services/
│   ├── EXIFReader.swift           EXIF/GPS 数据读取
│   └── WatermarkRenderer.swift    水印渲染与保存
└── Views/
    ├── ImageListView.swift        图片网格列表
    ├── SettingsPanel.swift         配置面板
    ├── PreviewView.swift           水印预览
    └── ProgressOverlay.swift       处理进度
```

## License

MIT
