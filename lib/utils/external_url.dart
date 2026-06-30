import 'package:url_launcher/url_launcher.dart';

import 'media_url.dart';
import 'safe_uri.dart';

Future<bool> openExternalUrl(String url) async {
  final resolved = resolveMediaUrl(url.trim());
  if (resolved.isEmpty) return false;
  final uri = tryParseUri(resolved);
  if (uri == null) return false;
  if (!await canLaunchUrl(uri)) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
