import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/models/chat_models.dart';
import 'package:mirror_mobile/utils/dm_file_message.dart';
import 'package:mirror_mobile/utils/dm_share_message.dart';

void main() {
  test('encode and parse user share', () {
    const share = DmUserShare(
      userId: 42,
      displayName: '陈墨 · DevOps',
      handle: 'chen.mo',
      avatarLetter: '陈',
      tagline: 'K8S 大佬',
    );
    final body = encodeUserShare(share);
    final parsed = parseUserShareBody(body);
    expect(parsed?.userId, share.userId);
    expect(parsed?.displayName, share.displayName);
    expect(parsed?.handle, share.handle);
    expect(userSharePreview(share), '[主页] 陈墨 · DevOps');
  });

  test('normalizeConversationPreview for user share', () {
    const body =
        '[[mirror:user]]{"user_id":42,"display_name":"陈墨 · DevOps","handle":"chen.mo"}';
    expect(normalizeConversationPreview(body), '[主页] 陈墨 · DevOps');
  });

  test('dmMessagePreview for user share message', () {
    final msg = ChatMessage(
      id: 1,
      conversationId: 1,
      senderId: 2,
      type: 'text',
      body: encodeUserShare(
        const DmUserShare(userId: 3, displayName: '测试博主'),
      ),
    );
    expect(dmMessagePreview(msg), '[主页] 测试博主');
  });
}
