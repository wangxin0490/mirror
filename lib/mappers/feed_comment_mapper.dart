import 'package:flutter/material.dart';

import '../models/feed_models.dart';
import '../theme/mirror_colors.dart';
/// 评论行视图数据（供 CommentsThreadList 动态渲染，不改变 UI 样式）。
class CommentRowView {
  CommentRowView({
    required this.id,
    required this.userId,
    required this.av,
    required this.grad,
    this.avatarUrl = '',
    required this.name,
    this.role,
    this.roleBg,
    this.roleFg,
    required this.text,
    required this.time,
    required this.likes,
    this.nested = const [],
    this.moreReplies,
  });

  final int id;
  final int userId;
  final String av;
  final LinearGradient grad;
  final String avatarUrl;
  final String name;
  final String? role;
  final Color? roleBg;
  final Color? roleFg;
  final String text;
  final String time;
  final String likes;
  final List<CommentNestView> nested;
  final String? moreReplies;
}

class CommentNestView {
  CommentNestView({
    required this.commentId,
    required this.userId,
    required this.av,
    required this.grad,
    this.avatarUrl = '',
    required this.name,
    required this.isAuthor,
    required this.replyTo,
    required this.text,
  });

  final int commentId;
  final int userId;
  final String av;
  final Color grad;
  final String avatarUrl;
  final String name;
  final bool isAuthor;
  final String replyTo;
  final String text;
}

LinearGradient _grad(String variant) {
  switch (variant) {
    case 'green':
      return MirrorGradients.green;
    case 'pink':
      return MirrorGradients.pink;
    case 'blue':
      return MirrorGradients.blue;
    case 'amber':
      return MirrorGradients.amber;
    default:
      return MirrorGradients.purple;
  }
}

(Color, Color)? _roleColors(String role) {
  if (role.isEmpty) return null;
  final r = role.toLowerCase();
  if (r.contains('k8s') || r.contains('大佬')) {
    return (MirrorColors.blueSoft, MirrorColors.blueText);
  }
  if (r.contains('长文') || r.contains('专家')) {
    return (MirrorColors.greenSoft, MirrorColors.greenText);
  }
  if (r.contains('prompt') || r.contains('工匠') || r.contains('编辑')) {
    return (MirrorColors.pinkSoft, MirrorColors.pinkText);
  }
  if (r.contains('凌晨')) {
    return (MirrorColors.coralSoft, MirrorColors.coralText);
  }
  return (MirrorColors.accentSoft, MirrorColors.accentDeep);
}

List<CommentRowView> mapCommentsToRows(List<FeedCommentDto> items) {
  return items.map((c) {
    final rc = _roleColors(c.roleLabel);
    return CommentRowView(
      id: c.commentId,
      userId: c.author.userId,
      av: c.author.avatarLetter,
      grad: _grad(c.author.avatarVariant),
      avatarUrl: c.author.avatarUrl,
      name: c.author.displayName,
      role: c.roleLabel.isEmpty ? null : c.roleLabel,
      roleBg: rc?.$1,
      roleFg: rc?.$2,
      text: c.content,
      time: c.timeLabel,
      likes: c.likesLabel,
      nested: c.replies
          .map(
            (r) => CommentNestView(
              commentId: r.commentId,
              userId: r.author.userId,
              av: r.author.avatarLetter,
              grad: MirrorColors.accent,
              avatarUrl: r.author.avatarUrl,
              name: r.author.displayName,
              isAuthor: r.replyToName.isNotEmpty,
              replyTo: r.replyToName,
              text: r.content,
            ),
          )
          .toList(),
    );
  }).toList();
}
