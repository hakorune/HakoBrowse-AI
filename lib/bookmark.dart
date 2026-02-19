import 'dart:convert';

enum BookmarkNodeType { folder, link }

class BookmarkNode {
  final String id;
  final BookmarkNodeType type;
  final String title;
  final String? url;
  final DateTime createdAt;
  final bool pinned;
  final List<BookmarkNode> children;

  const BookmarkNode({
    required this.id,
    required this.type,
    required this.title,
    required this.createdAt,
    this.url,
    this.pinned = false,
    this.children = const <BookmarkNode>[],
  });

  factory BookmarkNode.folder({
    required String id,
    required String title,
    DateTime? createdAt,
    List<BookmarkNode> children = const <BookmarkNode>[],
  }) {
    return BookmarkNode(
      id: id,
      type: BookmarkNodeType.folder,
      title: title,
      createdAt: createdAt ?? DateTime.now(),
      children: children,
    );
  }

  factory BookmarkNode.link({
    required String id,
    required String title,
    required String url,
    DateTime? createdAt,
    bool pinned = false,
  }) {
    return BookmarkNode(
      id: id,
      type: BookmarkNodeType.link,
      title: title,
      url: url,
      createdAt: createdAt ?? DateTime.now(),
      pinned: pinned,
    );
  }

  bool get isFolder => type == BookmarkNodeType.folder;
  bool get isLink => type == BookmarkNodeType.link;

  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    return (url ?? '').trim();
  }

  BookmarkNode copyWith({
    String? id,
    BookmarkNodeType? type,
    String? title,
    String? url,
    DateTime? createdAt,
    bool? pinned,
    List<BookmarkNode>? children,
  }) {
    return BookmarkNode(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      url: url ?? this.url,
      createdAt: createdAt ?? this.createdAt,
      pinned: pinned ?? this.pinned,
      children: children ?? this.children,
    );
  }

  BookmarkNode deepCopy() {
    return copyWith(
      children: children.map((c) => c.deepCopy()).toList(growable: false),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'url': url,
      'createdAt': createdAt.toIso8601String(),
      'pinned': pinned,
      'children': children.map((c) => c.toMap()).toList(),
    };
  }

  factory BookmarkNode.fromMap(Map<String, dynamic> map) {
    final typeRaw = map['type']?.toString() ?? 'link';
    final type =
        typeRaw == 'folder' ? BookmarkNodeType.folder : BookmarkNodeType.link;
    final childList = (map['children'] as List?)
            ?.whereType<Map>()
            .map((m) => BookmarkNode.fromMap(Map<String, dynamic>.from(m)))
            .toList(growable: false) ??
        const <BookmarkNode>[];

    return BookmarkNode(
      id: map['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      type: type,
      title: map['title']?.toString() ?? '',
      url: map['url']?.toString(),
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      pinned: map['pinned'] == true,
      children:
          type == BookmarkNodeType.folder ? childList : const <BookmarkNode>[],
    );
  }

  String toJson() => jsonEncode(toMap());

  factory BookmarkNode.fromJson(String source) =>
      BookmarkNode.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
