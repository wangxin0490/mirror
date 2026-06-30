/// 兼容旧 import；新代码请使用 [KbVoiceSessionController] 或 [VoiceRecordConfig]。
library;

import 'kb_voice_session_controller.dart';

export 'voice_record_shared.dart';
export 'kb_voice_session_controller.dart';

/// @deprecated 使用 [KbVoiceSessionController]
typedef VoiceSessionController = KbVoiceSessionController;
