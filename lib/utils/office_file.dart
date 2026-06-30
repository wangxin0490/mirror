import 'safe_uri.dart';

/// Office 附件（无法在 WebView 内嵌预览）的扩展名判断。
bool isOfficeFilename(String filename) {
  final n = filename.trim().toLowerCase();
  if (n.isEmpty) return false;
  const exts = [
    '.doc', '.docx', '.dot', '.dotx', '.wps', '.wpt',
    '.xls', '.xlsx', '.xltx', '.xlsb', '.xlsm', '.xltm', '.et', '.ett', '.xlt',
    '.ppt', '.pptx', '.pot', '.potx', '.pps', '.ppsx', '.dps', '.dpt',
  ];
  return exts.any(n.endsWith);
}

String filenameFromUrl(String url) => safeFilenameFromUrl(url);

/// 是否应使用「打开并存储 / 仅打开」全屏引导页（图二），而非 WebView / 浏览器直链下载。
///
/// 图片除外；md/pdf/Office 等在全平台（含 Web）统一先进入引导页。
bool shouldUseFileOpenGuide({required String filename, String? kind}) {
  final k = kind?.trim().toLowerCase() ?? '';
  if (k == 'image') return false;
  if (isImageFilename(filename)) return false;
  return true;
}

bool isImageFilename(String filename) {
  final n = filename.trim().toLowerCase();
  if (n.isEmpty) return false;
  const exts = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic', '.bmp', '.svg'];
  return exts.any(n.endsWith);
}

/// Hermes / 附件下载链接触发 attachment 响应。
String fileDownloadUrl(String url) => safeFileDownloadUrl(url);
