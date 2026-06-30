import 'dart:typed_data';

import 'document_path_reader_io.dart' if (dart.library.html) 'document_path_reader_stub.dart' as impl;

Future<Uint8List?> readFileBytesFromPath(String path) => impl.readFileBytesFromPath(path);
