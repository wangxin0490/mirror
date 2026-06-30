import 'picked_image_bytes.dart';

import 'file_picker_service_stub.dart'
    if (dart.library.js_interop) 'file_picker_service_web.dart' as platform;

export 'picked_image_bytes.dart';

/// 跨平台选择任意文件（Web 用原生 input，其它平台用 file_picker）。
Future<List<PickedImageBytes>> pickFiles({bool allowMultiple = false, int maxCount = 1}) =>
    platform.pickFiles(allowMultiple: allowMultiple, maxCount: maxCount);
