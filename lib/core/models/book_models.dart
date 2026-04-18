import 'dart:convert';

class WorkspaceData {
  const WorkspaceData({
    required this.books,
    required this.updatedAt,
    this.activeBookId,
    this.selectedSceneId,
  });

  final List<Book> books;
  final String? activeBookId;
  final String? selectedSceneId;
  final DateTime updatedAt;

  WorkspaceData copyWith({
    List<Book>? books,
    String? activeBookId,
    bool clearActiveBook = false,
    String? selectedSceneId,
    bool clearSelectedScene = false,
    DateTime? updatedAt,
  }) {
    return WorkspaceData(
      books: books ?? this.books,
      activeBookId: clearActiveBook ? null : activeBookId ?? this.activeBookId,
      selectedSceneId: clearSelectedScene
          ? null
          : selectedSceneId ?? this.selectedSceneId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'books': books.map((book) => book.toJson()).toList(growable: false),
      'activeBookId': activeBookId,
      'selectedSceneId': selectedSceneId,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  static WorkspaceData fromJson(Map<String, dynamic> json) {
    final booksJson = (json['books'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);

    return WorkspaceData(
      books: booksJson.map(Book.fromJson).toList(growable: false),
      activeBookId: json['activeBookId'] as String?,
      selectedSceneId: json['selectedSceneId'] as String?,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class Book {
  const Book({
    required this.id,
    required this.title,
    required this.parts,
    required this.storyBibleNotes,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
  });

  final String id;
  final String title;
  final String description;
  final List<BookPart> parts;
  final List<StoryBibleNote> storyBibleNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Book copyWith({
    String? title,
    String? description,
    List<BookPart>? parts,
    List<StoryBibleNote>? storyBibleNotes,
    DateTime? updatedAt,
  }) {
    return Book(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      parts: parts ?? this.parts,
      storyBibleNotes: storyBibleNotes ?? this.storyBibleNotes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'parts': parts.map((part) => part.toJson()).toList(growable: false),
      'storyBibleNotes': storyBibleNotes
          .map((note) => note.toJson())
          .toList(growable: false),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static Book fromJson(Map<String, dynamic> json) {
    final partsJson = (json['parts'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    final notesJson =
        (json['storyBibleNotes'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);

    return Book(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      parts: partsJson.map(BookPart.fromJson).toList(growable: false),
      storyBibleNotes: notesJson
          .map(StoryBibleNote.fromJson)
          .toList(growable: false),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class BookPart {
  const BookPart({
    required this.id,
    required this.title,
    required this.order,
    required this.chapters,
  });

  final String id;
  final String title;
  final int order;
  final List<Chapter> chapters;

  BookPart copyWith({String? title, int? order, List<Chapter>? chapters}) {
    return BookPart(
      id: id,
      title: title ?? this.title,
      order: order ?? this.order,
      chapters: chapters ?? this.chapters,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'order': order,
      'chapters': chapters
          .map((chapter) => chapter.toJson())
          .toList(growable: false),
    };
  }

  static BookPart fromJson(Map<String, dynamic> json) {
    final chaptersJson =
        (json['chapters'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);
    return BookPart(
      id: json['id'] as String,
      title: json['title'] as String,
      order: json['order'] as int? ?? 0,
      chapters: chaptersJson.map(Chapter.fromJson).toList(growable: false),
    );
  }
}

class Chapter {
  const Chapter({
    required this.id,
    required this.title,
    required this.order,
    required this.scenes,
  });

  final String id;
  final String title;
  final int order;
  final List<Scene> scenes;

  Chapter copyWith({String? title, int? order, List<Scene>? scenes}) {
    return Chapter(
      id: id,
      title: title ?? this.title,
      order: order ?? this.order,
      scenes: scenes ?? this.scenes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'order': order,
      'scenes': scenes.map((scene) => scene.toJson()).toList(growable: false),
    };
  }

  static Chapter fromJson(Map<String, dynamic> json) {
    final scenesJson = (json['scenes'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    return Chapter(
      id: json['id'] as String,
      title: json['title'] as String,
      order: json['order'] as int? ?? 0,
      scenes: scenesJson.map(Scene.fromJson).toList(growable: false),
    );
  }
}

class Scene {
  const Scene({
    required this.id,
    required this.title,
    required this.order,
    required this.createdAt,
    required this.updatedAt,
    this.content = '',
    this.imagePaths = const [],
  });

  final String id;
  final String title;
  final String content;
  final int order;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> imagePaths;

  Scene copyWith({
    String? title,
    String? content,
    int? order,
    DateTime? updatedAt,
    List<String>? imagePaths,
  }) {
    return Scene(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      order: order ?? this.order,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      imagePaths: imagePaths ?? this.imagePaths,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'order': order,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'imagePaths': imagePaths,
    };
  }

  static Scene fromJson(Map<String, dynamic> json) {
    return Scene(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String? ?? '',
      order: json['order'] as int? ?? 0,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      imagePaths: (json['imagePaths'] as List<dynamic>? ?? const <dynamic>[])
          .cast<String>(),
    );
  }
}

class StoryBibleNote {
  const StoryBibleNote({
    required this.id,
    required this.title,
    required this.content,
  });

  final String id;
  final String title;
  final String content;

  StoryBibleNote copyWith({String? title, String? content}) {
    return StoryBibleNote(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'title': title, 'content': content};
  }

  static StoryBibleNote fromJson(Map<String, dynamic> json) {
    return StoryBibleNote(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String? ?? '',
    );
  }
}
