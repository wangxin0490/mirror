import 'picked_image_bytes.dart';

import 'image_picker_service_stub.dart'
    if (dart.library.js_interop) 'image_picker_service_web.dart' as platform;

export 'picked_image_bytes.dart';

/// 跨平台选图（Web 用原生 input，避免 file_picker 未初始化）。
Future<List<PickedImageBytes>> pickImages({bool allowMultiple = true, int maxCount = 9}) =>
    platform.pickImages(allowMultiple: allowMultiple, maxCount: maxCount);
