import 'dart:typed_data';
import 'package:universal_html/html.dart' as html;

class ExcelDownloader {
  static Future<void> saveBytes(Uint8List bytes, String filename) async {
    final blob = html.Blob(
      [bytes],
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );

    final url = html.Url.createObjectUrlFromBlob(blob);
    final a = html.AnchorElement(href: url)
      ..download = filename
      ..style.display = 'none';

    html.document.body!.children.add(a);
    a.click();
    a.remove();
    html.Url.revokeObjectUrl(url);
  }
}
