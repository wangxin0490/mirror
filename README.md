# Mirror Mobile — Flutter 可交互原型

将 `index.html`（v0.3）转为**可直接操作**的手机 App 原型：单屏界面、底部 Tab、页面跳转（非画廊介绍页）。

## 运行

```bash
cd mirror   # 解压后的项目目录
flutter pub get
flutter run -d chrome
# 或 flutter run -d macos
```

### 本地后端 API

默认连接 **`http://127.0.0.1:8100`**（与 `lib/config/api_config.dart` 一致）。请先在本机启动 Mirror 后端（监听 `0.0.0.0:8100`），再跑前端。

```powershell
# 推荐：带 API_BASE 的 Web 热重载
.\scripts\run_web_dev.ps1

# 手机浏览器走局域网
.\scripts\run_web_lan.ps1
```

切回远程服务器：

```bash
flutter run -d chrome --dart-define=API_BASE=http://115.159.46.108:8100
```

更完整的交付说明见 [交付说明.md](交付说明.md)。

### Network Ninja 抓包（调试）

| 场景 | 开关 |
|------|------|
| `flutter run` Debug | 默认开启 |
| Release APK 内调试 | 打包时加 `--dart-define=NETWORK_NINJA=true` |

```powershell
# 正式包 + 抓包悬浮球（给测试同事）
.\scripts\build_android_release.ps1 -NetworkNinja

# 或手动
flutter build apk --release --dart-define=API_BASE=http://115.159.46.108:8100 --dart-define=NETWORK_NINJA=true
```

关闭：不传 `NETWORK_NINJA` 即可（Release 默认关）。仅记录经 `ApiClient`（Dio）的请求。

**看不到悬浮球？**

| 情况 | 原因 / 处理 |
|------|-------------|
| `flutter build apk --release` 且未加 `-NetworkNinja` | Release 默认关闭，需 `.\scripts\build_android_release.ps1 -NetworkNinja` |
| Chrome 打开 `build/web` 正式包 | 与 Release 相同，需构建时加 `--dart-define=NETWORK_NINJA=true` |
| `flutter run -d chrome` Debug | 默认应开启；球在**浏览器窗口右下角**（手机框外灰底区），不在手机框内 |
| 有球但列表为空 | 仅抓 `ApiClient`（Dio）；`http` 直传的上传等不会出现在 Ninja 里 |
| 仍看不到第三方悬浮球 | 看屏幕左下角黑色 **API** 按钮（应用内固定入口），点击进入抓包列表 |

## 交互说明

| 操作 | 结果 |
|------|------|
| 启动页 · 邮箱注册 / 第三方登录 | 进入主界面 |
| 底部 Tab | 切换 生态 / 对话 / 知识库 / 我的（默认生态） |
| 对话 · Mirror 置顶卡 | 进入与 Mirror 聊天 |
| 对话 · 右上角联系人 | 进入通讯录 |
| 对话 · 联系人列表 | 进入好友聊天 |
| 我的 · 工具箱 | 查看各技能 Token 消耗 |
| 生态 · 帖子卡片 | 帖子详情 |
| 帖子 · 分享 | 转发浮层 |
| 我的 · 灵魂/记忆/技能等 | 进入子页面，左上角返回 |

桌面/Web 宽屏会显示居中手机框；窄屏为全屏 App。

## 项目结构

| 路径 | 说明 |
|------|------|
| `lib/app/mirror_prototype.dart` | 导航与 Tab 状态 |
| `lib/widgets/prototype_shell.dart` | 手机框 / 全屏外壳 |
| `lib/screens/mirror_screens*.dart` | 各页面 UI |
| `lib/pages/gallery_page.dart` | 旧版 15 屏画廊（保留，非默认入口） |
| `index.html` | 原始 HTML 原型 |
