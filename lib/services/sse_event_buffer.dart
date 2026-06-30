/// 解析 SSE 文本块（与 Agent / ASR 流式接口共用）。
class SseEventBuffer {
  final StringBuffer _buf = StringBuffer();

  void add(String chunk, void Function(String event, String data) onEvent) {
    _buf.write(chunk);
    var text = _buf.toString();
    while (true) {
      final sep = text.indexOf('\n\n');
      if (sep < 0) break;
      final block = text.substring(0, sep);
      text = text.substring(sep + 2);
      var event = '';
      var data = '';
      for (final line in block.split('\n')) {
        if (line.startsWith('event:')) {
          event = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          data = line.substring(5).trim();
        }
      }
      if (event.isNotEmpty && data.isNotEmpty) {
        onEvent(event, data);
      }
    }
    _buf
      ..clear()
      ..write(text);
  }
}
