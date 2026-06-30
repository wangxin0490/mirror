import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/models/kb_models.dart';
import 'package:mirror_mobile/state/kb_store.dart';

KbDocumentItem _doc(int id, String status) => KbDocumentItem(
      id: id,
      originalFilename: '$id.pdf',
      parseStatus: status,
    );

KbDetail _detail(List<KbDocumentItem> docs, {int ready = 0}) => KbDetail(
      id: 1,
      name: 'test',
      documents: docs,
      readyDocCount: ready,
    );

void main() {
  test('kbHasPendingDocs detects in-flight statuses', () {
    expect(kbHasPendingDocs([_doc(1, 'ready')]), isFalse);
    expect(kbHasPendingDocs([_doc(1, 'uploaded')]), isTrue);
    expect(kbHasPendingDocs([_doc(1, 'parsing')]), isTrue);
    expect(kbHasPendingDocs([_doc(1, 'uploading')]), isTrue);
  });

  test('kbDocsStatusChanged compares document parse statuses', () {
    final before = _detail([_doc(1, 'parsing')]);
    final after = _detail([_doc(1, 'ready')], ready: 1);
    expect(kbDocsStatusChanged(before, after), isTrue);
    expect(kbDocsStatusChanged(after, after), isFalse);
    expect(kbDocsStatusChanged(before, before), isFalse);
  });

  test('kbMergeSyncItems updates parse status in place', () {
    final detail = _detail([_doc(1, 'parsing')]);
    final merged = kbMergeSyncItems(
      detail,
      [KbDocStatusItem(id: 1, parseStatus: 'ready', chunkNum: 3)],
      1,
    );
    expect(merged, isNotNull);
    expect(merged!.documents.first.parseStatus, 'ready');
    expect(merged.readyDocCount, 1);
  });
}
