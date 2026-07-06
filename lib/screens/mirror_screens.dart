import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import '../api/agent_api.dart';
import '../models/agent_models.dart';
import '../models/chat_launch_intent.dart';
import '../services/agent_sse_client.dart';
import '../services/asr_client.dart';
import '../services/voice_input_controller.dart';
import '../services/chat_stream_handle.dart';
import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import '../utils/agent_model.dart';
import '../utils/relay_error_messages.dart';
import '../utils/agent_chat_copy.dart';
import '../widgets/mirror_assistant_identity.dart';
import '../layout/adaptive_layout.dart';
import '../widgets/mirror_icon.dart';
import '../widgets/mirror_pressable.dart';
import '../widgets/mirror_scroll.dart';
import '../widgets/phone_components.dart';
import '../widgets/agent_rich_message.dart';
import '../widgets/agent_model_settings_sheet.dart';
import '../widgets/agent_chat_composer.dart';
import '../api/chat_api.dart';
import '../api/chat_inbox_ws.dart';
import '../api/contacts_api.dart';
import '../config/api_config.dart';
import '../data/mirror_authors.dart';
import '../models/chat_models.dart';
import '../models/chat_attachment.dart';
import '../models/pending_chat_attachment.dart';
import '../utils/chat_pending_upload.dart';
import '../utils/dm_file_message.dart';
import '../utils/dm_share_message.dart';
import '../widgets/dm_feed_post_share_card.dart';
import '../widgets/dm_user_share_card.dart';
import '../widgets/chat_attachment_preview_sheet.dart';
import '../widgets/chat_message_attachments.dart';
import '../services/file_picker_service.dart';
import '../services/image_picker_service.dart';
import '../services/media_picker_service.dart';
import '../state/dm_thread_store.dart';
import '../utils/media_url.dart';
import '../widgets/mirror_user_avatar.dart';
import '../screens/kb/kb_swipe_actions.dart';
import '../screens/kb/kb_ui_helpers.dart';
import '../widgets/ai_data_consent_dialog.dart';
import '../widgets/login_legal_consent_footer.dart';
import '../widgets/moderation_action_sheet.dart';

const _kModelNotVisionHint = '无法发送图片，请换一个标注「支持图片」的模型';

