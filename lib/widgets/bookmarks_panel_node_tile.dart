part of 'bookmarks_panel.dart';

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
