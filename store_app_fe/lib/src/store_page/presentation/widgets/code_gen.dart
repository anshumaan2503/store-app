// lib/src/store/presentation/utils/code_gen.dart
String genCode({required String prefix, required String name}) {
  final clean = name.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), '');

  final part =
      clean.isEmpty ? 'X' : (clean.length <= 3 ? clean : clean.substring(0, 3));

  final ts = DateTime.now().millisecondsSinceEpoch.toString();
  final tail = ts.substring(ts.length - 4);

  return '$prefix-$part$tail'; // e.g. RM-WAR1234
}
