# mirror · Android 打包与扫码下载

## 环境要求

1. 安装 [Android Studio](https://developer.android.com/studio) 或 Android SDK
2. 设置环境变量 `ANDROID_HOME`（指向 SDK 目录）
3. 本机已安装 Flutter 且 `flutter doctor` 通过 Android 项

## 国内网络加速（推荐）

`assembleRelease` 卡住多半是 Gradle/Maven 从国外下载。项目已配置：

- Gradle 发行包：腾讯云镜像
- Maven 依赖：阿里云 + 腾讯云
- Flutter pub：`pub.flutter-io.cn`

打包脚本会自动设置环境变量。手动构建前可先执行：

```powershell
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
```

若仍很慢，先 **Ctrl+C** 停掉当前构建，再重新运行打包脚本。

## 一键打包

```powershell
cd mirror
.\scripts\build_android_release.ps1
```

产物：

| 文件 | 说明 |
|------|------|
| `release/mirror.apk` | 安装包 |
| `release/download.html` | 扫码下载页（与 apk 同目录） |

默认 API：`http://115.159.46.108:8100`（可用 `-ApiBase` 覆盖）

## 扫码下载部署

将 **`release` 整个目录** 上传到可公网访问的 HTTP 路径，例如：

```
http://115.159.46.108:8080/release/download.html
http://115.159.46.108:8080/release/mirror.apk
```

手机浏览器打开 `download.html`，扫码即可下载。

> APK 与 `download.html` 必须在同一 URL 目录下，否则二维码链接会失效。

## 真机调试

```powershell
flutter run -d <device_id> --dart-define=API_BASE=http://115.159.46.108:8100
```

- **应用名**：mirror（桌面显示）
- **图标**：原型 Mirror sigil（深底 + 镜面图形）
- **布局**：真机全屏，无 Web 手机外框缩放，避免页面变形
- **网络**：已允许 HTTP 明文（对接当前 API 地址）

## Web 原型

Chrome 调试仍使用手机框画廊布局，不受影响：

```powershell
.\scripts\run_web_dev.ps1
```
