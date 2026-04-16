import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_book_writer/core/models/book_models.dart';

void main() {
  test('WorkspaceData serializes and deserializes book hierarchy', () {
    final now = DateTime.parse('2026-01-01T10:00:00.000Z');
    final workspace = WorkspaceData(
      books: [
        Book(
          id: 'book-1',
          title: 'Book',
          description: 'Desc',
          parts: [
            BookPart(
              id: 'part-1',
              title: 'Part',
              order: 1,
              chapters: [
                Chapter(
                  id: 'chapter-1',
                  title: 'Chapter',
                  order: 1,
                  scenes: [
                    Scene(
                      id: 'scene-1',
                      title: 'Scene',
                      order: 1,
                      content: 'Text',
                      createdAt: now,
                      updatedAt: now,
                    ),
                  ],
                ),
              ],
            ),
          ],
          storyBibleNotes: const [
            StoryBibleNote(id: 'note-1', title: 'World', content: 'Rules'),
          ],
          createdAt: now,
          updatedAt: now,
        ),
      ],
      activeBookId: 'book-1',
      selectedSceneId: 'scene-1',
      updatedAt: now,
    );

    final decoded = WorkspaceData.fromJson(workspace.toJson());

    expect(decoded.books.single.title, 'Book');
    expect(
      decoded.books.single.parts.single.chapters.single.scenes.single.content,
      'Text',
    );
    expect(decoded.activeBookId, 'book-1');
    expect(decoded.selectedSceneId, 'scene-1');
  });
}
