import 'dart:io';

void main() {
  final dir = Directory('lib');
  if (!dir.existsSync()) return;

  for (final file in dir.listSync(recursive: true)) {
    if (file is File && file.path.endsWith('.dart')) {
      var content = file.readAsStringSync();
      var original = content;

      content = content.replaceAllMapped(RegExp(r"json\['([^']+)'\]\s+as\s+int,"), (match) {
        final key = match.group(1);
        return "int.tryParse(json['$key']?.toString() ?? '') ?? 0,";
      });
      
      content = content.replaceAllMapped(RegExp(r"json\['([^']+)'\]\s+as\s+int\?,"), (match) {
        final key = match.group(1);
        return "json['$key'] != null ? int.tryParse(json['$key'].toString()) : null,";
      });

      if (content != original) {
        file.writeAsStringSync(content);
        print('Updated ${file.path}');
      }
    }
  }
}
