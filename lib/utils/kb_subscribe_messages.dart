/// 知识库订阅 API 错误文案本地化。
abstract final class KbSubscribeMessages {
  static const defaultFailure = '订阅失败，请稍后重试';

  static String failure(String? apiMessage) {
    final mapped = _map(apiMessage);
    if (mapped != null) return mapped;
    final trimmed = apiMessage?.trim();
    if (trimmed != null && trimmed.isNotEmpty && !_looksLikeInternal(trimmed)) {
      return trimmed;
    }
    return defaultFailure;
  }

  static String? _map(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final s = raw.toLowerCase();
    if (s.contains('cannot subscribe own') ||
        s.contains('own kb') ||
        raw.contains('不能订阅自己的知识库')) {
      return '不能订阅自己的知识库，请在「知识库」→「个人知识库」中管理';
    }
    if (s.contains('no ready documents') ||
        s.contains('has no ready') ||
        raw.contains('暂无可订阅')) {
      return '知识库暂无可订阅文档';
    }
    if (raw.contains('文档解析中')) {
      return '文档解析中，请稍后再试';
    }
    return null;
  }

  static bool _looksLikeInternal(String msg) {
    final s = msg.toLowerCase();
    return s.contains('internal') || s.startsWith('error') || s.contains('cannot subscribe');
  }
}
