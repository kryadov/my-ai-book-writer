import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'package:my_ai_book_writer/features/import_export/import_export_service.dart';

void main() {
  group('ImportExportService', () {
    const service = ImportExportService();

    test('imports markdown text', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'my_ai_book_writer_import_test',
      );
      final file = File('${tempDir.path}${Platform.pathSeparator}scene.md');
      await file.writeAsString('# Scene\n\nText');

      addTearDown(() async {
        await tempDir.delete(recursive: true);
      });

      final text = await service.importFile(
        filePath: file.path,
        format: ImportFormat.markdown,
      );

      expect(text, '# Scene\n\nText');
    });

    test('exports markdown and html', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'my_ai_book_writer_export_test',
      );
      final markdownFile = File(
        '${tempDir.path}${Platform.pathSeparator}out.md',
      );
      final htmlFile = File('${tempDir.path}${Platform.pathSeparator}out.html');

      addTearDown(() async {
        await tempDir.delete(recursive: true);
      });

      await service.exportFile(
        filePath: markdownFile.path,
        content: 'Alpha <beta>',
        format: ExportFormat.markdown,
      );
      await service.exportFile(
        filePath: htmlFile.path,
        content: 'Alpha <beta>',
        format: ExportFormat.html,
      );

      expect(await markdownFile.readAsString(), 'Alpha <beta>');
      final html = await htmlFile.readAsString();
      expect(html, contains('<pre>Alpha &lt;beta&gt;</pre>'));
    });

    test('exports docx package with main document xml', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'my_ai_book_writer_export_docx_test',
      );
      final docxFile = File('${tempDir.path}${Platform.pathSeparator}out.docx');

      addTearDown(() async {
        await tempDir.delete(recursive: true);
      });

      await service.exportFile(
        filePath: docxFile.path,
        content: 'Alpha <beta>\n\nGamma',
        format: ExportFormat.docx,
      );

      final archive = ZipDecoder().decodeBytes(await docxFile.readAsBytes());
      String? entryContent(String name) {
        final file = archive.findFile(name);
        if (file == null || file.isFile == false) {
          return null;
        }

        final bytes = file.content as List<int>;
        return String.fromCharCodes(bytes);
      }

      final contentTypesXml = entryContent('[Content_Types].xml');
      final relsXml = entryContent('_rels/.rels');
      final documentXml = entryContent('word/document.xml');

      expect(contentTypesXml, isNotNull);
      expect(relsXml, isNotNull);
      expect(documentXml, isNotNull);
      expect(documentXml, contains('Alpha &lt;beta&gt;'));
      expect(documentXml, contains('Gamma'));
    });

    test('throws for non-implemented binary formats', () async {
      expect(
        () => service.importFile(filePath: 'x.pdf', format: ImportFormat.pdf),
        throwsUnsupportedError,
      );
      expect(
        () => service.exportFile(
          filePath: 'x.epub',
          content: 'x',
          format: ExportFormat.epub,
        ),
        throwsUnsupportedError,
      );
    });
  });
}
