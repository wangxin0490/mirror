import 'package:image_picker/image_picker.dart';

import 'picked_image_bytes.dart';

Future<List<PickedImageBytes>> pickFromCamera() async {
  final picker = ImagePicker();
  final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
  if (file == null) return [];
  final bytes = await file.readAsBytes();
  if (bytes.isEmpty) return [];
  final name = file.name.isNotEmpty ? file.name : 'photo.jpg';
  return [PickedImageBytes(name: name, bytes: bytes)];
}
