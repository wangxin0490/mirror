import 'package:flutter/material.dart';

import '../api/feed_api.dart';
import '../api/me_api.dart';
import '../config/api_config.dart';
import '../data/mirror_authors.dart';
import '../models/me_models.dart';
import '../services/image_picker_service.dart';
import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import '../widgets/mirror_pressable.dart';
import '../utils/media_url.dart';
import '../widgets/phone_components.dart';

/// 「我的」编辑资料：昵称、简介、上传头像。
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.initial,
    this.onBack,
    this.onSaved,
  });

  final MeProfile initial;
  final VoidCallback? onBack;
  final ValueChanged<MeProfile>? onSaved;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bioCtrl;
  MeProfile? _profile;
  String _avatarUrl = '';
  String _avatarObjectKey = '';
  String _avatarLetter = '?';
  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;
  String? _error;

  MeProfile get _base => _profile ?? widget.initial;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _bioCtrl = TextEditingController();
    _applyProfile(widget.initial);
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  void _applyProfile(MeProfile p) {
    _profile = p;
    _nameCtrl.text = p.displayName;
    _bioCtrl.text = p.bio;
    _avatarUrl = p.avatarUrl;
    _avatarObjectKey = '';
    _avatarLetter = p.avatarLetter.isNotEmpty ? p.avatarLetter : _letterFromName(p.displayName);
  }

  static String _letterFromName(String name) {
    final t = name.trim();
    if (t.isEmpty) return '?';
    return t[0].toUpperCase();
  }

  Future<void> _loadProfile() async {
    if (!ApiConfig.isLoggedIn) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final p = await MeApi.fetchProfile();
    if (!mounted) return;
    if (p != null) {
      _applyProfile(p);
    }
    setState(() => _loading = false);
  }

  Future<void> _pickAvatar() async {
    if (_uploading || _loading) return;
    final picked = await pickImages(allowMultiple: false, maxCount: 1);
    if (picked.isEmpty || !mounted) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    final img = picked.first;
    final uploaded = await FeedApi.uploadImage(img.bytes, img.name);
    if (!mounted) return;
    if (uploaded == null || uploaded.objectKey.isEmpty) {
      setState(() {
        _uploading = false;
        _error = '头像上传失败';
      });
      return;
    }
    setState(() {
      _avatarUrl = uploaded.url;
      _avatarObjectKey = uploaded.objectKey;
      _uploading = false;
    });
  }

  Future<void> _save() async {
    if (_saving || _loading) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '请填写昵称');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final base = _base;
    final draft = MeProfile(
      displayName: name,
      handle: base.handle,
      homeUrl: base.homeUrl,
      avatarLetter: _letterFromName(name),
      avatarUrl: _avatarObjectKey.isNotEmpty ? _avatarObjectKey : _avatarUrl,
      bio: _bioCtrl.text.trim(),
      following: base.following,
      followers: base.followers,
      notes: base.notes,
    );
    final saved = await MeApi.updateProfile(draft);
    if (!mounted) return;
    if (saved == null) {
      setState(() {
        _saving = false;
        _error = '保存失败，请稍后重试';
      });
      return;
    }
    await ApiConfig.saveSession(
      token: ApiConfig.accessToken,
      userId: ApiConfig.userId,
      displayName: saved.displayName,
      handle: saved.handle,
      avatarLetter: saved.avatarLetter.isNotEmpty ? saved.avatarLetter : _letterFromName(saved.displayName),
    );
    widget.onSaved?.call(saved);
    widget.onBack?.call();
  }

  @override
  Widget build(BuildContext context) {
    final me = MirrorAuthor.currentUser();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
          child: SizedBox(
            height: 40,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                MirrorBackButton(onTap: widget.onBack),
                const Spacer(),
                MirrorPressable(
                  onTap: (_saving || _loading) ? null : _save,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  borderRadius: BorderRadius.circular(8),
                  child: Text(
                    _saving ? '保存中…' : '保存',
                    style: MirrorTheme.sans(
                      fontSize: 14,
                      height: 1,
                      weight: FontWeight.w600,
                      color: MirrorColors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('编辑资料', style: MirrorTheme.sans(fontSize: 22, weight: FontWeight.w500, letterSpacing: -0.02)),
                      const SizedBox(height: 24),
                      Center(
                        child: MirrorPressable(
                          onTap: _uploading ? null : _pickAvatar,
                          borderRadius: BorderRadius.circular(40),
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              _ProfileAvatar(
                                avatarUrl: _avatarUrl,
                                letter: _avatarLetter,
                                colors: me.avatarColors,
                                size: 80,
                              ),
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: MirrorColors.text,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: MirrorColors.bgApp, width: 2),
                                ),
                                child: _uploading
                                    ? const Padding(
                                        padding: EdgeInsets.all(6),
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.camera_alt_outlined, size: 14, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          '点击更换头像',
                          style: MirrorTheme.sans(fontSize: 12, color: MirrorColors.text3),
                        ),
                      ),
                      const SizedBox(height: 28),
                      _fieldLabel('昵称'),
                      const SizedBox(height: 8),
                      _textField(_nameCtrl, hint: '展示昵称'),
                      const SizedBox(height: 18),
                      _fieldLabel('简介'),
                      const SizedBox(height: 8),
                      _textField(_bioCtrl, hint: '一句话介绍自己（可选）', maxLines: 4),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Text(_error!, style: MirrorTheme.sans(fontSize: 12, color: MirrorColors.coral)),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _fieldLabel(String t) => Text(t, style: MirrorTheme.mono(fontSize: 10, color: MirrorColors.text3, letterSpacing: 0.06));

  Widget _textField(TextEditingController c, {required String hint, int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: MirrorColors.bgSoft,
        border: Border.all(color: MirrorColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        style: MirrorTheme.sans(fontSize: 15, height: maxLines > 1 ? 1.55 : 1.2),
        cursorColor: MirrorColors.accent,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: MirrorTheme.sans(fontSize: 14, color: MirrorColors.text3),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: maxLines > 1 ? 12 : 13),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.avatarUrl,
    required this.letter,
    required this.colors,
    required this.size,
  });

  final String avatarUrl;
  final String letter;
  final List<Color> colors;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (avatarUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          resolveMediaUrl(avatarUrl),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => AvatarGradient(label: letter, colors: colors, size: size, radius: size / 2),
        ),
      );
    }
    return AvatarGradient(label: letter, colors: colors, size: size, radius: size / 2);
  }
}
