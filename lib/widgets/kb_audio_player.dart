import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../config/api_config.dart';
import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import '../widgets/mirror_pressable.dart';

/// 知识库文档详情中的音频播放器。
class KbAudioPlayer extends StatefulWidget {
  const KbAudioPlayer({
    super.key,
    this.url,
    this.bytes,
    this.mimeType = 'audio/mp4',
    this.filename = 'audio.m4a',
  });

  final String? url;
  final Uint8List? bytes;
  final String mimeType;
  final String filename;

  @override
  State<KbAudioPlayer> createState() => _KbAudioPlayerState();
}

class _KbAudioPlayerState extends State<KbAudioPlayer> {
  final _player = AudioPlayer();
  var _ready = false;
  var _playing = false;
  var _position = Duration.zero;
  var _duration = Duration.zero;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
    _player.playerStateStream.listen((s) {
      if (!mounted) return;
      setState(() => _playing = s.playing);
    });
    _player.positionStream.listen((p) {
      if (!mounted) return;
      setState(() => _position = p);
    });
    _player.durationStream.listen((d) {
      if (!mounted || d == null) return;
      setState(() => _duration = d);
    });
  }

  Future<void> _init() async {
    try {
      final source = await _buildSource();
      await _player.setAudioSource(source);
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _error = '音频加载失败');
    }
  }

  Future<AudioSource> _buildSource() async {
    if (widget.bytes != null && widget.bytes!.isNotEmpty) {
      if (kIsWeb) {
        return AudioSource.uri(Uri.dataFromBytes(widget.bytes!, mimeType: widget.mimeType));
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/kb_audio_${DateTime.now().millisecondsSinceEpoch}_${widget.filename}';
      final file = File(path);
      await file.writeAsBytes(widget.bytes!, flush: true);
      return AudioSource.file(path);
    }
    final url = widget.url?.trim() ?? '';
    if (url.isEmpty) throw StateError('empty url');
    final headers = <String, String>{};
    if (ApiConfig.accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${ApiConfig.accessToken}';
    }
    return AudioSource.uri(Uri.parse(url), headers: headers.isEmpty ? null : headers);
  }

  Future<void> _togglePlay() async {
    if (!_ready) return;
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> _seek(double value) async {
    if (_duration.inMilliseconds <= 0) return;
    final target = Duration(milliseconds: (value * _duration.inMilliseconds).round());
    await _player.seek(target);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Text(_error!, style: MirrorTheme.sans(fontSize: 13, color: MirrorColors.text3));
    }
    final max = _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 1.0;
    final value = _position.inMilliseconds.clamp(0, _duration.inMilliseconds).toDouble();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MirrorColors.bgSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MirrorColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              MirrorPressable(
                onTap: _ready ? _togglePlay : null,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: MirrorColors.accentSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: MirrorColors.accentDeep,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: SliderComponentShape.noOverlay,
                        activeTrackColor: MirrorColors.accent,
                        inactiveTrackColor: MirrorColors.borderSoft,
                        thumbColor: MirrorColors.accentDeep,
                      ),
                      child: Slider(
                        value: _ready ? value / max : 0,
                        onChanged: _ready ? _seek : null,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_label(_position), style: MirrorTheme.mono(fontSize: 10, color: MirrorColors.text3)),
                        Text(_label(_duration), style: MirrorTheme.mono(fontSize: 10, color: MirrorColors.text3)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!_ready)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('加载音频…', style: MirrorTheme.sans(fontSize: 12, color: MirrorColors.text3)),
            ),
        ],
      ),
    );
  }

  static String _label(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