// ─── S1 Welcome ───────────────────────────────────────────────
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, this.authHint, this.onPhoneLogin});

  final String? authHint;
  final VoidCallback? onPhoneLogin;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.5, 0.3),
                      radius: 0.65,
                      colors: [
                        MirrorColors.accent.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              border: Border.all(color: MirrorColors.border),
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              color: MirrorColors.text,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            alignment: Alignment.center,
                            child: const MirrorIcon(size: 48),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'MirrorX',
                        style: MirrorTheme.sans(
                          fontSize: 36,
                          weight: FontWeight.w500,
                          letterSpacing: -0.025,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Mirror',
                        style: MirrorTheme.mono(
                          fontSize: 11,
                          color: MirrorColors.text3,
                          letterSpacing: 0.06,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '照见知识、映射能力',
                        textAlign: TextAlign.center,
                        style: MirrorTheme.sans(
                          fontSize: 13,
                          color: MirrorColors.text2,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 44),
          child: Column(
            children: [
              if (authHint != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: MirrorColors.coralSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    authHint!,
                    textAlign: TextAlign.center,
                    style: MirrorTheme.sans(
                      fontSize: 12,
                      color: MirrorColors.coral,
                    ),
                  ),
                ),
              ],
              _primaryBtn(Icons.smartphone_outlined, '手机号登录', onPhoneLogin),
              const LoginLegalConsentFooter(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _primaryBtn(IconData icon, String label, VoidCallback? onTap) =>
      MirrorPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: MirrorColors.text,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: MirrorTheme.sans(
                  fontSize: 14,
                  weight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
}

// ─── S2 Chat ────────────────────────────────────────────────────
enum _AgentChatStatus { listening, searching, thinking, responding }

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    this.onBack,
    this.previewMode = false,
    this.launchIntent,
    this.onLaunchIntentConsumed,
  });

  final VoidCallback? onBack;
  final bool previewMode;
  final ChatLaunchIntent? launchIntent;
  final VoidCallback? onLaunchIntentConsumed;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _previewModels = [
    AgentModelItem(
      modelCode: 'claude-4-opus',
      displayName: 'claude-4',
      accessMode: 'purchased',
      accessLabel: '已购',
      selectable: true,
    ),
    AgentModelItem(
      modelCode: 'gpt-4o',
      displayName: 'gpt-4o',
      accessMode: 'trial',
      accessLabel: '试用',
      selectable: true,
    ),
    AgentModelItem(
      modelCode: 'gemini-2.5',
      displayName: 'gemini-2.5',
      accessMode: 'locked',
      accessLabel: '需购买',
      selectable: false,
      lockReason: 'not_purchased',
    ),
  ];

  static final _previewConversations = [
    AgentConversationSummary(
      conversationId: 1,
      modelCode: 'claude-4-opus',
      title: '武汉天气',
      lastMessageAt: DateTime.now().subtract(const Duration(hours: 2)),
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    AgentConversationSummary(
      conversationId: 2,
      modelCode: 'gpt-4o',
      title: '周报提纲',
      lastMessageAt: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
      createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
    ),
    AgentConversationSummary(
      conversationId: 3,
      modelCode: 'claude-4-opus',
      title: '产品方案讨论',
      lastMessageAt: DateTime.now().subtract(const Duration(days: 5)),
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
  ];

  final _input = TextEditingController();
  final _scroll = ScrollController();

  bool _loading = false;
  bool _sending = false;
  ChatStreamHandle? _activeStream;
  bool _historyOpen = false;
  bool _loadingHistory = false;
  bool _webSearchEnabled = true;
  bool _uploading = false;
  bool _settlingHistoryScroll = false;
  final _pendingSlots = ComposerAttachmentSlots();
  List<AgentModelItem> _models = [];
  List<AgentConversationSummary> _conversations = [];
  AgentConversation? _conversation;
  List<AgentMessage> _messages = [];
  _AgentChatStatus _status = _AgentChatStatus.listening;
  int _previewNextConvId = 4;
  int _scrollSettleGeneration = 0;
  final _voiceInput = VoiceInputController();
  var _asrAvailable = false;
  String? _composerHint;
  String? _emptyWelcomeMessage;

  bool get _showVoiceMic => !widget.previewMode && _asrAvailable;

  @override
  void initState() {
    super.initState();
    final intent = widget.launchIntent;
    if (intent != null) {
      _composerHint = intent.composerPlaceholder;
      _emptyWelcomeMessage = intent.welcomeMessage;
    }
    _input.addListener(_onInputChanged);
    _voiceInput.addListener(_onVoiceInputChanged);
    _voiceInput.onAutoEnd = _onVoiceAutoEnd;
    if (widget.previewMode) {
      _models = List.of(_previewModels);
      _conversations = List.of(_previewConversations);
      _conversation = const AgentConversation(
        conversationId: 1,
        modelCode: 'claude-4-opus',
        title: '武汉天气',
      );
    } else {
      _bootstrap();
    }
  }

  void _onInputChanged() {
    if (mounted) setState(() {});
  }

  void _onVoiceInputChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _activeStream?.cancel();
    _voiceInput.removeListener(_onVoiceInputChanged);
    _voiceInput.dispose();
    _input.removeListener(_onInputChanged);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _stopGeneration() {
    if (!_sending && _activeStream == null) return;
    _activeStream?.cancel();
    if (!mounted) return;
    setState(() {
      _status = _AgentChatStatus.listening;
      _sending = false;
      for (var i = 0; i < _messages.length; i++) {
        final m = _messages[i];
        if (m.streaming || m.searching) {
          _messages[i] = m.copyWith(streaming: false, searching: false);
        }
      }
    });
  }

  AgentModelItem? _modelByCode(String code) {
    for (final m in _models) {
      if (m.modelCode == code) return m;
    }
    return null;
  }

  /// 与当前会话 model_code 精确匹配的目录项（不做 fallback，避免误用其它模型的 selectable）。
  AgentModelItem? get _conversationModel {
    final code = _conversation?.modelCode;
    if (code == null || code.isEmpty) return null;
    return _modelByCode(code);
  }

  bool get _isHermesModel =>
      isHermesAgentModel(_conversation?.modelCode) ||
      isHermesAgentItem(_conversationModel);

  /// Hermes 不走联网检索；联网按钮置灰且请求恒为 false。
  bool get _agentWebSearchEnabled => _webSearchEnabled && !_isHermesModel;

  AgentModelItem? get _selectedModel {
    final convModel = _conversationModel;
    if (convModel != null) return convModel;
    final code = _conversation?.modelCode;
    if (code != null && code.isNotEmpty) return null;
    return _models.isNotEmpty ? _models.first : null;
  }

  bool get _modelAllowsSend {
    final convModel = _conversationModel;
    if (convModel != null) return convModel.selectable;
    return true;
  }

  static String? _pickDefaultModelCode(List<AgentModelItem> models) {
    for (final m in models) {
      if (m.selectable) return m.modelCode;
    }
    return models.isNotEmpty ? models.first.modelCode : null;
  }

  String? _resolveLaunchModelCode(
    List<AgentModelItem> models,
    ChatLaunchIntent intent,
  ) {
    final preferred = intent.defaultModelCode?.trim();
    if (preferred != null && preferred.isNotEmpty) {
      for (final m in models) {
        if (m.modelCode == preferred && m.selectable) {
          return preferred;
        }
      }
    }
    for (final m in models) {
      if (!m.selectable) continue;
      if (m.modelCode.startsWith('deepseek')) return m.modelCode;
    }
    return _pickDefaultModelCode(models);
  }

  String get _modelPillLabel {
    final m = _conversationModel;
    if (m != null) return m.displayName;
    final code = _conversation?.modelCode;
    if (code != null && code.isNotEmpty) return code;
    return _models.isNotEmpty ? _models.first.displayName : '…';
  }

  String get _headerTitle {
    final t = _conversation?.title?.trim();
    if (t != null && t.isNotEmpty) return t;
    return 'Mirror';
  }

  bool get _headerIsAgentName => (_conversation?.title?.trim().isEmpty ?? true);

  Color get _statusColor => switch (_status) {
    _AgentChatStatus.listening => MirrorColors.green,
    _AgentChatStatus.searching => MirrorColors.accent,
    _AgentChatStatus.thinking => MirrorColors.accent,
    _AgentChatStatus.responding => MirrorColors.accent,
  };

  String get _statusLabel => switch (_status) {
    _AgentChatStatus.listening => 'listening',
    _AgentChatStatus.searching => '正在搜索',
    _AgentChatStatus.thinking => 'thinking',
    _AgentChatStatus.responding => 'responding',
  };

  bool get _hasComposerContent =>
      _input.text.trim().isNotEmpty || _pendingSlots.hasPending;

  /// 会话与模型已就绪，且未在拉取消息（草稿会话 conversationId=0 亦可用）。
  bool get _sessionReady {
    final conv = _conversation;
    return !_loading && conv != null && _modelAllowsSend;
  }

  /// 仅上传附件时锁定输入；生成中仍允许编辑下一条（发送由 [_canSend] / [canStop] 控制）。
  bool get _composerBusy => _uploading;

  AgentConversation _draftConversation(String? modelCode) =>
      AgentConversation(
        conversationId: 0,
        modelCode: modelCode?.trim().isNotEmpty == true
            ? modelCode!.trim()
            : (_pickDefaultModelCode(_models) ?? ''),
      );

  /// 丢弃当前未发消息的空会话，避免历史里堆积「新对话」。
  Future<void> _discardEmptyPersistedConversation() async {
    final conv = _conversation;
    if (widget.previewMode || conv == null || conv.conversationId <= 0) {
      return;
    }
    if (_messages.isNotEmpty) return;
    await AgentApi.deleteConversation(conv.conversationId);
  }

  bool get _composerEnabled => !widget.previewMode && !_composerBusy;

  bool get _canSend => _composerEnabled && _sessionReady && _hasComposerContent;

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      final models = await AgentApi.listModels();
      final intent = widget.launchIntent;
      AgentConversation? conv;
      if (!widget.previewMode &&
          intent != null &&
          intent.forceNewSession) {
        final modelCode = _resolveLaunchModelCode(models, intent);
        conv = _draftConversation(modelCode);
        widget.onLaunchIntentConsumed?.call();
      } else {
        conv = await AgentApi.getConversation();
        if (conv == null || conv.conversationId <= 0) {
          conv = _draftConversation(_pickDefaultModelCode(models));
        }
      }
      final asrFuture = AsrClient.fetchStatus(refresh: true);
      List<AgentMessage> msgs = [];
      if (conv != null && conv.conversationId > 0) {
        final list = await AgentApi.listMessages(conv.conversationId);
        msgs = list?.items ?? [];
      }
      if (!mounted) return;
      final asr = await asrFuture;
      setState(() {
        _models = models;
        _conversation = conv;
        _messages = msgs;
        _settlingHistoryScroll = msgs.isNotEmpty;
        _loading = false;
        _asrAvailable = asr.enabled;
        _voiceInput.maxDuration = Duration(seconds: asr.maxSegmentSeconds);
      });
      await _loadConversations(silent: true);
      await _jumpToEndAfterLayout();
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        _toast('加载失败，请重试');
      }
    }
  }

  void _animateToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _jumpToEndAfterLayout() async {
    final generation = ++_scrollSettleGeneration;
    for (var i = 0; i < 3; i++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || generation != _scrollSettleGeneration) return;
      if (!_scroll.hasClients) continue;
      final max = _scroll.position.maxScrollExtent;
      _scroll.jumpTo(max);
    }
    if (!mounted || generation != _scrollSettleGeneration) return;
    if (_settlingHistoryScroll) {
      setState(() => _settlingHistoryScroll = false);
    }
  }

  void _toast(String message) {
    if (!mounted || message.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _copyFeedback() => _toast('已复制');

  Future<void> _copyMessage(AgentMessage message) async {
    final ok = await copyTextToClipboard(formatAgentMessageForCopy(message));
    if (!mounted) return;
    if (ok) {
      _copyFeedback();
    } else {
      _toast('暂无可复制内容');
    }
  }

  Future<void> _showMessageActions(AgentMessage message) async {
    if (message.streaming || message.content.trim().isEmpty) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: MirrorColors.bgApp,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.content_copy_outlined, size: 20),
              title: Text('复制', style: MirrorTheme.sans(fontSize: 15)),
              onTap: () => Navigator.pop(ctx, 'copy'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action != 'copy') return;
    await _copyMessage(message);
  }

  Future<void> _exportConversationMarkdown({
    AgentConversationSummary? item,
  }) async {
    List<AgentMessage> msgs = _messages;
    String? title = _conversation?.title;

    if (item != null) {
      title = item.title ?? item.displayTitle;
      if (item.conversationId != _conversation?.conversationId) {
        if (widget.previewMode) {
          _toast('预览模式暂不支持导出其他会话');
          return;
        }
        final list = await AgentApi.listMessages(item.conversationId);
        if (!mounted) return;
        msgs = list?.items ?? [];
      }
    }

    final markdown = formatAgentConversationMarkdown(
      title: title,
      messages: msgs,
    );
    final ok = await copyTextToClipboard(markdown);
    if (!mounted) return;
    if (ok) {
      _toast('对话已复制为 Markdown');
    } else {
      _toast('暂无可导出内容');
    }
  }

  Future<bool> _onEnterVoiceMode() async {
    final granted = await _voiceInput.ensureMicPermission();
    if (!granted && mounted) {
      _toast('需要麦克风权限才能使用语音输入');
    }
    return granted;
  }

  Future<void> _onVoiceHoldStart() async {
    if (_composerBusy) return;
    if (!_asrAvailable) {
      _toast('语音识别服务未开启');
      return;
    }
    try {
      await _voiceInput.holdStart();
    } catch (_) {
      _toast('需要麦克风权限才能使用语音输入');
    }
  }

  Future<void> _onVoiceHoldEnd() async {
    if (!_voiceInput.recording) return;
    final text = await _voiceInput.holdEnd();
    await _deliverVoiceText(text);
  }

  Future<void> _onVoiceAutoEnd(String? text) async {
    if (!mounted) return;
    _toast('单次语音最长 ${AsrClient.cachedStatus.maxSegmentSeconds} 秒');
    await _deliverVoiceText(text);
  }

  Future<void> _deliverVoiceText(String? text) async {
    if (!mounted) return;
    if (text == null || text.isEmpty) {
      if (_voiceInput.transcribing) return;
      _toast(AsrClient.lastError ?? '未识别到语音内容');
      return;
    }
    await _send(voiceText: text);
  }

  Future<void> _onVoiceHoldCancel() async {
    await _voiceInput.holdCancel();
  }

  void _showAgentAttachSheet() {
    if (widget.previewMode) {
      _toast('预览模式不支持上传');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MirrorColors.bgApp,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.camera_alt_outlined,
                size: 20,
                color: MirrorColors.text2,
              ),
              title: Text('拍照', style: MirrorTheme.sans(fontSize: 15)),
              onTap: () {
                Navigator.pop(ctx);
                _agentPickCamera();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.image_outlined,
                size: 20,
                color: MirrorColors.text2,
              ),
              title: Text('图片', style: MirrorTheme.sans(fontSize: 15)),
              onTap: () {
                Navigator.pop(ctx);
                _agentPickGallery();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.insert_drive_file_outlined,
                size: 20,
                color: MirrorColors.text2,
              ),
              title: Text('文件', style: MirrorTheme.sans(fontSize: 15)),
              onTap: () {
                Navigator.pop(ctx);
                _agentPickFiles();
              },
            ),
            if (_messages.isNotEmpty)
              ListTile(
                leading: const Icon(
                  Icons.download_outlined,
                  size: 20,
                  color: MirrorColors.text2,
                ),
                title: Text(
                  '导出对话为 Markdown',
                  style: MirrorTheme.sans(fontSize: 15),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportConversationMarkdown();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _agentPickCamera() async {
    final picked = await pickFromCamera();
    if (picked.isEmpty || !mounted) return;
    _stageAgentPick(picked.first, isImage: true);
  }

  Future<void> _agentPickGallery() async {
    // maxCount: 1 — 与后端 chat_attachment 每消息 1 图限制一致
    final picked = await pickFromGallery(allowMultiple: false, maxCount: 1);
    if (picked.isEmpty || !mounted) return;
    _stageAgentPick(picked.first, isImage: true);
  }

  bool _selectedModelSupportsVision() {
    final code = _conversation?.modelCode;
    if (code == null || code.isEmpty) return false;
    for (final m in _models) {
      if (m.modelCode == code) return m.supportsVision;
    }
    return false;
  }

  Future<void> _agentPickFiles() async {
    final picked = await pickFiles(maxCount: 1);
    if (picked.isEmpty || !mounted) return;
    final file = picked.first;
    _stageAgentPick(file, isImage: pendingFileIsImage(file.name));
  }

  void _stageAgentPick(PickedImageBytes file, {required bool isImage}) {
    if (_uploading || _sending) return;
    if (isImage && !_selectedModelSupportsVision()) {
      _toast(_kModelNotVisionHint);
      return;
    }
    final sizeErr = validatePendingAttachmentSize(
      file.bytes.length,
      isImage: isImage,
    );
    if (sizeErr != null) {
      _toast(sizeErr);
      return;
    }
    setState(() {
      if (isImage) {
        if (_pendingSlots.image != null) _toast('已替换上一张图片');
        _pendingSlots.image = PendingChatAttachment.fromPicked(
          file,
          isImage: true,
        );
      } else {
        if (_pendingSlots.document != null) _toast('已替换上一个文件');
        _pendingSlots.document = PendingChatAttachment.fromPicked(
          file,
          isImage: false,
        );
      }
    });
  }

  Future<void> _openModelPickerSheet() async {
    if (_models.isEmpty) return;
    await showAgentModelPickerSheet(
      context: context,
      models: _models,
      selectedModelCode: _conversation?.modelCode,
      onModelSelected: _selectModel,
    );
  }

  Future<void> _selectModel(AgentModelItem picked) async {
    if (widget.previewMode) {
      setState(
        () => _conversation = AgentConversation(
          conversationId: 0,
          modelCode: picked.modelCode,
        ),
      );
      return;
    }
    final conv = _conversation;
    if (conv == null) return;
    if (picked.modelCode == conv.modelCode) return;
    if (!picked.selectable) {
      _toast(_quotaMessage(picked.lockReason));
      return;
    }
    if (conv.conversationId <= 0) {
      setState(
        () => _conversation = AgentConversation(
          conversationId: 0,
          modelCode: picked.modelCode,
        ),
      );
      return;
    }
    final r = await AgentApi.patchModel(conv.conversationId, picked.modelCode);
    if (!mounted) return;
    if (!r.ok) {
      _toast(
        r.message.isNotEmpty ? r.message : _quotaMessage(picked.lockReason),
      );
      return;
    }
    setState(() {
      _conversation =
          r.data ??
          AgentConversation(
            conversationId: conv.conversationId,
            modelCode: picked.modelCode,
            title: conv.title,
          );
      if (isHermesAgentModel(picked.modelCode) || isHermesAgentItem(picked)) {
        _webSearchEnabled = false;
      }
    });
    if (_historyOpen) await _loadConversations(silent: true);
  }

  Future<void> _loadConversations({bool silent = false}) async {
    if (widget.previewMode) return;
    if (!silent) setState(() => _loadingHistory = true);
    try {
      final list = await AgentApi.listConversations();
      if (!mounted) return;
      setState(() => _conversations = list?.items ?? []);
    } finally {
      if (mounted && !silent) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _openHistory() async {
    if (_sending) {
      _toast('请等待回复完成');
      return;
    }
    setState(() => _historyOpen = true);
    await _loadConversations();
  }

  void _closeHistory() => setState(() => _historyOpen = false);

  String _historyDateLabel(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final day = DateTime(local.year, local.month, local.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    if (diff < 7) return '${diff}天前';
    return '${local.year}年${local.month.toString().padLeft(2, '0')}月${local.day.toString().padLeft(2, '0')}日';
  }

  List<({String label, List<AgentConversationSummary> items})>
  get _groupedConversations {
    final sorted = List<AgentConversationSummary>.from(_conversations)
      ..sort((a, b) => b.sortTime.compareTo(a.sortTime));
    final order = <String>[];
    final groups = <String, List<AgentConversationSummary>>{};
    for (final c in sorted) {
      final label = _historyDateLabel(c.sortTime);
      groups.putIfAbsent(label, () => []).add(c);
      if (!order.contains(label)) order.add(label);
    }
    return [for (final label in order) (label: label, items: groups[label]!)];
  }

  Future<void> _switchToConversation(AgentConversationSummary item) async {
    if (_sending) {
      _toast('请等待回复完成');
      return;
    }
    if (_conversation?.conversationId == item.conversationId) {
      _closeHistory();
      return;
    }
    if (widget.previewMode) {
      setState(() {
        _conversation = AgentConversation(
          conversationId: item.conversationId,
          modelCode: item.modelCode,
          title: item.title,
        );
        _messages = item.conversationId == 1
            ? const [
                AgentMessage(id: 1, role: 'user', content: '武汉今天天气怎么样？'),
                AgentMessage(
                  id: 2,
                  role: 'assistant',
                  content: '武汉今日多云，气温 18–26℃。',
                ),
              ]
            : [];
      });
      _closeHistory();
      await _jumpToEndAfterLayout();
      return;
    }
    setState(() => _loading = true);
    try {
      final list = await AgentApi.listMessages(item.conversationId);
      if (!mounted) return;
      setState(() {
        _conversation = AgentConversation(
          conversationId: item.conversationId,
          modelCode: item.modelCode,
          title: item.title,
        );
        _messages = list?.items ?? [];
        _settlingHistoryScroll = (list?.items.isNotEmpty ?? false);
        _loading = false;
        if (_isHermesModel) _webSearchEnabled = false;
      });
      _closeHistory();
      await _jumpToEndAfterLayout();
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        _toast('加载会话失败');
      }
    }
  }

  Future<void> _createNewConversation() async {
    if (_sending) {
      _toast('请等待回复完成');
      return;
    }
    final modelCode =
        _conversation?.modelCode ?? _selectedModel?.modelCode ?? '';
    if (widget.previewMode) {
      final id = _previewNextConvId++;
      final conv = AgentConversation(
        conversationId: id,
        modelCode: modelCode.isNotEmpty ? modelCode : 'claude-4-opus',
      );
      setState(() {
        _conversation = conv;
        _messages = [];
        _conversations = [
          AgentConversationSummary(
            conversationId: id,
            modelCode: conv.modelCode,
            createdAt: DateTime.now(),
          ),
          ..._conversations,
        ];
      });
      _closeHistory();
      return;
    }
    await _discardEmptyPersistedConversation();
    setState(() {
      _conversation = _draftConversation(
        modelCode.isNotEmpty ? modelCode : _pickDefaultModelCode(_models),
      );
      _messages = [];
    });
    _closeHistory();
  }

  Future<void> _showConversationActions(AgentConversationSummary item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: MirrorColors.bgApp,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined, size: 20),
              title: Text('重命名', style: MirrorTheme.sans(fontSize: 15)),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined, size: 20),
              title: Text('导出 Markdown', style: MirrorTheme.sans(fontSize: 15)),
              onTap: () => Navigator.pop(ctx, 'export'),
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                size: 20,
                color: MirrorColors.coral,
              ),
              title: Text(
                '删除',
                style: MirrorTheme.sans(
                  fontSize: 15,
                  color: MirrorColors.coral,
                ),
              ),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'rename') {
      await _renameConversation(item);
    } else if (action == 'export') {
      await _exportConversationMarkdown(item: item);
    } else if (action == 'delete') {
      await _deleteConversation(item);
    }
  }

  Future<void> _renameConversation(AgentConversationSummary item) async {
    final ctrl = TextEditingController(
      text: item.displayTitle == '新对话' ? '' : item.displayTitle,
    );
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '重命名会话',
          style: MirrorTheme.sans(fontSize: 16, weight: FontWeight.w600),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 128,
          decoration: const InputDecoration(hintText: '输入会话标题'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (!mounted || title == null || title.isEmpty) return;
    if (widget.previewMode) {
      setState(() {
        _conversations = _conversations
            .map(
              (c) => c.conversationId == item.conversationId
                  ? AgentConversationSummary(
                      conversationId: c.conversationId,
                      modelCode: c.modelCode,
                      title: title,
                      lastMessageAt: c.lastMessageAt,
                      createdAt: c.createdAt,
                    )
                  : c,
            )
            .toList();
        if (_conversation?.conversationId == item.conversationId) {
          _conversation = AgentConversation(
            conversationId: item.conversationId,
            modelCode: item.modelCode,
            title: title,
          );
        }
      });
      return;
    }
    final r = await AgentApi.patchTitle(item.conversationId, title);
    if (!mounted) return;
    if (!r.ok) {
      _toast(r.message.isNotEmpty ? r.message : '重命名失败');
      return;
    }
    await _loadConversations(silent: true);
    if (_conversation?.conversationId == item.conversationId &&
        r.data != null) {
      setState(() => _conversation = r.data);
    }
  }

  Future<void> _deleteConversation(AgentConversationSummary item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '删除会话',
          style: MirrorTheme.sans(fontSize: 16, weight: FontWeight.w600),
        ),
        content: Text(
          '删除后无法恢复，确定删除「${item.displayTitle}」？',
          style: MirrorTheme.sans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              '删除',
              style: MirrorTheme.sans(color: MirrorColors.coral),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (widget.previewMode) {
      final remaining = _conversations
          .where((c) => c.conversationId != item.conversationId)
          .toList();
      setState(() {
        _conversations = remaining;
        if (_conversation?.conversationId == item.conversationId) {
          if (remaining.isNotEmpty) {
            final next = remaining.first;
            _conversation = AgentConversation(
              conversationId: next.conversationId,
              modelCode: next.modelCode,
              title: next.title,
            );
            _messages = [];
          } else {
            final id = _previewNextConvId++;
            _conversation = AgentConversation(
              conversationId: id,
              modelCode: 'claude-4-opus',
            );
            _messages = [];
            _conversations = [
              AgentConversationSummary(
                conversationId: id,
                modelCode: 'claude-4-opus',
                createdAt: DateTime.now(),
              ),
            ];
          }
        }
      });
      return;
    }
    final deleted = await AgentApi.deleteConversation(item.conversationId);
    if (!mounted) return;
    if (!deleted) {
      _toast('删除失败');
      return;
    }
    await _loadConversations(silent: true);
    if (_conversation?.conversationId != item.conversationId) return;
    if (_conversations.isNotEmpty) {
      await _switchToConversation(_conversations.first);
      return;
    }
    setState(() {
      _conversation = _draftConversation(_pickDefaultModelCode(_models));
      _messages = [];
    });
  }

  String _quotaMessage(String? lockReason) => switch (lockReason) {
    'trial_exhausted' => '体验额度已用完，购买 Token 后可继续对话',
    'balance_exhausted' => '该模型 Token 已用完，请充值',
    'not_purchased' => '请购买该模型 Token 包',
    _ => '当前模型不可用',
  };

  Future<void> _send({String? voiceText}) async {
    if (widget.previewMode || _sending || _uploading) return;
    final text = voiceText?.trim() ?? _input.text.trim();
    if (text.isEmpty && !_pendingSlots.hasPending) return;

    List<ChatAttachment> attachments = const [];
    if (_pendingSlots.hasPending) {
      setState(() => _uploading = true);
      List<ChatAttachment>? uploaded;
      try {
        uploaded = await uploadComposerSlots(_pendingSlots);
      } finally {
        if (mounted) setState(() => _uploading = false);
      }
      if (!mounted) return;
      if (uploaded == null) {
        _toast('上传失败，请重试');
        return;
      }
      attachments = uploaded;
      _pendingSlots.clear();
    }

    if (voiceText == null) _input.clear();
    await _sendContent(text, attachments: attachments);
  }

  Future<void> _sendContent(
    String text, {
    List<ChatAttachment> attachments = const [],
  }) async {
    if (widget.previewMode || _sending || _uploading) return;
    text = text.trim();
    if (text.isEmpty && attachments.isEmpty) return;

    final consented = await ensureAiDataConsent(context);
    if (!consented || !mounted) return;

    if (attachments.any((a) => a.type == 'image') &&
        !_selectedModelSupportsVision()) {
      _toast(_kModelNotVisionHint);
      return;
    }
    var conv = _conversation;
    if (conv == null || conv.conversationId == 0) {
      final created = await AgentApi.createConversation(
        modelCode:
            _conversationModel?.modelCode ?? _pickDefaultModelCode(_models),
      );
      if (!mounted) return;
      if (created == null || created.conversationId <= 0) {
        _toast('会话未就绪');
        return;
      }
      setState(() => _conversation = created);
      conv = created;
    }
    if (!_modelAllowsSend) {
      _toast(_quotaMessage(_conversationModel?.lockReason));
      return;
    }

    setState(() {
      _sending = true;
      _status = _AgentChatStatus.thinking;
      _messages = [
        ..._messages,
        AgentMessage(
          id: -1,
          role: 'user',
          content: text,
          attachments: attachments,
        ),
        const AgentMessage(
          id: -2,
          role: 'assistant',
          content: '',
          streaming: true,
        ),
      ];
    });
    _animateToEnd();

    var assistantIdx = _messages.length - 1;
    late final ChatStreamHandle stream;
    stream = AgentSseClient.sendMessage(
      conversationId: conv.conversationId,
      content: text,
      attachments: attachments,
      webSearch: _agentWebSearchEnabled,
      onTool: (tool) {
        if (!mounted || stream.cancelled) return;
        if (tool.name == 'web.search') {
          if (_isHermesModel) return;
          setState(() {
            final cur = _messages[assistantIdx];
            if (tool.phase == 'start') {
              _status = _AgentChatStatus.searching;
              _messages[assistantIdx] = cur.copyWith(searching: true);
            } else if (tool.phase == 'done' && tool.sources.isNotEmpty) {
              _messages[assistantIdx] = cur.copyWith(
                searching: false,
                sources: tool.sources,
              );
            } else if (tool.phase == 'error') {
              _messages[assistantIdx] = cur.copyWith(searching: false);
            }
          });
          return;
        }
        if (tool.phase == 'start') {
          setState(() => _status = _AgentChatStatus.thinking);
        }
      },
      onDelta: (delta) {
        if (!mounted || stream.cancelled) return;
        setState(() {
          _status = _AgentChatStatus.responding;
          final cur = _messages[assistantIdx];
          _messages[assistantIdx] = cur.copyWith(content: cur.content + delta);
        });
        _animateToEnd();
      },
      onDone: (done) {
        if (!mounted || stream.cancelled) return;
        setState(() {
          _status = _AgentChatStatus.listening;
          _sending = false;
          final cur = _messages[assistantIdx];
          final content =
              done.content.isNotEmpty ? done.content : cur.content;
          _messages[assistantIdx] = cur.copyWith(
            content: content,
            streaming: false,
            searching: false,
            id: done.messageId,
            sources: _isHermesModel
                ? const []
                : (done.sources.isNotEmpty ? done.sources : cur.sources),
          );
          if (RelayErrorMessages.isUserFacingError(content)) {
            _toast(content);
          }
        });
        unawaited(_loadConversations(silent: true));
      },
      onError: (code, message) {
        if (!mounted || stream.cancelled) return;
        if (code == 'use_kb_import') {
          _toast('请先在知识库中导入 PDF/Word 文档后再提问');
          setState(() {
            _status = _AgentChatStatus.listening;
            _sending = false;
            _messages = _messages.where((m) => m.id >= 0).toList();
          });
          return;
        }
        if (code == 'model_not_vision') {
          _toast(_kModelNotVisionHint);
          setState(() {
            _status = _AgentChatStatus.listening;
            _sending = false;
            _messages = _messages.where((m) => m.id >= 0).toList();
          });
          return;
        }
        final text = RelayErrorMessages.userMessage(
          code: code,
          upstream: message,
        );
        setState(() {
          _status = _AgentChatStatus.listening;
          _sending = false;
          final cur = _messages[assistantIdx];
          _messages[assistantIdx] = cur.copyWith(
            content: text,
            streaming: false,
          );
        });
        _toast(text);
      },
    );
    _activeStream = stream;
    try {
      await stream.done;
    } catch (e) {
      if (!mounted) return;
      if (stream.cancelled) return;
      setState(() {
        _status = _AgentChatStatus.listening;
        _sending = false;
        _messages = _messages.where((m) => m.id != -2).toList();
      });
      _toast('发送失败');
    } finally {
      if (mounted) {
        setState(() {
          _status = _AgentChatStatus.listening;
          _sending = false;
          if (assistantIdx < _messages.length) {
            final cur = _messages[assistantIdx];
            if (cur.streaming || cur.searching) {
              _messages[assistantIdx] = cur.copyWith(
                streaming: false,
                searching: false,
              );
            }
          }
        });
      }
      _activeStream = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final drawerW = MediaQuery.sizeOf(context).width * 0.75;
    return Stack(
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(8, 6, 12, 12),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: MirrorColors.borderSoft),
                ),
              ),
              child: Row(
                children: [
                  if (widget.onBack != null)
                    MirrorBackButton(onTap: widget.onBack),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _headerIsAgentName
                            ? const MirrorAssistantHeaderTitle()
                            : Text(
                                _headerTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: MirrorTheme.sans(
                                  fontSize: 14,
                                  weight: FontWeight.w500,
                                  letterSpacing: -0.01,
                                ),
                              ),
                        if (_headerIsAgentName && _messages.isEmpty)
                          Text(
                            '新会话',
                            style: MirrorTheme.sans(
                              fontSize: 12,
                              color: MirrorColors.text3,
                            ),
                          )
                        else
                          Row(
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: _statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _statusLabel,
                                style: MirrorTheme.mono(
                                  fontSize: 10,
                                  color: _statusColor,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  MirrorPressable(
                    onTap: _sending ? null : _createNewConversation,
                    borderRadius: BorderRadius.circular(8),
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.note_add_outlined,
                      size: 20,
                      color: _sending ? MirrorColors.text3 : MirrorColors.text2,
                    ),
                  ),
                  MirrorPressable(
                    onTap: _openHistory,
                    borderRadius: BorderRadius.circular(8),
                    padding: const EdgeInsets.all(8),
                    child: const Icon(
                      Icons.menu_rounded,
                      size: 20,
                      color: MirrorColors.text2,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Stack(
                      children: [
                        IgnorePointer(
                          ignoring: _settlingHistoryScroll,
                          child: Opacity(
                            opacity: _settlingHistoryScroll ? 0 : 1,
                            child: ListView.builder(
                              controller: _scroll,
                              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                              itemCount: _messages.isEmpty
                                  ? 2
                                  : _messages.length + 1,
                              itemBuilder: (context, i) {
                                if (i == 0) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _buildAiDisclaimerBanner(),
                                  );
                                }
                                if (_messages.isEmpty) {
                                  return SizedBox(
                                    height:
                                        MediaQuery.sizeOf(context).height *
                                        0.42,
                                    child: _buildChatEmptyState(),
                                  );
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _messageBubble(_messages[i - 1]),
                                );
                              },
                            ),
                          ),
                        ),
                        if (_settlingHistoryScroll)
                          const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                      ],
                    ),
            ),
            AgentChatComposer(
              controller: _input,
              enabled: _composerEnabled,
              canSend: _canSend,
              canStop: _sending,
              onStop: _stopGeneration,
              modelLabel: _modelPillLabel,
              webSearchEnabled: _webSearchEnabled,
              webSearchLocked: _isHermesModel,
              previewMode: widget.previewMode,
              composerHint: _composerHint,
              pendingSlots: widget.previewMode ? null : _pendingSlots,
              onRemovePendingImage: widget.previewMode
                  ? null
                  : () => setState(() => _pendingSlots.image = null),
              onRemovePendingDocument: widget.previewMode
                  ? null
                  : () => setState(() => _pendingSlots.document = null),
              onOpenModelPicker: _models.isEmpty ? null : _openModelPickerSheet,
              onSend: _send,
              onWebSearchToggle: widget.previewMode || _isHermesModel
                  ? null
                  : () =>
                        setState(() => _webSearchEnabled = !_webSearchEnabled),
              onMore: _showAgentAttachSheet,
              showVoiceMic: _showVoiceMic,
              voiceRecording: _voiceInput.recording,
              voiceTranscribing: _voiceInput.transcribing,
              voiceAmplitude: _voiceInput.amplitude,
              onEnterVoiceMode: _showVoiceMic ? _onEnterVoiceMode : null,
              onVoiceHoldStart: _showVoiceMic ? _onVoiceHoldStart : null,
              onVoiceHoldEnd: _showVoiceMic ? _onVoiceHoldEnd : null,
              onVoiceHoldCancel: _showVoiceMic ? _onVoiceHoldCancel : null,
            ),
          ],
        ),
        if (_historyOpen) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeHistory,
              child: Container(color: Colors.black.withValues(alpha: 0.35)),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: drawerW,
            child: Material(
              color: MirrorColors.bgApp,
              elevation: 8,
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                      child: Row(
                        children: [
                          Text(
                            '会话历史',
                            style: MirrorTheme.sans(
                              fontSize: 16,
                              weight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: _closeHistory,
                            icon: const Icon(Icons.close_rounded, size: 20),
                            color: MirrorColors.text3,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: MirrorColors.borderSoft),
                    Expanded(
                      child: _loadingHistory
                          ? const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : _conversations.isEmpty
                          ? Center(
                              child: Text(
                                '暂无历史会话',
                                style: MirrorTheme.sans(
                                  fontSize: 13,
                                  color: MirrorColors.text3,
                                ),
                              ),
                            )
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
                              children: [
                                for (final group in _groupedConversations) ...[
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      12,
                                      16,
                                      6,
                                    ),
                                    child: Text(
                                      group.label,
                                      style: MirrorTheme.sans(
                                        fontSize: 12,
                                        color: MirrorColors.text3,
                                        weight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  for (final item in group.items)
                                    _historyTile(item),
                                  const SizedBox(height: 4),
                                ],
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAiDisclaimerBanner() {
    return Text(
      '内容由AI生成仅供参考',
      textAlign: TextAlign.center,
      style: MirrorTheme.sans(
        fontSize: 11,
        color: MirrorColors.text4,
        height: 1.4,
      ),
    );
  }

  Widget _buildChatEmptyState() {
    final welcome = _emptyWelcomeMessage?.trim();
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '新会话',
              style: MirrorTheme.sans(
                fontSize: 22,
                weight: FontWeight.w600,
                color: MirrorColors.text,
                letterSpacing: -0.02,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              welcome != null && welcome.isNotEmpty
                  ? welcome
                  : '从这里开始和 Mirror 对话',
              textAlign: TextAlign.center,
              style: MirrorTheme.sans(
                fontSize: 14,
                color: MirrorColors.text3,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyTile(AgentConversationSummary item) {
    final active = _conversation?.conversationId == item.conversationId;
    return ListTile(
      dense: true,
      selected: active,
      selectedTileColor: MirrorColors.accentSoft.withValues(alpha: 0.35),
      leading: Icon(
        Icons.chat_bubble_outline_rounded,
        size: 18,
        color: active ? MirrorColors.accent : MirrorColors.text3,
      ),
      title: Text(
        item.displayTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: MirrorTheme.sans(
          fontSize: 14,
          weight: active ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.more_horiz, size: 18, color: MirrorColors.text3),
        onPressed: () => _showConversationActions(item),
      ),
      onTap: () => _switchToConversation(item),
      onLongPress: () => _showConversationActions(item),
    );
  }

  Widget _messageBubble(AgentMessage m) {
    if (m.isAssistant) {
      return GestureDetector(
        onLongPress: () => _showMessageActions(m),
        child: AgentAssistantMessage(
          message: m,
          onLinkFailure: _toast,
          onCopyFeedback: _copyFeedback,
          onDgCouponQueryStock: (code) => _sendContent('$code 还有多少库存？'),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onLongPress: () => _showMessageActions(m),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: MirrorColors.text,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: _userMessageBody(m),
        ),
      ),
    );
  }

  Widget _userMessageBody(AgentMessage m) {
    final text = m.content.trim();
    final hasText = text.isNotEmpty;
    final hasAtt = m.attachments.isNotEmpty;
    if (!hasText && !hasAtt) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasAtt) ...[
          ChatMessageAttachments(
            attachments: m.attachments,
            onDarkBackground: true,
          ),
          if (hasText) const SizedBox(height: 8),
        ],
        if (hasText)
          SelectableText(
            text,
            style: MirrorTheme.sans(
              fontSize: 13,
              height: 1.55,
              color: Colors.white,
            ),
          ),
      ],
    );
  }
}

// ─── S3 Sessions ───────────────────────────────────────────────
enum _MsgCategory { contact }

class _ThreadData {
  const _ThreadData({
    required this.key,
    this.conversationId = 0,
    required this.av,
    required this.colors,
    this.avatarUrl = '',
    required this.name,
    required this.time,
    required this.preview,
    required this.category,
    this.unread = false,
    this.at = false,
    this.radius,
  });

  final String key;
  final int conversationId;
  final String av;
  final List<Color> colors;
  final String avatarUrl;
  final String name;
  final String time;
  final String preview;
  final _MsgCategory category;
  final bool unread;
  final bool at;
  final double? radius;
}

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key, this.onThreadTap, this.onContactsTap});

  /// 传入会话 key（与 [MirrorAuthor.key] / [DmThread.key] 一致）
  final ValueChanged<String>? onThreadTap;
  final VoidCallback? onContactsTap;

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  static const _filters = ['全部', '未读', '联系人'];
  int _filterIndex = 0;
  bool _searchOpen = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  static String _tabParam(int filterIndex) => switch (filterIndex) {
    1 => 'unread',
    2 => 'contacts',
    _ => 'all',
  };

  @override
  void initState() {
    super.initState();
    DmThreadStore.instance.addListener(_onDmChanged);
    _load();
  }

  void _onDmChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    if (!ApiConfig.isLoggedIn) {
      DmThreadStore.instance.clear();
      return;
    }
    await DmThreadStore.instance.refreshFromApi(tab: _tabParam(_filterIndex));
  }

  List<_ThreadData> get _visibleThreads {
    final q = _searchQuery.trim().toLowerCase();
    final threads = DmThreadStore.instance.threads.map((t) {
      return _ThreadData(
        key: t.key,
        conversationId: t.conversationId,
        av: t.av,
        colors: t.colors,
        avatarUrl: t.avatarUrl,
        name: t.name,
        time: t.time,
        preview: normalizeConversationPreview(t.preview),
        category: _MsgCategory.contact,
        unread: t.unread,
        at: t.atMe,
      );
    }).toList();
    if (q.isEmpty) return threads;
    return threads
        .where(
          (t) =>
              t.name.toLowerCase().contains(q) ||
              t.preview.toLowerCase().contains(q) ||
              t.key.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  void dispose() {
    DmThreadStore.instance.removeListener(_onDmChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  String _emptyHint() {
    if (!ApiConfig.isLoggedIn) return '登录后查看消息';
    if (DmThreadStore.instance.loadFailed) {
      return '加载失败，请确认后端已启动\n（go run ./cmd/server）';
    }
    if (_searchQuery.trim().isNotEmpty) return '未找到相关对话';
    return '该分类暂无消息';
  }

  void _toggleSearch({bool? open}) {
    final next = open ?? !_searchOpen;
    if (next) {
      setState(() => _searchOpen = true);
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && _searchOpen) _searchFocus.requestFocus();
      });
    } else {
      _searchFocus.unfocus();
      setState(() {
        _searchOpen = false;
        _searchQuery = '';
        _searchController.clear();
      });
      _load();
    }
  }

  void _onFilterTap(int i) {
    if (_filterIndex == i) return;
    setState(() => _filterIndex = i);
    _load();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: MirrorTheme.sans(fontSize: 13)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmDeleteThread(_ThreadData t) async {
    if (t.conversationId <= 0) {
      _toast('该会话暂无法删除');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '删除对话',
          style: MirrorTheme.sans(fontSize: 16, weight: FontWeight.w600),
        ),
        content: Text(
          '确定删除与「${t.name}」的聊天记录？删除后无法恢复。',
          style: MirrorTheme.sans(
            fontSize: 14,
            color: MirrorColors.text2,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              '删除',
              style: MirrorTheme.sans(
                color: MirrorColors.coral,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final result = await DmThreadStore.instance.deleteConversation(
      t.conversationId,
    );
    if (!mounted) return;
    _toast(result.ok ? '已删除' : result.message);
  }

  @override
  Widget build(BuildContext context) {
    final store = DmThreadStore.instance;
    final threads = _visibleThreads;
    final loading = store.loading && threads.isEmpty;
    return Column(
      children: [
        MirrorAppBar(
          title: '',
          accentPart: '消息',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MirrorPressable(
                onTap: widget.onContactsTap,
                padding: const EdgeInsets.all(4),
                borderRadius: BorderRadius.circular(8),
                child: const Icon(
                  Icons.people_outline,
                  size: 22,
                  color: MirrorColors.text2,
                ),
              ),
              const SizedBox(width: 4),
              MirrorPressable(
                onTap: () => _toggleSearch(open: !_searchOpen),
                padding: const EdgeInsets.all(4),
                borderRadius: BorderRadius.circular(8),
                child: Icon(
                  _searchOpen ? Icons.close : Icons.search,
                  size: 22,
                  color: _searchOpen ? MirrorColors.text : MirrorColors.text2,
                ),
              ),
            ],
          ),
        ),
        if (_searchOpen) _searchBar(),
        Expanded(
          child: RefreshIndicator(
            color: MirrorColors.accent,
            onRefresh: _load,
            child: MirrorListView(
              padding: EdgeInsets.zero,
              children: [
                _msgFilterChips(),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (threads.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 40,
                      horizontal: 24,
                    ),
                    child: Center(
                      child: Text(
                        _emptyHint(),
                        textAlign: TextAlign.center,
                        style: MirrorTheme.sans(
                          fontSize: 13,
                          color: MirrorColors.text3,
                          height: 1.5,
                        ),
                      ),
                    ),
                  )
                else
                  for (var i = 0; i < threads.length; i++)
                    _thread(threads[i], showDivider: i < threads.length - 1),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _searchBar() => Container(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: MirrorColors.borderSoft)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: MirrorColors.bgSoft,
              border: Border.all(color: MirrorColors.border),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, size: 16, color: MirrorColors.text3),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: MirrorTheme.sans(
                      fontSize: 14,
                      color: MirrorColors.text,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      isCollapsed: true,
                      hintText: '搜索联系人或消息内容',
                      hintStyle: MirrorTheme.sans(
                        fontSize: 13,
                        color: MirrorColors.text3,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  MirrorPressable(
                    onTap: () => setState(() {
                      _searchQuery = '';
                      _searchController.clear();
                    }),
                    padding: const EdgeInsets.all(2),
                    child: const Icon(
                      Icons.cancel,
                      size: 16,
                      color: MirrorColors.text3,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        MirrorPressable(
          onTap: () => _toggleSearch(open: false),
          child: Text(
            '取消',
            style: MirrorTheme.sans(
              fontSize: 14,
              color: MirrorColors.text2,
              weight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _msgFilterChips() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
    child: SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final on = _filterIndex == i;
          return MirrorPressable(
            onTap: () => _onFilterTap(i),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: on ? MirrorColors.text : MirrorColors.bgSoft,
                border: Border.all(
                  color: on ? MirrorColors.text : MirrorColors.border,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _filters[i],
                style: MirrorTheme.sans(
                  fontSize: 12,
                  weight: FontWeight.w500,
                  color: on ? Colors.white : MirrorColors.text2,
                ),
              ),
            ),
          );
        },
      ),
    ),
  );

  Widget _thread(_ThreadData t, {required bool showDivider}) {
    final row = MirrorPressable(
      onTap: widget.onThreadTap == null
          ? null
          : () => widget.onThreadTap!(t.key),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          MirrorUserAvatar(
            size: 44,
            letter: t.av,
            avatarUrl: t.avatarUrl,
            gradient: MirrorGradients.avatar(t.colors),
            fontSize: 44 * 0.36,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              t.name,
                              style: MirrorTheme.sans(
                                fontSize: 14,
                                weight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      t.time,
                      style: MirrorTheme.mono(fontSize: 10, letterSpacing: 0),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    style: MirrorTheme.sans(
                      fontSize: 12,
                      color: MirrorColors.text3,
                    ),
                    children: [
                      if (t.at)
                        TextSpan(
                          text: '@你 ',
                          style: MirrorTheme.sans(
                            fontSize: 12,
                            color: MirrorColors.accent,
                            weight: FontWeight.w500,
                          ),
                        ),
                      TextSpan(text: t.preview),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (t.unread)
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(left: 4),
              decoration: const BoxDecoration(
                color: MirrorColors.accent,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );

    final canDelete = ApiConfig.isLoggedIn && t.conversationId > 0;
    final tile = canDelete
        ? Slidable(
            key: ValueKey('dm-thread-${t.conversationId}'),
            endActionPane: ActionPane(
              motion: const DrawerMotion(),
              extentRatio: 0.14,
              children: [
                CustomSlidableAction(
                  onPressed: (_) => _confirmDeleteThread(t),
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.transparent,
                  padding: const EdgeInsets.only(left: 2, right: 8),
                  flex: 1,
                  child: KbCircularSwipeAction(
                    icon: TablerIcons.trash,
                    backgroundColor: MirrorColors.coralSoft,
                    iconColor: MirrorColors.coral,
                    onTap: () => _confirmDeleteThread(t),
                  ),
                ),
              ],
            ),
            child: row,
          )
        : row;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        tile,
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 74, right: 16),
            child: Container(height: 1, color: MirrorColors.borderSoft),
          ),
      ],
    );
  }
}

// ─── S4 Human Chat ─────────────────────────────────────────────
class HumanChatScreen extends StatefulWidget {
  const HumanChatScreen({
    super.key,
    this.author,
    this.onBack,
    this.onPostTap,
    this.onUserTap,
  });

  final MirrorAuthor? author;
  final VoidCallback? onBack;
  final void Function(int postId)? onPostTap;
  final void Function(DmUserShare share)? onUserTap;

  @override
  State<HumanChatScreen> createState() => _HumanChatScreenState();
}

class _HumanChatScreenState extends State<HumanChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];

  int _conversationId = 0;
  int _peerUserId = 0;
  bool _loading = true;
  bool _loadFailed = false;
  bool _sending = false;
  bool _uploading = false;
  bool _settlingHistoryScroll = false;
  int _scrollSettleGeneration = 0;
  late final void Function(ChatMessage) _wsMessageListener;

  MirrorAuthor get _peer => widget.author ?? MirrorAuthor.byKey('linan')!;

  @override
  void initState() {
    super.initState();
    _wsMessageListener = _onWsMessage;
    ChatInboxWs.instance.addMessageListener(_wsMessageListener);
    DmThreadStore.instance.markRead(_peer.key);
    _bootstrap();
  }

  @override
  void dispose() {
    ChatInboxWs.instance.removeMessageListener(_wsMessageListener);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onWsMessage(ChatMessage msg) {
    if (_conversationId <= 0 && msg.conversationId > 0) {
      _conversationId = msg.conversationId;
      ChatInboxWs.instance.subscribe(_conversationId);
    }
    if (msg.conversationId != _conversationId) return;
    if (_messages.any((m) => m.id == msg.id)) return;
    if (!mounted) return;
    setState(() => _messages.add(msg));
    _jumpToLatestIfNearBottom();
    if (!msg.isMe) {
      ChatApi.markConversationRead(_conversationId);
      DmThreadStore.instance.markRead(_peer.key);
    }
    DmThreadStore.instance.bumpThread(
      _peer.key,
      preview: dmMessagePreview(msg),
      unread: false,
      conversationId: msg.conversationId,
    );
  }

  void _subscribeConversation() {
    if (_conversationId > 0) {
      ChatInboxWs.instance.subscribe(_conversationId);
    }
  }

  Future<void> _bootstrap() async {
    final thread = DmThreadStore.instance.byKey(_peer.key);
    _conversationId = thread?.conversationId ?? 0;
    _peerUserId = thread?.userId ?? 0;
    if (_peerUserId <= 0) {
      _peerUserId = _peer.userId;
    }

    if (_peerUserId <= 0 && _peer.handle.isNotEmpty) {
      final card = await ContactsApi.lookup(_peer.handle);
      _peerUserId = card?.userId ?? 0;
    }

    if (!ApiConfig.isLoggedIn) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
      return;
    }

    if (_conversationId > 0) {
      _subscribeConversation();
      await ChatApi.markConversationRead(_conversationId);
      await _loadHistory();
    } else if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadHistory() async {
    if (_conversationId <= 0) return;
    final firstLoad = _messages.isEmpty;
    if (firstLoad) {
      setState(() {
        _loading = true;
        _loadFailed = false;
      });
    }
    final res = await ChatApi.fetchMessages(_conversationId, limit: 50);
    if (!mounted) return;
    if (res == null) {
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
      return;
    }
    setState(() {
      _messages
        ..clear()
        ..addAll(res.items);
      _loading = false;
      _loadFailed = false;
      _settlingHistoryScroll = res.items.isNotEmpty;
    });
    if (res.items.isNotEmpty) {
      await _settleScrollToLatest();
    }
  }

  /// reverse ListView：offset 0 为最新消息一侧（底部）。
  bool _isNearLatest() {
    if (!_scroll.hasClients) return true;
    return _scroll.position.pixels <= 80;
  }

  void _jumpToLatestIfNearBottom() {
    if (!_isNearLatest()) return;
    _jumpToLatest();
  }

  void _jumpToLatest() {
    if (!_scroll.hasClients) return;
    _scroll.jumpTo(0);
  }

  /// 布局完成前隐藏列表，无动画滚到底后再显示（避免闪动）。
  Future<void> _settleScrollToLatest() async {
    final generation = ++_scrollSettleGeneration;
    for (var i = 0; i < 4; i++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || generation != _scrollSettleGeneration) return;
      if (_scroll.hasClients) {
        _scroll.jumpTo(0);
      }
    }
    if (!mounted || generation != _scrollSettleGeneration) return;
    if (_settlingHistoryScroll) {
      setState(() => _settlingHistoryScroll = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _sendText() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    if (!ApiConfig.isLoggedIn) {
      _toast('请先登录');
      return;
    }
    if (_peerUserId <= 0 && _conversationId <= 0) {
      _toast('无法识别对方用户');
      return;
    }

    setState(() => _sending = true);
    final r = await ChatApi.sendMessage(
      conversationId: _conversationId > 0 ? _conversationId : null,
      peerUserId: _conversationId > 0 ? null : _peerUserId,
      type: 'text',
      body: text,
    );
    if (!mounted) return;
    setState(() => _sending = false);

    if (!r.ok || r.data == null) {
      _toast(r.message.isNotEmpty ? r.message : '发送失败');
      return;
    }

    _input.clear();
    _applySentMessage(r.data!, preview: text);
  }

  void _applySentMessage(ChatMessage msg, {required String preview}) {
    if (_conversationId <= 0 && msg.conversationId > 0) {
      _conversationId = msg.conversationId;
      _subscribeConversation();
      ChatApi.markConversationRead(_conversationId);
    }
    setState(() => _messages.add(msg));
    DmThreadStore.instance.bumpThread(
      _peer.key,
      preview: preview,
      unread: false,
      conversationId: _conversationId,
    );
    _jumpToLatest();
  }

  Future<void> _sendImageMessage(PickedImageBytes file) async {
    if (_uploading || _sending) return;
    if (!ApiConfig.isLoggedIn) {
      _toast('请先登录');
      return;
    }
    if (_peerUserId <= 0 && _conversationId <= 0) {
      _toast('无法识别对方用户');
      return;
    }

    setState(() => _uploading = true);
    final url = await ChatApi.uploadAttachment(file.bytes, file.name);
    if (!mounted) return;
    if (url == null) {
      setState(() => _uploading = false);
      _toast('图片上传失败');
      return;
    }

    setState(() {
      _uploading = false;
      _sending = true;
    });
    final r = await ChatApi.sendMessage(
      conversationId: _conversationId > 0 ? _conversationId : null,
      peerUserId: _conversationId > 0 ? null : _peerUserId,
      type: 'image',
      mediaUrl: url,
    );
    if (!mounted) return;
    setState(() => _sending = false);

    if (!r.ok || r.data == null) {
      _toast(r.message.isNotEmpty ? r.message : '发送失败');
      return;
    }
    _applySentMessage(r.data!, preview: '[图片]');
  }

  Future<void> _sendFileMessage(PickedImageBytes file) async {
    if (_uploading || _sending) return;
    if (!ApiConfig.isLoggedIn) {
      _toast('请先登录');
      return;
    }
    if (_peerUserId <= 0 && _conversationId <= 0) {
      _toast('无法识别对方用户');
      return;
    }

    setState(() => _uploading = true);
    final upload = await ChatApi.uploadAttachmentResult(file.bytes, file.name);
    if (!mounted) return;
    if (upload == null) {
      setState(() => _uploading = false);
      _toast('文件上传失败');
      return;
    }

    setState(() {
      _uploading = false;
      _sending = true;
    });
    final r = await ChatApi.sendMessage(
      conversationId: _conversationId > 0 ? _conversationId : null,
      peerUserId: _conversationId > 0 ? null : _peerUserId,
      // 后端仅支持 text/image；非图片文件用 image 类型携带 media_url，body 存文件名
      type: 'image',
      body: file.name,
      mediaUrl: upload.url,
    );
    if (!mounted) return;
    setState(() => _sending = false);

    if (!r.ok || r.data == null) {
      _toast(r.message.isNotEmpty ? r.message : '发送失败');
      return;
    }
    _applySentMessage(r.data!, preview: file.name);
  }

  Future<void> _pickCamera() async {
    final picked = await pickFromCamera();
    if (picked.isEmpty) return;
    await _sendImageMessage(picked.first);
  }

  Future<void> _pickImages() async {
    final picked = await pickImages(allowMultiple: false, maxCount: 1);
    if (picked.isEmpty) return;
    await _sendImageMessage(picked.first);
  }

  Future<void> _pickFiles() async {
    final picked = await pickFiles(maxCount: 1);
    if (picked.isEmpty) return;
    final file = picked.first;
    final lower = file.name.toLowerCase();
    final isImage =
        lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp');
    if (isImage) {
      await _sendImageMessage(file);
    } else {
      await _sendFileMessage(file);
    }
  }

  Future<void> _showPeerModeration() async {
    final peer = _peer;
    final uid = _peerUserId > 0 ? _peerUserId : peer.userId;
    await showModerationActionSheet(
      context,
      title: '私信操作',
      userId: uid > 0 ? uid : null,
      userName: peer.name,
      targetType: 'user',
      targetId: '$uid',
      onBlocked: widget.onBack,
    );
  }

  void _showAttachSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MirrorColors.bgApp,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_outlined,
                  color: MirrorColors.text2,
                ),
                title: Text('拍照', style: MirrorTheme.sans(fontSize: 14)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickCamera();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.image_outlined,
                  color: MirrorColors.text2,
                ),
                title: Text('图片', style: MirrorTheme.sans(fontSize: 14)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImages();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.insert_drive_file_outlined,
                  color: MirrorColors.text2,
                ),
                title: Text('文件', style: MirrorTheme.sans(fontSize: 14)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFiles();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final peer = _peer;
    final busy = _sending || _uploading;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
          decoration: const BoxDecoration(
            color: MirrorColors.bgApp,
            border: Border(bottom: BorderSide(color: MirrorColors.borderSoft)),
          ),
          child: Row(
            children: [
              MirrorBackButton(onTap: widget.onBack),
              const SizedBox(width: 12),
              MirrorUserAvatar(
                size: 34,
                letter: peer.av,
                avatarUrl: peer.avatarUrl,
                gradient: MirrorGradients.avatar(peer.avatarColors),
                fontSize: 13,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      peer.name,
                      style: MirrorTheme.sans(
                        fontSize: 14,
                        weight: FontWeight.w500,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: MirrorColors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '在线',
                          style: MirrorTheme.mono(
                            fontSize: 10.5,
                            color: MirrorColors.green,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_peerUserId > 0 || _peer.userId > 0)
                IconButton(
                  icon: const Icon(Icons.more_horiz, size: 20, color: MirrorColors.text2),
                  onPressed: _showPeerModeration,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: MirrorColors.accent,
                  ),
                )
              : _loadFailed
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '消息加载失败',
                        style: MirrorTheme.sans(
                          fontSize: 13,
                          color: MirrorColors.text3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      MirrorPressable(
                        onTap: _conversationId > 0 ? _loadHistory : _bootstrap,
                        child: Text(
                          '重试',
                          style: MirrorTheme.sans(
                            fontSize: 13,
                            color: MirrorColors.accent,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    IgnorePointer(
                      ignoring: _settlingHistoryScroll,
                      child: Opacity(
                        opacity: _settlingHistoryScroll ? 0 : 1,
                        child: ListView.builder(
                          controller: _scroll,
                          reverse: true,
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
                          itemCount: _messages.isEmpty ? 1 : _messages.length + 2,
                          itemBuilder: (context, index) {
                            if (_messages.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 24),
                                  child: Text(
                                    '暂无消息，发一句打个招呼吧',
                                    style: MirrorTheme.sans(
                                      fontSize: 12,
                                      color: MirrorColors.text3,
                                    ),
                                  ),
                                ),
                              );
                            }
                            if (index == _messages.length + 1) {
                              return Center(
                                child: Text(
                                  '今天',
                                  style: MirrorTheme.mono(
                                    fontSize: 10,
                                    letterSpacing: 0.06,
                                  ),
                                ),
                              );
                            }
                            if (index == _messages.length) {
                              return const SizedBox(height: 8);
                            }
                            final m =
                                _messages[_messages.length - 1 - index];
                            return _messageBubble(m);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: MirrorColors.borderSoft)),
          ),
          child: Row(
            children: [
              MirrorPressable(
                onTap: busy ? null : _showAttachSheet,
                child: Icon(
                  busy ? Icons.hourglass_top : Icons.add,
                  size: 22,
                  color: MirrorColors.text3,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _input,
                  enabled: !busy,
                  onSubmitted: (_) => _sendText(),
                  style: MirrorTheme.sans(fontSize: 12.5),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: _uploading ? '上传中…' : '输入消息',
                    hintStyle: MirrorTheme.sans(
                      fontSize: 12.5,
                      color: MirrorColors.text3,
                    ),
                    filled: true,
                    fillColor: MirrorColors.bgSoft,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              MirrorPressable(
                onTap: busy ? null : _sendText,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: busy ? MirrorColors.text3 : MirrorColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_upward,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _messageBubble(ChatMessage m) {
    final userShare = userShareFromChat(m);
    if (userShare != null) {
      return DmUserShareCard(
        share: userShare,
        alignEnd: m.isMe,
        onTap: widget.onUserTap == null ? null : () => widget.onUserTap!(userShare),
      );
    }
    final share = feedPostShareFromChat(m);
    if (share != null) {
      return DmFeedPostShareCard(
        share: share,
        alignEnd: m.isMe,
        onTap: widget.onPostTap == null
            ? null
            : () => widget.onPostTap!(share.postId),
      );
    }
    final file = fileMessageFromChat(m);
    if (file != null) {
      return _fileBubble(file, m.isMe);
    }
    if (m.isImage && m.mediaUrl != null && m.mediaUrl!.isNotEmpty) {
      return _imageBubble(resolveMediaUrl(m.mediaUrl!), m.isMe);
    }
    return _textBubble(m.body.isNotEmpty ? m.body : '[消息]', m.isMe);
  }

  Widget _textBubble(String t, bool me) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 240),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: me ? MirrorColors.text : MirrorColors.bgSoft,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(me ? 16 : 4),
            topRight: const Radius.circular(16),
            bottomLeft: const Radius.circular(16),
            bottomRight: Radius.circular(me ? 4 : 16),
          ),
        ),
        child: Text(
          t,
          style: MirrorTheme.sans(
            fontSize: 13,
            height: 1.55,
            color: me ? Colors.white : MirrorColors.text,
          ),
        ),
      ),
    ),
  );

  Widget _imageBubble(String url, bool me) {
    final side = adaptiveSquareSize(context);
    return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: MirrorPressable(
        onTap: () => openChatImagePreview(context, url: url),
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: side, maxHeight: side),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return Container(
                  width: 120,
                  height: 120,
                  color: MirrorColors.bgSoft,
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: MirrorColors.accent,
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => Container(
                width: 120,
                height: 80,
                color: MirrorColors.bgSoft,
                alignment: Alignment.center,
                child: Text(
                  '图片加载失败',
                  style: MirrorTheme.sans(
                    fontSize: 11,
                    color: MirrorColors.text3,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  }

  Widget _fileBubble(DmFileMessage file, bool me) {
    final (icon, iconColor, _) = KbDocUi.fileTypeForFilename(file.filename);
    final fg = me ? Colors.white.withValues(alpha: 0.95) : MirrorColors.text;
    final bg = me ? Colors.white.withValues(alpha: 0.12) : MirrorColors.bgSoft;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: me ? Alignment.centerRight : Alignment.centerLeft,
        child: MirrorPressable(
          onTap: () => openUploadedFilePreview(
            context,
            url: file.url,
            title: file.filename,
          ),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 240),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: me ? MirrorColors.text : bg,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(me ? 16 : 4),
                topRight: const Radius.circular(16),
                bottomLeft: const Radius.circular(16),
                bottomRight: Radius.circular(me ? 4 : 16),
              ),
              border: me ? null : Border.all(color: MirrorColors.borderSoft),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: me ? iconColor.withValues(alpha: 0.95) : iconColor,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    file.filename,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: MirrorTheme.sans(
                      fontSize: 13,
                      height: 1.35,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _shareCard() => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          border: Border.all(color: MirrorColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              height: 88,
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(gradient: MirrorGradients.pink),
              alignment: Alignment.center,
              child: Text(
                '"清醒、有据、\n敢于反对。"',
                textAlign: TextAlign.center,
                style: MirrorTheme.serif(fontSize: 14),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '林岸的 Soul · 8 个月在用',
                    style: MirrorTheme.sans(
                      fontSize: 13,
                      weight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '¥12',
                        style: MirrorTheme.mono(
                          fontSize: 13,
                          color: MirrorColors.coral,
                          weight: MirrorFontWeight.semibold,
                          letterSpacing: 0,
                        ),
                      ),
                      Text(
                        '一键导入 →',
                        style: MirrorTheme.sans(
                          fontSize: 11.5,
                          color: MirrorColors.accent,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
