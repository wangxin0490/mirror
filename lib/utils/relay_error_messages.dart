/// 错误码 → 通俗易懂的提醒文案（不展示技术术语）。
class RelayErrorMessages {
  RelayErrorMessages._();

  static const userErrorPrefix = '抱歉，';

  static String userMessage({String? code, String? upstream}) {
    final text = upstream?.trim() ?? '';
    if (isUserFacingError(text)) return text;

    final fromUpstream = _fromUpstream(text);
    if (fromUpstream != null) return fromUpstream;

    final status = int.tryParse(code ?? '');
    if (status != null) return _fromStatus(status);

    return switch (code) {
      '40900' => '${userErrorPrefix}上一条回复仍在生成中，请稍后再试。',
      'timeout' => '${userErrorPrefix}等太久了，请再试一次。',
      'stream_error' => '${userErrorPrefix}网络不太稳定，请检查一下网络后再试。',
      'incomplete' => '${userErrorPrefix}回复中断了，请再试一次。',
      'relay_error' => '${userErrorPrefix}暂时无法获取回复，请稍后再试。',
      _ => '${userErrorPrefix}暂时无法获取回复，请稍后再试。',
    };
  }

  static bool isUserFacingError(String text) {
    return text.startsWith(userErrorPrefix);
  }

  static String? _fromUpstream(String lowerSource) {
    final lower = lowerSource.toLowerCase();
    if (lower.isEmpty) return null;
    if (_containsAny(lower, [
      'invalid token', 'invalid_api_key', 'incorrect api key', 'unauthorized', 'authentication',
    ])) {
      return '${userErrorPrefix}暂时无法回复，请稍后再试，或换一个模型试试。';
    }
    if (_containsAny(lower, [
      'insufficient_user', 'insufficient_quota', 'quota exceeded',
      'exceeded your current quota', '余额不足', '额度不足',
    ])) {
      return '${userErrorPrefix}暂时无法继续，请稍后再试或换一个模型试试。';
    }
    if (_containsAny(lower, ['rate limit', 'too many requests', '请求过于频繁'])) {
      return '${userErrorPrefix}你发送得太快了，稍等一会儿再试。';
    }
    if (_containsAny(lower, ['model_not_found', 'model not found', 'does not exist', 'no such model'])) {
      return '${userErrorPrefix}这个模型暂时用不了，请换一个试试。';
    }
    if (_containsAny(lower, ['invalid assistant message', 'content or tool_calls must be set'])) {
      return '${userErrorPrefix}对话记录有点问题，请新建会话后再试。';
    }
    if (_containsAny(lower, [
      'context length', 'maximum context', 'token limit', 'too long', 'context_length_exceeded',
    ])) {
      return '${userErrorPrefix}对话内容太长了，请缩短一些再发。';
    }
    if (_containsAny(lower, ['content policy', 'content filter', 'safety', 'moderation', '违规'])) {
      return '${userErrorPrefix}这条消息可能不太合适，请改一下说法再试。';
    }
    if (_containsAny(lower, ['timeout', 'timed out', 'deadline exceeded'])) {
      return '${userErrorPrefix}等了一会儿还没收到回复，请再试一次。';
    }
    if (_containsAny(lower, ['conversation busy', '仍在生成'])) {
      return '${userErrorPrefix}上一条回复仍在生成中，请稍后再试。';
    }
    if (_containsAny(lower, ['overloaded', 'capacity', 'server busy', 'try again later'])) {
      return '${userErrorPrefix}现在用的人比较多，请稍后再试。';
    }
    if (_containsAny(lower, ['bad gateway', 'gateway error', 'upstream'])) {
      return '${userErrorPrefix}服务暂时出了点问题，请稍后再试。';
    }
    return null;
  }

  static String _fromStatus(int status) => switch (status) {
        40900 => '${userErrorPrefix}上一条回复仍在生成中，请稍后再试。',
        400 => '${userErrorPrefix}这条消息好像有点问题，请改一改再发。',
        401 => '${userErrorPrefix}暂时无法回复，请稍后再试，或换一个模型试试。',
        402 => '${userErrorPrefix}暂时无法继续，请稍后再试或换一个模型试试。',
        403 => '${userErrorPrefix}你暂时还不能使用这个模型，请联系客服了解详情。',
        404 => '${userErrorPrefix}找不到这个模型了，请换一个试试。',
        408 => '${userErrorPrefix}等了一会儿还没收到回复，请再试一次。',
        413 => '${userErrorPrefix}你发送的内容太多了，请缩短后再试。',
        429 => '${userErrorPrefix}你发送得太快了，稍等一会儿再试。',
        500 => '${userErrorPrefix}出了点小状况，请稍后再试。',
        502 || 503 || 504 => '${userErrorPrefix}服务暂时出了点问题，请稍后再试。',
        >= 400 => '${userErrorPrefix}暂时无法获取回复，请稍后再试。',
        _ => '${userErrorPrefix}暂时无法获取回复，请稍后再试。',
      };

  static bool _containsAny(String s, List<String> needles) {
    for (final n in needles) {
      if (s.contains(n)) return true;
    }
    return false;
  }
}
