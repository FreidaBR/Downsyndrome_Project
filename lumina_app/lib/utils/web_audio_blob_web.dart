import 'dart:html' as html;
import 'dart:typed_data';

Future<Uint8List?> readBlobUrl(String url) async {
  try {
    final request = await html.HttpRequest.request(
      url,
      method: 'GET',
      responseType: 'arraybuffer',
    );
    final buffer = request.response as ByteBuffer;
    return buffer.asUint8List();
  } catch (_) {
    return null;
  }
}
