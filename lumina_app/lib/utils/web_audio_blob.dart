import 'dart:typed_data';

import 'web_audio_blob_stub.dart'
    if (dart.library.html) 'web_audio_blob_web.dart' as impl;

Future<Uint8List?> readBlobUrl(String url) => impl.readBlobUrl(url);
