// ignore_for_file: invalid_use_of_protected_member

part of '../main.dart';

extension _HomeStateBookmarksIoExt on _HomePageState {
  Future<void> _importBookmarksJson() async {
    try {
      const jsonGroup = XTypeGroup(label: 'JSON', extensions: <String>['json']);
      final file = await openFile(acceptedTypeGroups: <XTypeGroup>[jsonGroup]);
      if (file == null) return;
      final raw = await file.readAsString();
      final next = await _bookmarkService.importJsonText(raw);
      if (!mounted) return;
      setState(() {
        _bookmarks = next;
      });
      _log(
          'Imported bookmarks JSON: ${_bookmarkService.countLinks(next)} links');
    } catch (e) {
      _log('Import JSON failed: $e');
    }
  }

  Future<void> _importBookmarksHtml() async {
    try {
      const htmlGroup = XTypeGroup(
        label: 'Bookmarks HTML',
        extensions: <String>['html', 'htm'],
      );
      final file = await openFile(acceptedTypeGroups: <XTypeGroup>[htmlGroup]);
      if (file == null) return;
      final raw = await file.readAsString();
      final next = await _bookmarkService.importHtmlText(raw);
      if (!mounted) return;
      setState(() {
        _bookmarks = next;
      });
      _log(
          'Imported bookmarks HTML: ${_bookmarkService.countLinks(next)} links');
    } catch (e) {
      _log('Import HTML failed: $e');
    }
  }

  Future<void> _exportBookmarksJson() async {
    try {
      const group = XTypeGroup(label: 'JSON', extensions: <String>['json']);
      final location = await getSaveLocation(
        suggestedName: 'bookmarks_export.json',
        acceptedTypeGroups: <XTypeGroup>[group],
      );
      if (location == null) return;
      final file = File(location.path);
      final text = _bookmarkService.exportJsonText(_bookmarks);
      await file.writeAsString(text);
      _log('Exported bookmarks JSON: ${file.path}');
    } catch (e) {
      _log('Export JSON failed: $e');
    }
  }

  Future<void> _exportBookmarksHtml() async {
    try {
      const group = XTypeGroup(
        label: 'Bookmarks HTML',
        extensions: <String>['html', 'htm'],
      );
      final location = await getSaveLocation(
        suggestedName: 'bookmarks_export.html',
        acceptedTypeGroups: <XTypeGroup>[group],
      );
      if (location == null) return;
      final file = File(location.path);
      final text = _bookmarkService.exportHtmlText(_bookmarks);
      await file.writeAsString(text);
      _log('Exported bookmarks HTML: ${file.path}');
    } catch (e) {
      _log('Export HTML failed: $e');
    }
  }
}
