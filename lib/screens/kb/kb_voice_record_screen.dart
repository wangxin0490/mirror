import 'package:flutter/material.dart';

import '../../services/voice_record_config.dart';
import '../../state/kb_store.dart';
import '../voice_record_screen.dart';

export '../voice_record_screen.dart' show VoiceUploadFn;

typedef KbVoiceUploadFn = VoiceUploadFn;

/// 知识库语音导入薄封装（行为与泛化前一致）。
class KbVoiceRecordScreen extends StatelessWidget {
  const KbVoiceRecordScreen({super.key, required this.onUpload, required this.config});

  final KbVoiceUploadFn onUpload;
  final VoiceRecordConfig config;

  @override
  Widget build(BuildContext context) {
    return VoiceRecordScreen(config: config, onUpload: onUpload);
  }
}

Future<bool> openKbVoiceRecordScreen(
  BuildContext context, {
  required KbVoiceUploadFn onUpload,
}) async {
  final limits = await KbStore.instance.ensureUploadLimits();
  final config = VoiceRecordConfig.kb(maxDuration: Duration(seconds: limits.maxVoiceSeconds));
  if (!context.mounted) return false;
  return openVoiceRecordScreen(context, config: config, onUpload: onUpload);
}

Future<bool> openMeetingVoiceRecordScreen(BuildContext context) {
  return openVoiceRecordScreen(context, config: VoiceRecordConfig.meeting);
}
