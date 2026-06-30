import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/data/mirror_authors.dart';
import 'package:mirror_mobile/config/api_config.dart';
import 'package:mirror_mobile/screens/author_profile_screen.dart';
import 'package:mirror_mobile/screens/mirror_screens_part3.dart';
import 'package:mirror_mobile/screens/post_detail_data.dart';
import 'package:mirror_mobile/screens/post_detail_screen.dart';
import 'package:mirror_mobile/state/kb_subscription_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Post detail shows "订阅知识库" when not subscribed', (tester) async {
    final base = PostDetailData.byId(PostDetailId.soul);
    final kb = const SharedKnowledgeBaseInfo(
      name: '一个未订阅的知识库',
      author: '作者',
      docCount: 3,
      summary: '摘要',
      apiKbId: null,
    );
    final data = PostDetailData(
      id: base.id,
      author: base.author,
      slides: base.slides,
      intervalMs: base.intervalMs,
      title: base.title,
      meta: base.meta,
      blocks: base.blocks,
      tags: base.tags,
      actions: base.actions,
      markdownBody: base.markdownBody,
      sharedKb: kb,
    );

    expect(KbSubscriptionStore.instance.contains(kb.name), isFalse);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PostDetailScreen(data: data))));
    expect(find.text('订阅知识库'), findsOneWidget);
    expect(find.textContaining('不是已订阅'), findsNothing);
  });

  testWidgets('Post detail disables subscribe when KB has zero docs', (tester) async {
    final base = PostDetailData.byId(PostDetailId.soul);
    const kb = SharedKnowledgeBaseInfo(
      name: 'liufan · 知识库',
      author: 'liufan',
      docCount: 0,
      summary: '摘要',
      apiKbId: 42,
    );
    final data = PostDetailData(
      id: base.id,
      author: base.author,
      slides: base.slides,
      intervalMs: base.intervalMs,
      title: base.title,
      meta: base.meta,
      blocks: base.blocks,
      tags: base.tags,
      actions: base.actions,
      markdownBody: base.markdownBody,
      sharedKb: kb,
    );

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PostDetailScreen(data: data))));
    await tester.pump();

    expect(find.text('暂无可订阅文档'), findsOneWidget);
    expect(find.text('订阅知识库'), findsNothing);
  });

  testWidgets('Author profile header has no LinearGradient', (tester) async {
    await tester.pumpWidget(MaterialApp(home: AuthorProfileScreen(author: MirrorAuthor.catalog.first)));
    await tester.pump();

    final bg = tester.widget<Container>(find.byKey(const Key('author-profile-header-bg')));
    final deco = bg.decoration as BoxDecoration?;
    expect(deco?.gradient, isNull);
  });

  testWidgets('Me header has no LinearGradient', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await ApiConfig.saveSession(token: 't', userId: 1, displayName: '测试用户', handle: 'test', avatarLetter: '测');
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MeScreen())));
    await tester.pump();

    final card = tester.widget<Container>(find.byKey(const Key('me-profile-card')));
    final deco = card.decoration as BoxDecoration?;
    expect(deco?.gradient, isNull);
  });

  testWidgets('KB has single add button only in personal section', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: KnowledgeBaseScreen())));

    expect(find.byKey(const Key('kb-header-add')), findsNothing);
    expect(find.byKey(const Key('kb-detail-add')), findsNothing);
    expect(find.byKey(const Key('kb-personal-create-folder')), findsOneWidget);
  });

  testWidgets('KB create button opens create-folder sheet', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: KnowledgeBaseScreen())));

    await tester.tap(find.byKey(const Key('kb-personal-create-folder')));
    // 避免 pumpAndSettle：弹窗里的 TextField 获取焦点后光标闪烁会让 settle 永远不结束
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('创建个人知识库'), findsWidgets);
    expect(find.text('设置名称与封面，之后再导入知识'), findsOneWidget);
    expect(find.text('上传封面'), findsOneWidget);
    expect(find.text('可选，用一张图代表这个知识库'), findsOneWidget);
    expect(find.text('新建一个分类并设置封面'), findsOneWidget);
  });
}

