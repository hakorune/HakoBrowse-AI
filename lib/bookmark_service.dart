import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'bookmark.dart';

enum DuplicateStrategy { overwrite, keepBoth }

class BookmarkService {
  static const String _storageKey = 'bookmarks_tree_v2';

  Future<List<BookmarkNode>> loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) return <BookmarkNode>[];

    try {
      final decoded = jsonDecode(raw);
      final nodes = _decodeNodeList(decoded);
      return _cloneTree(nodes);
    } catch (_) {
      return <BookmarkNode>[];
    }
  }

  Future<void> saveBookmarks(List<BookmarkNode> bookmarks) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(bookmarks.map((b) => b.toMap()).toList());
    await prefs.setString(_storageKey, raw);
  }

  Future<List<BookmarkNode>> clearAll() async {
    const empty = <BookmarkNode>[];
    await saveBookmarks(empty);
    return empty;
  }

  int countLinks(List<BookmarkNode> nodes) {
    var count = 0;
    for (final node in nodes) {
      if (node.isLink) {
        count += 1;
        continue;
      }
      count += countLinks(node.children);
    }
    return count;
  }

  List<BookmarkNode> flattenLinks(List<BookmarkNode> nodes) {
    final out = <BookmarkNode>[];
    void visit(List<BookmarkNode> items) {
      for (final node in items) {
        if (node.isLink) {
          out.add(node);
        } else {
          visit(node.children);
        }
      }
    }

    visit(nodes);
    return out;
  }

  List<BookmarkNode> flattenFolders(List<BookmarkNode> nodes) {
    final out = <BookmarkNode>[];
    void visit(List<BookmarkNode> items) {
      for (final node in items) {
        if (!node.isFolder) continue;
        out.add(node);
        visit(node.children);
      }
    }

    visit(nodes);
    return out;
  }

  bool isBookmarked(List<BookmarkNode> bookmarks, String url) {
    final target = url.trim();
    if (target.isEmpty) return false;
    for (final link in flattenLinks(bookmarks)) {
      if ((link.url ?? '').trim() == target) return true;
    }
    return false;
  }

  Future<List<BookmarkNode>> addBookmark({
    required String title,
    required String url,
    String? folderId,
    String? folderName,
    DuplicateStrategy duplicateStrategy = DuplicateStrategy.overwrite,
  }) async {
    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty) {
      return loadBookmarks();
    }

    var nodes = _cloneTree(await loadBookmarks());
    String? targetFolderId = (folderId ?? '').trim().isEmpty ? null : folderId;

    final normalizedFolderName = (folderName ?? '').trim();
    if (targetFolderId == null && normalizedFolderName.isNotEmpty) {
      final ensured = _ensureRootFolder(nodes, normalizedFolderName);
      nodes = ensured.nodes;
      targetFolderId = ensured.folderId;
    }

    if (duplicateStrategy == DuplicateStrategy.overwrite) {
      final extracted = _extractFirstLinkByUrl(nodes, normalizedUrl);
      nodes = extracted.nodes;
      if (extracted.extracted != null) {
        final updated = extracted.extracted!.copyWith(
          title: title.trim().isEmpty ? normalizedUrl : title.trim(),
          url: normalizedUrl,
          createdAt: DateTime.now(),
        );
        nodes = _insertNode(nodes, updated, targetFolderId);
        await saveBookmarks(nodes);
        return nodes;
      }
    }

    final newNode = BookmarkNode.link(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title.trim().isEmpty ? normalizedUrl : title.trim(),
      url: normalizedUrl,
      createdAt: DateTime.now(),
    );
    nodes = _insertNode(nodes, newNode, targetFolderId);
    await saveBookmarks(nodes);
    return nodes;
  }

  Future<List<BookmarkNode>> addFolder({
    required String name,
    String? parentFolderId,
  }) async {
    final normalized = name.trim();
    if (normalized.isEmpty) return loadBookmarks();
    final nodes = _cloneTree(await loadBookmarks());

    final targetFolderId =
        (parentFolderId ?? '').trim().isEmpty ? null : parentFolderId;
    final newFolder = BookmarkNode.folder(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: normalized,
      createdAt: DateTime.now(),
      children: <BookmarkNode>[],
    );

    final updated = _insertNode(nodes, newFolder, targetFolderId);
    await saveBookmarks(updated);
    return updated;
  }

  Future<List<BookmarkNode>> removeBookmarkById(String id) async {
    final nodes = _cloneTree(await loadBookmarks());
    final extracted = _extractNodeById(nodes, id);
    if (extracted.extracted == null) return nodes;
    await saveBookmarks(extracted.nodes);
    return extracted.nodes;
  }

  Future<List<BookmarkNode>> removeFirstByUrl(String url) async {
    final normalized = url.trim();
    if (normalized.isEmpty) return loadBookmarks();
    final nodes = _cloneTree(await loadBookmarks());
    final extracted = _extractFirstLinkByUrl(nodes, normalized);
    if (extracted.extracted == null) return nodes;
    await saveBookmarks(extracted.nodes);
    return extracted.nodes;
  }

  Future<List<BookmarkNode>> renameNode({
    required String id,
    required String title,
  }) async {
    final normalized = title.trim();
    if (normalized.isEmpty) return loadBookmarks();
    final nodes = _cloneTree(await loadBookmarks());
    final updated = _updateNodeById(
      nodes,
      id,
      (node) => node.copyWith(title: normalized),
    );
    if (!updated.changed) return nodes;
    await saveBookmarks(updated.nodes);
    return updated.nodes;
  }

  Future<List<BookmarkNode>> updatePinned({
    required String id,
    required bool pinned,
  }) async {
    final nodes = _cloneTree(await loadBookmarks());
    final updated = _updateNodeById(nodes, id, (node) {
      if (!node.isLink) return node;
      return node.copyWith(pinned: pinned, createdAt: DateTime.now());
    });
    if (!updated.changed) return nodes;
    await saveBookmarks(updated.nodes);
    return updated.nodes;
  }

  Future<List<BookmarkNode>> moveNode({
    required String id,
    String? parentFolderId,
  }) async {
    final nodes = _cloneTree(await loadBookmarks());
    final extracted = _extractNodeById(nodes, id);
    final target = extracted.extracted;
    if (target == null) return nodes;

    final normalizedParent =
        (parentFolderId ?? '').trim().isEmpty ? null : parentFolderId;

    if (normalizedParent == id) {
      return nodes;
    }
    if (target.isFolder &&
        normalizedParent != null &&
        _containsFolderId(target.children, normalizedParent)) {
      return nodes;
    }

    final moved = _insertNode(extracted.nodes, target, normalizedParent);
    await saveBookmarks(moved);
    return moved;
  }

  Future<List<BookmarkNode>> importJsonText(String rawText) async {
    final decoded = jsonDecode(rawText);
    final nodes = _decodeNodeList(decoded);
    await saveBookmarks(nodes);
    return _cloneTree(nodes);
  }

  String exportJsonText(List<BookmarkNode> nodes) {
    return const JsonEncoder.withIndent('  ')
        .convert(nodes.map((n) => n.toMap()).toList());
  }

  Future<List<BookmarkNode>> importHtmlText(String htmlText) async {
    final root = <BookmarkNode>[];
    final stack = <List<BookmarkNode>>[root];
    BookmarkNode? pendingFolder;

    final tokenPattern = RegExp(
      r'<DT>\s*<H3[^>]*>(.*?)</H3>|<DT>\s*<A[^>]*HREF\s*=\s*"([^"]+)"[^>]*>(.*?)</A>|<DL[^>]*>|</DL>',
      caseSensitive: false,
      dotAll: true,
    );

    for (final match in tokenPattern.allMatches(htmlText)) {
      final folderTitle = match.group(1);
      final href = match.group(2);
      final linkTitle = match.group(3);
      final token = match.group(0) ?? '';

      if (folderTitle != null) {
        final folder = BookmarkNode.folder(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: _decodeHtmlEntities(folderTitle.trim()),
          createdAt: DateTime.now(),
          children: <BookmarkNode>[],
        );
        stack.last.add(folder);
        pendingFolder = folder;
        continue;
      }

      if (href != null) {
        final normalizedUrl = _decodeHtmlEntities(href.trim());
        if (normalizedUrl.isEmpty) continue;
        final title = _decodeHtmlEntities((linkTitle ?? '').trim());
        stack.last.add(
          BookmarkNode.link(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            title: title.isEmpty ? normalizedUrl : title,
            url: normalizedUrl,
            createdAt: DateTime.now(),
          ),
        );
        pendingFolder = null;
        continue;
      }

      final lowerToken = token.toLowerCase();
      if (lowerToken.startsWith('<dl')) {
        if (pendingFolder != null) {
          stack.add(pendingFolder.children);
          pendingFolder = null;
        }
        continue;
      }

      if (lowerToken.startsWith('</dl')) {
        pendingFolder = null;
        if (stack.length > 1) {
          stack.removeLast();
        }
      }
    }

    await saveBookmarks(root);
    return _cloneTree(root);
  }

  String exportHtmlText(List<BookmarkNode> nodes) {
    final buffer = StringBuffer();
    buffer.writeln('<!DOCTYPE NETSCAPE-Bookmark-file-1>');
    buffer.writeln(
        '<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">');
    buffer.writeln('<TITLE>Bookmarks</TITLE>');
    buffer.writeln('<H1>Bookmarks</H1>');
    buffer.writeln('<DL><p>');
    _writeHtmlNodes(buffer, nodes, 1);
    buffer.writeln('</DL><p>');
    return buffer.toString();
  }

  void _writeHtmlNodes(
      StringBuffer buffer, List<BookmarkNode> nodes, int depth) {
    final indent = '    ' * depth;
    for (final node in nodes) {
      if (node.isFolder) {
        buffer.writeln('$indent<DT><H3>${_encodeHtml(node.displayTitle)}</H3>');
        buffer.writeln('$indent<DL><p>');
        _writeHtmlNodes(buffer, node.children, depth + 1);
        buffer.writeln('$indent</DL><p>');
      } else {
        final url = _encodeHtml((node.url ?? '').trim());
        if (url.isEmpty) continue;
        buffer.writeln(
          '$indent<DT><A HREF="$url">${_encodeHtml(node.displayTitle)}</A>',
        );
      }
    }
  }

  _EnsureFolderResult _ensureRootFolder(List<BookmarkNode> nodes, String name) {
    for (final node in nodes) {
      if (node.isFolder &&
          node.title.trim().toLowerCase() == name.toLowerCase()) {
        return _EnsureFolderResult(nodes: nodes, folderId: node.id);
      }
    }
    final folder = BookmarkNode.folder(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: name,
      createdAt: DateTime.now(),
      children: <BookmarkNode>[],
    );
    return _EnsureFolderResult(nodes: [...nodes, folder], folderId: folder.id);
  }

  List<BookmarkNode> _cloneTree(List<BookmarkNode> source) {
    return source.map((n) => n.deepCopy()).toList();
  }

  List<BookmarkNode> _decodeNodeList(dynamic decoded) {
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((m) => BookmarkNode.fromMap(Map<String, dynamic>.from(m)))
          .toList(growable: false);
    }
    if (decoded is Map && decoded['nodes'] is List) {
      final list = decoded['nodes'] as List;
      return list
          .whereType<Map>()
          .map((m) => BookmarkNode.fromMap(Map<String, dynamic>.from(m)))
          .toList(growable: false);
    }
    return <BookmarkNode>[];
  }

  _ExtractNodeResult _extractFirstLinkByUrl(
      List<BookmarkNode> nodes, String url) {
    final out = <BookmarkNode>[];
    BookmarkNode? found;
    for (final node in nodes) {
      if (found == null && node.isLink && (node.url ?? '').trim() == url) {
        found = node;
        continue;
      }
      if (found == null && node.isFolder) {
        final child = _extractFirstLinkByUrl(node.children, url);
        if (child.extracted != null) {
          found = child.extracted;
          out.add(node.copyWith(children: child.nodes));
          continue;
        }
      }
      out.add(node);
    }
    return _ExtractNodeResult(nodes: out, extracted: found);
  }

  _ExtractNodeResult _extractNodeById(List<BookmarkNode> nodes, String id) {
    final out = <BookmarkNode>[];
    BookmarkNode? found;
    for (final node in nodes) {
      if (found == null && node.id == id) {
        found = node;
        continue;
      }
      if (found == null && node.isFolder) {
        final child = _extractNodeById(node.children, id);
        if (child.extracted != null) {
          found = child.extracted;
          out.add(node.copyWith(children: child.nodes));
          continue;
        }
      }
      out.add(node);
    }
    return _ExtractNodeResult(nodes: out, extracted: found);
  }

  List<BookmarkNode> _insertNode(
    List<BookmarkNode> nodes,
    BookmarkNode node,
    String? folderId,
  ) {
    if (folderId == null || folderId.trim().isEmpty) {
      return [...nodes, node];
    }
    final inserted = _insertIntoFolder(nodes, folderId, node);
    if (inserted.changed) return inserted.nodes;
    return [...nodes, node];
  }

  _ModifyResult _insertIntoFolder(
    List<BookmarkNode> nodes,
    String folderId,
    BookmarkNode nodeToAdd,
  ) {
    var changed = false;
    final out = <BookmarkNode>[];

    for (final node in nodes) {
      if (node.isFolder && node.id == folderId) {
        changed = true;
        out.add(node.copyWith(children: [...node.children, nodeToAdd]));
        continue;
      }
      if (node.isFolder) {
        final child = _insertIntoFolder(node.children, folderId, nodeToAdd);
        if (child.changed) {
          changed = true;
          out.add(node.copyWith(children: child.nodes));
          continue;
        }
      }
      out.add(node);
    }

    return _ModifyResult(nodes: out, changed: changed);
  }

  _ModifyResult _updateNodeById(
    List<BookmarkNode> nodes,
    String id,
    BookmarkNode Function(BookmarkNode node) transform,
  ) {
    var changed = false;
    final out = <BookmarkNode>[];

    for (final node in nodes) {
      if (node.id == id) {
        out.add(transform(node));
        changed = true;
        continue;
      }
      if (node.isFolder) {
        final child = _updateNodeById(node.children, id, transform);
        if (child.changed) {
          out.add(node.copyWith(children: child.nodes));
          changed = true;
          continue;
        }
      }
      out.add(node);
    }

    return _ModifyResult(nodes: out, changed: changed);
  }

  bool _containsFolderId(List<BookmarkNode> nodes, String folderId) {
    for (final node in nodes) {
      if (!node.isFolder) continue;
      if (node.id == folderId) return true;
      if (_containsFolderId(node.children, folderId)) return true;
    }
    return false;
  }

  String _encodeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  String _decodeHtmlEntities(String value) {
    return value
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&gt;', '>')
        .replaceAll('&lt;', '<')
        .replaceAll('&amp;', '&');
  }
}

class _ExtractNodeResult {
  final List<BookmarkNode> nodes;
  final BookmarkNode? extracted;

  const _ExtractNodeResult({required this.nodes, required this.extracted});
}

class _ModifyResult {
  final List<BookmarkNode> nodes;
  final bool changed;

  const _ModifyResult({required this.nodes, required this.changed});
}

class _EnsureFolderResult {
  final List<BookmarkNode> nodes;
  final String folderId;

  const _EnsureFolderResult({required this.nodes, required this.folderId});
}
