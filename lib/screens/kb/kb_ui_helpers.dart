import 'package:flutter/material.dart';

import '../../models/kb_models.dart';
import '../../theme/mirror_colors.dart';

/// 文档行图标与副标题。
class KbDocUi {
  static (IconData icon, Color bg, Color fg) iconFor(KbDocumentItem doc) {
    final n = doc.originalFilename.toLowerCase();
    if (n.endsWith('.pdf')) return (Icons.picture_as_pdf_outlined, MirrorColors.amberSoft, MirrorColors.amber);
    if (n.endsWith('.png') || n.endsWith('.jpg') || n.endsWith('.jpeg') || n.endsWith('.webp')) {
      return (Icons.image_outlined, MirrorColors.pinkSoft, MirrorColors.pink);
    }
    if (n.endsWith('.mp3') || n.endsWith('.wav') || n.endsWith('.m4a')) {
      return (Icons.mic_none, MirrorColors.accentSoft, MirrorColors.accentDeep);
    }
    return (Icons.description_outlined, MirrorColors.blueSoft, MirrorColors.blue);
  }

  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// 列表副标题：网页导入无大小时显示「网页」，否则格式化字节数。
  static String sizeLabel(KbDocumentItem doc) {
    if (doc.fileSize > 0) return formatSize(doc.fileSize);
    if (doc.isWebImport) return '网页';
    return formatSize(doc.fileSize);
  }

  static String statusLabel(String status) {
    return switch (status) {
      'uploading' => '上传中',
      'uploaded' => '待解析',
      'queued' => '待导入',
      'parsing' => '解析中',
      'ready' => '可用',
      'failed' => '失败',
      _ => status,
    };
  }

  static bool isMarkdown(String filename) {
    final n = filename.toLowerCase();
    return n.endsWith('.md') || n.endsWith('.markdown');
  }

  static bool isRichTextPreview(String filename) {
    final n = filename.toLowerCase();
    return isMarkdown(filename) || n.endsWith('.html') || n.endsWith('.htm');
  }

  static bool isAudio(KbDocumentItem doc) {
    final n = doc.originalFilename.toLowerCase();
    if (n.endsWith('.m4a') ||
        n.endsWith('.mp3') ||
        n.endsWith('.wav') ||
        n.endsWith('.aac') ||
        n.endsWith('.webm') ||
        n.endsWith('.ogg')) {
      return true;
    }
    final mime = doc.mimeType.toLowerCase();
    return mime.startsWith('audio/');
  }

  static bool isImage(KbDocumentItem doc) {
    final n = doc.originalFilename.toLowerCase();
    if (n.endsWith('.png') ||
        n.endsWith('.jpg') ||
        n.endsWith('.jpeg') ||
        n.endsWith('.webp') ||
        n.endsWith('.gif') ||
        n.endsWith('.bmp')) {
      return true;
    }
    final mime = doc.mimeType.toLowerCase();
    return mime.startsWith('image/');
  }

  static bool isTextPreviewable(KbDocumentItem doc) {
    final n = doc.originalFilename.toLowerCase();
    if (n.endsWith('.md') ||
        n.endsWith('.markdown') ||
        n.endsWith('.txt') ||
        n.endsWith('.json') ||
        n.endsWith('.csv') ||
        n.endsWith('.xml') ||
        n.endsWith('.html') ||
        n.endsWith('.htm') ||
        n.endsWith('.yaml') ||
        n.endsWith('.yml') ||
        n.endsWith('.log')) {
      return true;
    }
    final mime = doc.mimeType.toLowerCase();
    return mime.startsWith('text/') || mime == 'application/json' || mime == 'application/xml';
  }

  static String relativeUpdated(String iso) {
    if (iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 30) return '${diff.inDays} 天前';
    if (diff.inDays < 365) return '${diff.inDays ~/ 30} 个月前';
    return '${diff.inDays ~/ 365} 年前';
  }

  static (IconData icon, Color color, String label) fileTypeForFilename(String filename) {
    final n = filename.toLowerCase();
    if (n.endsWith('.doc') || n.endsWith('.docx')) {
      return (Icons.description_outlined, MirrorColors.blue, 'Word');
    }
    if (n.endsWith('.pdf')) return (Icons.picture_as_pdf_outlined, MirrorColors.amber, 'PDF');
    if (n.endsWith('.xls') || n.endsWith('.xlsx')) {
      return (Icons.table_chart_outlined, MirrorColors.accentDeep, 'Excel');
    }
    if (n.endsWith('.ppt') || n.endsWith('.pptx')) {
      return (Icons.slideshow_outlined, MirrorColors.amber, 'PPT');
    }
    if (isMarkdown(n)) return (Icons.text_snippet_outlined, MirrorColors.text2, 'Markdown');
    if (n.endsWith('.txt')) return (Icons.notes_outlined, MirrorColors.text3, '文本');
    if (n.endsWith('.png') || n.endsWith('.jpg') || n.endsWith('.jpeg') || n.endsWith('.webp')) {
      return (Icons.image_outlined, MirrorColors.pink, '图片');
    }
    return (Icons.description_outlined, MirrorColors.blue, '文档');
  }
}
