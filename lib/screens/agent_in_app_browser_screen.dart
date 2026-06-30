import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import '../utils/agent_external_link.dart';
import '../utils/safe_uri.dart';
import '../widgets/phone_components.dart';

/// 应用内打开引用链接，不跳转系统浏览器。
class AgentInAppBrowserScreen extends StatefulWidget {
  const AgentInAppBrowserScreen({
    super.key,
    required this.url,
    this.title,
    this.headers,
  });

  final String url;
  final String? title;
  final Map<String, String>? headers;

  @override
  State<AgentInAppBrowserScreen> createState() => _AgentInAppBrowserScreenState();
}

class _AgentInAppBrowserScreenState extends State<AgentInAppBrowserScreen> {
  late final WebViewController _controller;
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    if (!kIsWeb) {
      _controller
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              if (mounted) setState(() => _loading = false);
            },
            onWebResourceError: (e) {
              if (mounted) {
                setState(() {
                  _loading = false;
                  _error = e.description;
                });
              }
            },
          ),
        );
    }
    _load();
  }

  Future<void> _load() async {
    final uri = tryParseUri(widget.url);
    if (uri == null) {
      if (mounted) setState(() { _loading = false; _error = '无效链接'; });
      return;
    }
    try {
      await _controller.loadRequest(uri, headers: widget.headers ?? const {});
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = '$e'; });
      return;
    }
    if (kIsWeb && mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.title?.trim().isNotEmpty == true
        ? widget.title!
        : agentSourceHostLabel(widget.url);
    return Scaffold(
      backgroundColor: MirrorColors.bgApp,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(8, 6, 12, 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: MirrorColors.borderSoft)),
              ),
              child: Row(
                children: [
                  MirrorBackButton(onTap: () => Navigator.of(context).pop()),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label.isEmpty ? '网页' : label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MirrorTheme.sans(fontSize: 14, weight: FontWeight.w600),
                        ),
                        Text(
                          agentSourceHostLabel(widget.url),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MirrorTheme.mono(fontSize: 10, color: MirrorColors.text3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  if (_error != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_error!, style: MirrorTheme.sans(fontSize: 14, color: MirrorColors.text3)),
                      ),
                    )
                  else
                    WebViewWidget(controller: _controller),
                  if (_loading)
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
          ],
        ),
      ),
    );
  }
}
