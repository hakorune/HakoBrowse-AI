import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';

import '../bookmark.dart';
import '../bookmark_service.dart';
import '../content_sanitizer.dart';
import 'safety_gate.dart';
import 'structured_extractor.dart';

class ToolExecutorService {
  static Future<String> execute({
    required BuildContext context,
    required String toolName,
    required Map<String, dynamic> arguments,
    required WebviewController? activeController,
    required bool useHtmlContent,
    required int maxContentLength,
    required String currentUrl,
    required bool enableSafetyGate,
    required List<BookmarkNode> bookmarks,
    required BookmarkService bookmarkService,
    required Future<void> Function(List<BookmarkNode> updated)
        onBookmarksChanged,
    required void Function(String url) onNavigated,
    required Future<int> Function({String? initialUrl, bool activate})
        onCreateTab,
    required void Function(String message) log,
    required String Function(String value, {int max}) shorten,
  }) async {
    switch (toolName) {
      case 'get_page_content':
        if (activeController == null) {
          return jsonEncode({'error': 'No active browser tab'});
        }
        final selector = arguments['selector'] as String?;
        final contentScript = useHtmlContent ? 'innerHTML' : 'innerText';
        final script = selector != null
            ? 'document.querySelector("$selector")?.$contentScript || ""'
            : 'document.body.$contentScript';
        try {
          var result = await activeController.executeScript(script) ?? '';
          final title =
              await activeController.executeScript('document.title') ?? '';
          final sanitizeResult =
              sanitizeUntrustedContent(result, sampleLimit: 2);
          result = sanitizeResult.content;
          final removedLines = sanitizeResult.removedLines;
          if (removedLines > 0) {
            final preview = sanitizeResult.removedSamples.join(' | ');
            log(
              preview.isEmpty
                  ? 'Sanitized page content: removed $removedLines suspicious lines'
                  : 'Sanitized page content: removed $removedLines suspicious lines. Preview: $preview',
            );
          }
          final truncated = result.length > maxContentLength;
          if (truncated) {
            result = result.substring(0, maxContentLength);
            log(
              'Content truncated: ${result.length} chars (original: full content too large)',
            );
          } else {
            log(
              'Page content (${useHtmlContent ? "HTML" : "text"}): ${result.length} chars',
            );
          }
          return jsonEncode({
            'title': title,
            'url': currentUrl,
            'content': result,
            'format': useHtmlContent ? 'html' : 'text',
            'truncated': truncated,
            'sanitized': removedLines > 0,
            'removed_lines': removedLines,
          });
        } catch (e) {
          return jsonEncode({'error': 'Failed to get page content: $e'});
        }

      case 'navigate_to':
        if (activeController == null) {
          return jsonEncode({'error': 'No active browser tab'});
        }
        final url = arguments['url'] as String;
        if (SafetyGate.isRiskyNavigate(url)) {
          final approved = await SafetyGate.confirm(
            context: context,
            enabled: enableSafetyGate,
            title: 'Safety Gate: navigate_to',
            summary: 'Risky navigation detected.\n$url',
          );
          if (!approved) {
            return jsonEncode({'error': 'Blocked by safety gate'});
          }
        }
        try {
          await activeController.loadUrl(url);
          onNavigated(url);
          return jsonEncode({'success': true, 'url': url});
        } catch (e) {
          return jsonEncode({'error': 'Failed to navigate: $e'});
        }

      case 'get_current_url':
        return jsonEncode({'url': currentUrl});

      case 'open_new_tab':
        {
          final rawUrl = (arguments['url'] as String?)?.trim();
          final activate = arguments['activate'] != false;
          final targetUrl = (rawUrl == null || rawUrl.isEmpty)
              ? 'https://www.google.com'
              : rawUrl;

          if (SafetyGate.isRiskyNavigate(targetUrl)) {
            final approved = await SafetyGate.confirm(
              context: context,
              enabled: enableSafetyGate,
              title: 'Safety Gate: open_new_tab',
              summary: 'Risky navigation detected in new tab.\n$targetUrl',
            );
            if (!approved) {
              return jsonEncode({'error': 'Blocked by safety gate'});
            }
          }

          try {
            final index = await onCreateTab(
              initialUrl: targetUrl,
              activate: activate,
            );
            if (activate) {
              onNavigated(targetUrl);
            }
            return jsonEncode({
              'success': true,
              'tab_index': index,
              'url': targetUrl,
              'activated': activate,
            });
          } catch (e) {
            return jsonEncode({'error': 'Failed to open new tab: $e'});
          }
        }

      case 'execute_script':
        if (activeController == null) {
          return jsonEncode({'error': 'No active browser tab'});
        }
        final script = arguments['script'] as String;
        if (SafetyGate.isRiskyScript(script)) {
          final approved = await SafetyGate.confirm(
            context: context,
            enabled: enableSafetyGate,
            title: 'Safety Gate: execute_script',
            summary:
                'Potentially risky JavaScript detected.\n${shorten(script, max: 600)}',
          );
          if (!approved) {
            return jsonEncode({'error': 'Blocked by safety gate'});
          }
        }
        try {
          final result = await activeController.executeScript(script);
          return jsonEncode({'result': result ?? ''});
        } catch (e) {
          return jsonEncode({'error': 'Script execution failed: $e'});
        }

      case 'extract_structured':
        if (activeController == null) {
          return jsonEncode({'error': 'No active browser tab'});
        }
        final selector = (arguments['selector'] as String?)?.trim();
        final schema = arguments['schema'];
        if (schema is! Map) {
          return jsonEncode({'error': 'schema must be an object'});
        }
        try {
          final script = StructuredExtractor.buildScript(
            selector: selector ?? '',
            schema: schema.cast<String, dynamic>(),
          );
          final raw = await activeController.executeScript(script) ?? '';
          dynamic decoded;
          try {
            decoded = jsonDecode(raw);
          } catch (_) {
            decoded = {
              'data': {'raw': raw}
            };
          }
          final sanitized =
              StructuredExtractor.sanitizeStructuredValue(decoded);
          return jsonEncode({
            'url': currentUrl,
            'selector': selector ?? '',
            'result': sanitized,
          });
        } catch (e) {
          return jsonEncode({'error': 'extract_structured failed: $e'});
        }

      case 'add_bookmark':
        final url = (arguments['url'] as String?)?.trim();
        final title = (arguments['title'] as String?)?.trim() ?? '';
        final folder = (arguments['folder'] as String?)?.trim() ?? '';
        final strategyRaw =
            (arguments['duplicate_strategy'] as String?)?.toLowerCase();
        final strategy = strategyRaw == 'keep_both'
            ? DuplicateStrategy.keepBoth
            : DuplicateStrategy.overwrite;
        final targetUrl = (url == null || url.isEmpty) ? currentUrl : url;
        if (targetUrl.isEmpty) {
          return jsonEncode({'error': 'No URL available to bookmark'});
        }
        try {
          final finalTitle = title.isNotEmpty ? title : targetUrl;
          final next = await bookmarkService.addBookmark(
            title: finalTitle,
            url: targetUrl,
            folderName: folder,
            duplicateStrategy: strategy,
          );
          await onBookmarksChanged(next);
          return jsonEncode({
            'success': true,
            'url': targetUrl,
            'title': finalTitle,
            'folder': folder,
            'count': bookmarkService.countLinks(next),
          });
        } catch (e) {
          return jsonEncode({'error': 'Failed to add bookmark: $e'});
        }

      case 'list_bookmarks':
        final query =
            (arguments['query'] as String?)?.toLowerCase().trim() ?? '';
        final folder = (arguments['folder'] as String?)?.toLowerCase().trim();
        final links = _flattenLinksWithPath(bookmarks);
        final filtered = links.where((entry) {
          final title = entry.node.displayTitle.toLowerCase();
          final url = (entry.node.url ?? '').toLowerCase();
          final path = entry.path.toLowerCase();
          if (folder != null && folder.isNotEmpty && !path.contains(folder)) {
            return false;
          }
          if (query.isEmpty) return true;
          return title.contains(query) ||
              url.contains(query) ||
              path.contains(query);
        }).toList(growable: false);

        return jsonEncode({
          'count': filtered.length,
          'bookmarks': filtered
              .map((entry) => {
                    'id': entry.node.id,
                    'title': entry.node.displayTitle,
                    'url': entry.node.url,
                    'path': entry.path,
                    'pinned': entry.node.pinned,
                    'createdAt': entry.node.createdAt.toIso8601String(),
                  })
              .toList(),
        });

      case 'open_bookmark':
        final id = (arguments['id'] as String?)?.trim();
        final url = (arguments['url'] as String?)?.trim();
        final query = (arguments['query'] as String?)?.toLowerCase().trim();
        final links = bookmarkService.flattenLinks(bookmarks);

        BookmarkNode? target;
        if (id != null && id.isNotEmpty) {
          for (final b in links) {
            if (b.id == id) {
              target = b;
              break;
            }
          }
        } else if (url != null && url.isNotEmpty) {
          for (final b in links) {
            if ((b.url ?? '').trim() == url) {
              target = b;
              break;
            }
          }
        } else if (query != null && query.isNotEmpty) {
          for (final b in links) {
            final titleLower = b.displayTitle.toLowerCase();
            final urlLower = (b.url ?? '').toLowerCase();
            if (titleLower.contains(query) || urlLower.contains(query)) {
              target = b;
              break;
            }
          }
        }
        if (target == null) {
          return jsonEncode({'error': 'Bookmark not found'});
        }
        if (activeController == null) {
          return jsonEncode({'error': 'No active browser tab'});
        }
        try {
          await activeController.loadUrl(target.url ?? '');
          return jsonEncode({
            'success': true,
            'id': target.id,
            'title': target.displayTitle,
            'url': target.url,
          });
        } catch (e) {
          return jsonEncode({'error': 'Failed to open bookmark: $e'});
        }

      default:
        return jsonEncode({'error': 'Unknown tool: $toolName'});
    }
  }

  static List<_BookmarkLinkEntry> _flattenLinksWithPath(
      List<BookmarkNode> nodes) {
    final out = <_BookmarkLinkEntry>[];

    void walk(List<BookmarkNode> items, List<String> path) {
      for (final node in items) {
        if (node.isFolder) {
          walk(node.children, [...path, node.displayTitle]);
          continue;
        }
        out.add(_BookmarkLinkEntry(node: node, path: path.join(' / ')));
      }
    }

    walk(nodes, const <String>[]);
    return out;
  }
}

class _BookmarkLinkEntry {
  final BookmarkNode node;
  final String path;

  const _BookmarkLinkEntry({required this.node, required this.path});
}
