part of 'bookmark_service.dart';

void _writeHtmlNodes({
  required StringBuffer buffer,
  required List<BookmarkNode> nodes,
  required int depth,
}) {
  final indent = '    ' * depth;
  for (final node in nodes) {
    if (node.isFolder) {
      buffer.writeln('$indent<DT><H3>${_encodeHtml(node.displayTitle)}</H3>');
      buffer.writeln('$indent<DL><p>');
      _writeHtmlNodes(buffer: buffer, nodes: node.children, depth: depth + 1);
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
