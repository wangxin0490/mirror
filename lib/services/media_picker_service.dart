import 'picked_image_bytes.dart';

import 'document_picker_service.dart' show pickDocument, PickedFileBytes;
import 'file_picker_service.dart' show pickFiles;
import 'image_picker_service.dart' show pickImages;

import 'media_picker_service_stub.dart'
    if (dart.library.js_interop) 'media_picker_service_web.dart' as camera;

export 'picked_image_bytes.dart';

/// 从相机拍照（Web 使用 capture 或降级选文件）。
Future<List<PickedImageBytes>> pickFromCamera() => camera.pickFromCamera();

/// 从相册选择图片。
Future<List<PickedImageBytes>> pickFromGallery({bool allowMultiple = false, int maxCount = 1}) =>
    pickImages(allowMultiple: allowMultiple, maxCount: maxCount);

/// 选择本地文件（任意类型）。
Future<List<PickedImageBytes>> pickLocalFile({int maxCount = 1}) => pickFiles(maxCount: maxCount);

/// 选择文档（与知识库导入一致）。
Future<PickedFileBytes?> pickLocalDocument() => pickDocument();
