import 'picked_file_bytes.dart';

import 'document_picker_service_io.dart'
    if (dart.library.js_interop) 'document_picker_service_web.dart' as platform;

export 'picked_file_bytes.dart';

/// 跨平台选文档（Web 用原生 input，桌面用 file_picker）。
Future<PickedFileBytes?> pickDocument() => platform.pickDocument();
