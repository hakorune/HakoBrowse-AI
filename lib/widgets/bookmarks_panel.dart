import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../bookmark.dart';

class BookmarksPanel extends StatelessWidget {
  final TextEditingController searchController;
  final void Function(String value) onSearchChanged;
  final List<BookmarkNode> tree;
  final int linkCount;
  final Future<void> Function(BookmarkNode bookmark) onOpenBookmark;
  final Future<void> Function(BookmarkNode bookmark) onOpenBookmarkInNewTab;
  final Future<void> Function(BookmarkNode bookmark, bool pinned) onSetPinned;
  final Future<void> Function(String? parentFolderId) onCreateFolder;
  final Future<void> Function(BookmarkNode node) onRenameNode;
  final Future<void> Function(BookmarkNode node) onDeleteNode;
  final Future<void> Function(BookmarkNode node) onMoveNode;
  final Future<void> Function() onImportJson;
  final Future<void> Function() onImportHtml;
  final Future<void> Function() onExportJson;
  final Future<void> Function() onExportHtml;
  final Future<void> Function() onClearAll;

  const BookmarksPanel({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.tree,
    required this.linkCount,
    required this.onOpenBookmark,
    required this.onOpenBookmarkInNewTab,
    required this.onSetPinned,
    required this.onCreateFolder,
    required this.onRenameNode,
    required this.onDeleteNode,
    required this.onMoveNode,
    required this.onImportJson,
    required this.onImportHtml,
    required this.onExportJson,
    required this.onExportHtml,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final query = searchController.text.trim().toLowerCase();
    final searchHits = _searchLinks(query);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search bookmarks',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                onPressed: () => onCreateFolder(null),
                icon: const Icon(Icons.create_new_folder_outlined, size: 16),
                label: const Text('New Folder'),
              ),
              OutlinedButton.icon(
                onPressed: onImportJson,
                icon: const Icon(Icons.upload_file_outlined, size: 16),
                label: const Text('Import JSON'),
              ),
              OutlinedButton.icon(
                onPressed: onImportHtml,
                icon: const Icon(Icons.upload_file, size: 16),
                label: const Text('Import HTML'),
              ),
              OutlinedButton.icon(
                onPressed: onExportJson,
                icon: const Icon(Icons.download_outlined, size: 16),
                label: const Text('Export JSON'),
              ),
              OutlinedButton.icon(
                onPressed: onExportHtml,
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Export HTML'),
              ),
              OutlinedButton.icon(
                onPressed: onClearAll,
                icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                label: const Text('Clear All'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Links: $linkCount',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
        ),
        Expanded(
          child: tree.isEmpty
              ? Center(
                  child: Text(
                    'No bookmarks yet',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              : (query.isNotEmpty
                  ? _buildSearchResults(searchHits)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                      itemCount: tree.length,
                      itemBuilder: (context, index) {
                        final node = tree[index];
                        return _BookmarkNodeTile(
                          node: node,
                          depth: 0,
                          onOpenBookmark: onOpenBookmark,
                          onOpenBookmarkInNewTab: onOpenBookmarkInNewTab,
                          onSetPinned: onSetPinned,
                          onCreateFolder: onCreateFolder,
                          onRenameNode: onRenameNode,
                          onDeleteNode: onDeleteNode,
                          onMoveNode: onMoveNode,
                        );
                      },
                    )),
        ),
      ],
    );
  }

