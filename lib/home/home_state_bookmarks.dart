// ignore_for_file: invalid_use_of_protected_member

part of '../main.dart';

extension _HomeStateBookmarksExt on _HomePageState {
  Future<void> _addCurrentBookmark() async {
    try {
      final controller = _activeController;
      if (controller == null) return;
      final rawTitle = await controller.executeScript('document.title') ?? '';
      final title = rawTitle.toString().trim();
      final next = await _bookmarkService.addBookmark(
        title: title,
        url: _currentUrl,
        duplicateStrategy: DuplicateStrategy.overwrite,
      );
      if (!mounted) return;
      setState(() {
        _bookmarks = next;
      });
      _log('Bookmarked: $_currentUrl');
    } catch (e) {
      _log('Bookmark add failed: $e');
    }
  }

  Future<void> _toggleCurrentBookmark() async {
    if (_bookmarkService.isBookmarked(_bookmarks, _currentUrl)) {
      final next = await _bookmarkService.removeFirstByUrl(_currentUrl);
      if (!mounted) return;
      setState(() {
        _bookmarks = next;
      });
      _log('Bookmark removed by URL: $_currentUrl');
      return;
    }
    await _addCurrentBookmark();
  }

  Future<void> _setBookmarkPinned(BookmarkNode bookmark, bool pinned) async {
    if (!bookmark.isLink) return;
    final bookmarks = await _bookmarkService.updatePinned(
      id: bookmark.id,
      pinned: pinned,
    );
    if (!mounted) return;
    setState(() {
      _bookmarks = bookmarks;
    });
  }

  Future<void> _createFolder({String? parentFolderId}) async {
    final name = await _askTextInput(
      title: 'New folder',
      label: 'Folder name',
    );
    if (name == null || name.trim().isEmpty) return;
    final next = await _bookmarkService.addFolder(
      name: name.trim(),
      parentFolderId: parentFolderId,
    );
    if (!mounted) return;
    setState(() {
      _bookmarks = next;
    });
    _log('Folder created: ${name.trim()}');
  }

  Future<void> _renameBookmarkNode(BookmarkNode node) async {
    final title = await _askTextInput(
      title: 'Rename',
      label: node.isFolder ? 'Folder name' : 'Bookmark title',
      initial: node.displayTitle,
    );
    if (title == null || title.trim().isEmpty) return;
    final next = await _bookmarkService.renameNode(
      id: node.id,
      title: title.trim(),
    );
    if (!mounted) return;
    setState(() {
      _bookmarks = next;
    });
    _log('Renamed node: ${node.displayTitle} -> ${title.trim()}');
  }

  Future<void> _deleteBookmarkNode(BookmarkNode node) async {
    final ok = await _confirmDeleteNode(node);
    if (!ok) return;
    final next = await _bookmarkService.removeBookmarkById(node.id);
    if (!mounted) return;
    setState(() {
      _bookmarks = next;
    });
    _log('Deleted node: ${node.displayTitle}');
  }

  Future<void> _moveBookmarkNode(BookmarkNode node) async {
    final targetId = await _pickFolderTarget(node);
    if (targetId == '__cancel__') return;
    final next = await _bookmarkService.moveNode(
      id: node.id,
      parentFolderId: targetId == '__root__' ? null : targetId,
    );
    if (!mounted) return;
    setState(() {
      _bookmarks = next;
    });
    _log('Moved node: ${node.displayTitle}');
  }

  Future<void> _openBookmarkFromTree(BookmarkNode node) async {
    if (!node.isLink) return;
    final targetUrl = (node.url ?? '').trim();
    if (targetUrl.isEmpty) return;
    final controller = _activeController;
    if (controller == null) return;
    await controller.loadUrl(targetUrl);
  }

  Future<void> _openBookmarkInNewTabFromTree(BookmarkNode node) async {
    if (!node.isLink) return;
    final targetUrl = (node.url ?? '').trim();
    if (targetUrl.isEmpty) return;
    await _createTab(initialUrl: targetUrl, activate: true);
  }

  Future<void> _clearAllBookmarks() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all bookmarks'),
        content: const Text(
          'Delete all bookmarks and folders? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final next = await _bookmarkService.clearAll();
    if (!mounted) return;
    setState(() {
      _bookmarks = next;
    });
    _log('Cleared all bookmarks');
  }

  Future<String?> _askTextInput({
    required String title,
    required String label,
    String initial = '',
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<bool> _confirmDeleteNode(BookmarkNode node) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete bookmark node'),
        content: Text(
          node.isFolder
              ? 'Delete folder "${node.displayTitle}" and all children?'
              : 'Delete bookmark "${node.displayTitle}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<String?> _pickFolderTarget(BookmarkNode node) async {
    final folders = _bookmarkService.flattenFolders(_bookmarks);
    final banned = <String>{node.id};
    if (node.isFolder) {
      void collect(List<BookmarkNode> items) {
        for (final item in items) {
          if (!item.isFolder) continue;
          banned.add(item.id);
          collect(item.children);
        }
      }

      collect(node.children);
    }

    final options = <(String id, String name)>[("__root__", '(Root)')];
    for (final folder in folders) {
      if (banned.contains(folder.id)) continue;
      options.add((folder.id, folder.displayTitle));
    }

    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to folder'),
        content: SizedBox(
          width: 420,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: options.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final option = options[index];
              return ListTile(
                dense: true,
                title: Text(option.$2),
                onTap: () => Navigator.pop(context, option.$1),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, '__cancel__'),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    return selected;
  }
}
