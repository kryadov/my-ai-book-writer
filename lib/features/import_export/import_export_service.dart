import 'dart:io';

import 'package:archive/archive.dart';

enum ImportFormat { txt, markdown, docx, pdf }

enum ExportFormat { markdown, html, docx, pdf, epub }

class ImportExportService {
  const ImportExportService();

  Future<String> importFile({
    required String filePath,
    required ImportFormat format,
  }) async {
    switch (format) {
      case ImportFormat.txt:
      case ImportFormat.markdown:
        return File(filePath).readAsString();
      case ImportFormat.docx:
      case ImportFormat.pdf:
        throw UnsupportedError(
          'DOCX and PDF import adapters are planned but not implemented in this build.',
        );
    }
  }

  Future<void> exportFile({
    required String filePath,
    required String content,
    required ExportFormat format,
  }) async {
    switch (format) {
      case ExportFormat.markdown:
        await File(filePath).writeAsString(content);
        return;
      case ExportFormat.html:
        final html =
            '''
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Exported manuscript</title>
  </head>
  <body>
    <pre>${_escapeHtml(content)}</pre>
  </body>
</html>
''';
        await File(filePath).writeAsString(html);
        return;
      case ExportFormat.docx:
        await _exportDocx(filePath: filePath, content: content);
        return;
      case ExportFormat.pdf:
      case ExportFormat.epub:
        throw UnsupportedError(
          'PDF and EPUB export adapters are planned but not implemented in this build.',
        );
    }
  }

  Future<void> _exportDocx({
    required String filePath,
    required String content,
  }) async {
    final archive = Archive()
      ..addFile(ArchiveFile.string('[Content_Types].xml', _docxContentTypesXml))
      ..addFile(ArchiveFile.string('_rels/.rels', _docxRootRelationshipsXml))
      ..addFile(ArchiveFile.string('word/document.xml', _docxDocumentXml(content)))
      ..addFile(
        ArchiveFile.string(
          'word/_rels/document.xml.rels',
          _docxDocumentRelationshipsXml,
        ),
      );

    final encoded = ZipEncoder().encode(archive);
    await File(filePath).writeAsBytes(encoded, flush: true);
  }

  String _docxDocumentXml(String content) {
    final lines = content
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');
    final bodyParagraphs = lines
        .map(
          (line) => line.isEmpty
              ? '<w:p/>'
              : '<w:p><w:r><w:t xml:space="preserve">${_escapeXml(line)}</w:t></w:r></w:p>',
        )
        .join();

    return '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    $bodyParagraphs
    <w:sectPr>
      <w:pgSz w:w="12240" w:h="15840"/>
      <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="708" w:footer="708" w:gutter="0"/>
      <w:cols w:space="708"/>
      <w:docGrid w:linePitch="360"/>
    </w:sectPr>
  </w:body>
</w:document>
''';
  }

  String get _docxContentTypesXml => '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>
''';

  String get _docxRootRelationshipsXml => '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>
''';

  String get _docxDocumentRelationshipsXml => '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>
''';

  String _escapeXml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  String _escapeHtml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#039;');
  }
}