  Widget _buildSearchResults(List<_SearchHit> hits) {
    if (hits.isEmpty) {
      return Center(
        child: Text('No matching bookmarks',
            style: TextStyle(color: Colors.grey[600])),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      itemCount: hits.length,
      itemBuilder: (context, index) {
        final hit = hits[index];
        final node = hit.node;
        return Card(
          child: _MiddleClickListener(
            onMiddleClick: () => onOpenBookmarkInNewTab(node),
            child: ListTile(
              dense: true,
              leading: Icon(
                node.pinned ? Icons.push_pin : Icons.bookmark_outline,
                size: 18,
              ),
              title: Text(
                node.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${hit.path}  •  ${node.url ?? ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => onOpenBookmark(node),
              trailing: PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'open') {
                    await onOpenBookmark(node);
                    return;
                  }
                  if (value == 'open_new_tab') {
                    await onOpenBookmarkInNewTab(node);
                    return;
                  }
                  if (value == 'pin') {
                    await onSetPinned(node, !node.pinned);
                    return;
                  }
                  if (value == 'rename') {
                    await onRenameNode(node);
                    return;
                  }
                  if (value == 'move') {
                    await onMoveNode(node);
                    return;
                  }
                  if (value == 'delete') {
                    await onDeleteNode(node);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'open', child: Text('Open')),
                  const PopupMenuItem(
                    value: 'open_new_tab',
                    child: Text('Open in new tab'),
                  ),
                  PopupMenuItem(
                    value: 'pin',
                    child: Text(node.pinned ? 'Unpin' : 'Pin'),
                  ),
                  const PopupMenuItem(value: 'rename', child: Text('Rename')),
                  const PopupMenuItem(value: 'move', child: Text('Move...')),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<_SearchHit> _searchLinks(String query) {
    final out = <_SearchHit>[];

    void walk(List<BookmarkNode> nodes, List<String> path) {
      for (final node in nodes) {
        if (node.isFolder) {
          walk(node.children, [...path, node.displayTitle]);
          continue;
        }
        if (query.isEmpty) {
          out.add(_SearchHit(node: node, path: path.join(' / ')));
          continue;
        }
        final title = node.displayTitle.toLowerCase();
        final url = (node.url ?? '').toLowerCase();
        final joinedPath = path.join(' / ').toLowerCase();
        if (title.contains(query) ||
            url.contains(query) ||
            joinedPath.contains(query)) {
          out.add(_SearchHit(node: node, path: path.join(' / ')));
        }
      }
    }

    walk(tree, const <String>[]);
    return out;
  }
}

class _BookmarkNodeTile extends StatelessWidget {
  final BookmarkNode node;
  final int depth;
  final Future<void> Function(BookmarkNode bookmark) onOpenBookmark;
  final Future<void> Function(BookmarkNode bookmark) onOpenBookmarkInNewTab;
  final Future<void> Function(BookmarkNode bookmark, bool pinned) onSetPinned;
  final Future<void> Function(String? parentFolderId) onCreateFolder;
  final Future<void> Function(BookmarkNode node) onRenameNode;
  final Future<void> Function(BookmarkNode node) onDeleteNode;
  final Future<void> Function(BookmarkNode node) onMoveNode;

  const _BookmarkNodeTile({
    required this.node,
    required this.depth,
    required this.onOpenBookmark,
    required this.onOpenBookmarkInNewTab,
    required this.onSetPinned,
    required this.onCreateFolder,
    required this.onRenameNode,
    required this.onDeleteNode,
    required this.onMoveNode,
  });

  @override
  Widget build(BuildContext context) {
    if (node.isFolder) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 3),
        child: ExpansionTile(
          key: PageStorageKey<String>('folder-${node.id}'),
          tilePadding: EdgeInsets.only(left: 8.0 + depth * 14.0, right: 8),
          leading: const Icon(Icons.folder_outlined, size: 18),
          title: Text(node.displayTitle),
          trailing: PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'new') {
                await onCreateFolder(node.id);
                return;
              }
              if (value == 'rename') {
                await onRenameNode(node);
                return;
              }
              if (value == 'move') {
                await onMoveNode(node);
                return;
              }
              if (value == 'delete') {
                await onDeleteNode(node);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'new', child: Text('New subfolder')),
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(value: 'move', child: Text('Move...')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
          children: node.children.isEmpty
              ? [
                  const Padding(
                    padding: EdgeInsets.only(left: 16, right: 16, bottom: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Empty', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ]
              : node.children
                  .map(
                    (child) => _BookmarkNodeTile(
                      node: child,
                      depth: depth + 1,
                      onOpenBookmark: onOpenBookmark,
                      onOpenBookmarkInNewTab: onOpenBookmarkInNewTab,
                      onSetPinned: onSetPinned,
                      onCreateFolder: onCreateFolder,
                      onRenameNode: onRenameNode,
                      onDeleteNode: onDeleteNode,
                      onMoveNode: onMoveNode,
                    ),
                  )
                  .toList(growable: false),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: _MiddleClickListener(
        onMiddleClick: () => onOpenBookmarkInNewTab(node),
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.only(left: 16.0 + depth * 14.0, right: 8),
          leading: Icon(
            node.pinned ? Icons.push_pin : Icons.bookmark_outline,
            size: 18,
          ),
          title: Text(
            node.displayTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            node.url ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => onOpenBookmark(node),
          trailing: PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'open') {
                await onOpenBookmark(node);
                return;
              }
              if (value == 'open_new_tab') {
                await onOpenBookmarkInNewTab(node);
                return;
              }
              if (value == 'pin') {
                await onSetPinned(node, !node.pinned);
                return;
              }
              if (value == 'rename') {
                await onRenameNode(node);
                return;
              }
              if (value == 'move') {
                await onMoveNode(node);
                return;
              }
              if (value == 'delete') {
                await onDeleteNode(node);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'open', child: Text('Open')),
              const PopupMenuItem(
                value: 'open_new_tab',
                child: Text('Open in new tab'),
              ),
              PopupMenuItem(
                value: 'pin',
                child: Text(node.pinned ? 'Unpin' : 'Pin'),
              ),
              const PopupMenuItem(value: 'rename', child: Text('Rename')),
              const PopupMenuItem(value: 'move', child: Text('Move...')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiddleClickListener extends StatelessWidget {
  final Widget child;
  final VoidCallback onMiddleClick;

  const _MiddleClickListener({
    required this.child,
    required this.onMiddleClick,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        if ((event.buttons & kMiddleMouseButton) == 0) return;
        onMiddleClick();
      },
      child: child,
    );
  }
}

class _SearchHit {
  final BookmarkNode node;
  final String path;

  const _SearchHit({required this.node, required this.path});
}
