import 'dart:async';

import 'package:http/http.dart' as http;

/// 流取消标记（SSE 客户端与 [ChatStreamHandle] 共享）。
class StreamCancelFlag {
  var value = false;
  bool isSet() => value;
}

/// SSE 运行时可注册的立即中止（完成 completer、取消订阅），避免仅关连接时长时间挂起。
class StreamAbortRegistration {
  void Function()? _abort;

  void bind(void Function() abort) {
    _abort = abort;
  }

  void invoke() {
    _abort?.call();
  }
}

/// 可取消的 SSE 流（关闭底层 HTTP 连接以停止生成）。
class ChatStreamHandle {
  ChatStreamHandle(
    this._client,
    this.done,
    this._cancelled, [
    StreamAbortRegistration? abortRegistration,
  ]) : _abortRegistration = abortRegistration;

  final http.Client _client;
  final Future<void> done;
  final StreamCancelFlag _cancelled;
  final StreamAbortRegistration? _abortRegistration;

  bool get cancelled => _cancelled.value;

  void cancel() {
    if (_cancelled.value) return;
    _cancelled.value = true;
    _abortRegistration?.invoke();
    _client.close();
  }
}
