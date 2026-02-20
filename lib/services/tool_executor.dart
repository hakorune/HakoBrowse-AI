import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_windows/webview_windows.dart';

import '../bookmark.dart';
import '../bookmark_service.dart';
import '../content_sanitizer.dart';
import '../models/skill_definition.dart';
import '../models/tool_auth_profile.dart';
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
    required List<SkillDefinition> skills,
    required List<ToolAuthProfile> authProfiles,
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
      case 'load_skill_index':
        {
          final enabledSkills =
              skills.where((s) => s.enabled).toList(growable: false);
          final source = enabledSkills.isNotEmpty ? enabledSkills : skills;
          if (source.isEmpty) {
            return jsonEncode({'error': 'No skills available'});
          }

          final skillId = (arguments['skill_id'] as String?)?.trim();
          final skillName = (arguments['skill_name'] as String?)?.trim();
          final query = (arguments['query'] as String?)?.trim();
          final maxHeadings =
              ((arguments['max_headings'] as num?)?.toInt() ?? 60)
                  .clamp(10, 200);
          final hasSelector = (skillId?.isNotEmpty ?? false) ||
              (skillName?.isNotEmpty ?? false) ||
              (query?.isNotEmpty ?? false);

          final skill = _findSkill(
            source,
            skillId: skillId,
            skillName: skillName,
            query: query,
          );

          if (skill == null) {
            if (!hasSelector) {
              return jsonEncode({
                'success': true,
                'skills': source
                    .map((s) => {
                          'id': s.id,
                          'name': s.name,
                          'description': s.description,
                          'enabled': s.enabled,
                        })
                    .toList(growable: false),
                'hint':
                    'Specify skill_id or skill_name, then call load_skill_index again.',
              });
            }
            return jsonEncode({
              'error': 'Skill not found',
              'available_skills': source
                  .map((s) => {
                        'id': s.id,
                        'name': s.name,
                        'enabled': s.enabled,
                      })
                  .toList(growable: false),
            });
          }

          final headings =
              _extractHeadings(skill.body, maxHeadings: maxHeadings);
          return jsonEncode({
            'success': true,
            'skill': {
              'id': skill.id,
              'name': skill.name,
              'description': skill.description,
              'allowed_tools': skill.allowedTools,
              'enabled': skill.enabled,
              'path': skill.path,
            },
            'index': {
              'body_chars': skill.body.length,
              'body_lines': _countLines(skill.body),
              'heading_count': headings.length,
              'headings': headings,
            },
            'hint':
                'Then call load_skill with skill_id and section/query, or use start_line/end_line for precise range reads.',
          });
        }

      case 'load_skill':
        {
          final enabledSkills =
              skills.where((s) => s.enabled).toList(growable: false);
          final source = enabledSkills.isNotEmpty ? enabledSkills : skills;
          if (source.isEmpty) {
            return jsonEncode({'error': 'No skills available'});
          }

          final skillId = (arguments['skill_id'] as String?)?.trim();
          final skillName = (arguments['skill_name'] as String?)?.trim();
          final query = (arguments['query'] as String?)?.trim();
          final section = (arguments['section'] as String?)?.trim();
          final startLine = (arguments['start_line'] as num?)?.toInt();
          final endLine = (arguments['end_line'] as num?)?.toInt();
          final maxChars = ((arguments['max_chars'] as num?)?.toInt() ?? 3500)
              .clamp(800, 8000);

          final skill = _findSkill(
            source,
            skillId: skillId,
            skillName: skillName,
            query: query,
          );
          if (skill == null) {
            return jsonEncode({
              'error': 'Skill not found',
              'available_skills': source
                  .map((s) => {
                        'id': s.id,
                        'name': s.name,
                        'enabled': s.enabled,
                      })
                  .toList(growable: false),
            });
          }

          final snippet = _extractSkillSnippet(
            skill: skill,
            section: section,
            query: query,
            startLine: startLine,
            endLine: endLine,
            maxChars: maxChars,
          );
          final body = snippet.content;
          final truncated = snippet.truncated;

          return jsonEncode({
            'success': true,
            'skill': {
              'id': skill.id,
              'name': skill.name,
              'description': skill.description,
              'allowed_tools': skill.allowedTools,
              'enabled': skill.enabled,
              'path': skill.path,
            },
            'selection': {
              'mode': snippet.mode,
              'section': section ?? '',
              'query': query ?? '',
              'start_line': snippet.startLine,
              'end_line': snippet.endLine,
              'total_lines': snippet.totalLines,
              'max_chars': maxChars,
            },
            'content': body,
            'truncated': truncated,
            'hint':
                'Need another part? Call load_skill again with section/query or start_line/end_line.',
          });
        }

      case 'load_skill_file':
        {
          final enabledSkills =
              skills.where((s) => s.enabled).toList(growable: false);
          final source = enabledSkills.isNotEmpty ? enabledSkills : skills;
          if (source.isEmpty) {
            return jsonEncode({'error': 'No skills available'});
          }

          final skillId = (arguments['skill_id'] as String?)?.trim();
          final skillName = (arguments['skill_name'] as String?)?.trim();
          final skillQuery = (arguments['query'] as String?)?.trim();
          final section = (arguments['section'] as String?)?.trim();
          final maxChars = ((arguments['max_chars'] as num?)?.toInt() ?? 3500)
              .clamp(800, 12000);
          final filePath =
              ((arguments['file_path'] ?? arguments['path']) as String?)
                      ?.trim() ??
                  '';

          final skill = _findSkill(
            source,
            skillId: skillId,
            skillName: skillName,
            query: skillQuery,
          );
          if (skill == null) {
            return jsonEncode({
              'error': 'Skill not found',
              'available_skills': source
                  .map((s) => {
                        'id': s.id,
                        'name': s.name,
                        'enabled': s.enabled,
                      })
                  .toList(growable: false),
            });
          }

          final skillDir = File(skill.path).parent;
          final files = await _listSkillFiles(skillDir);
          if (filePath.isEmpty) {
            return jsonEncode({
              'success': true,
              'skill': {
                'id': skill.id,
                'name': skill.name,
                'description': skill.description,
                'allowed_tools': skill.allowedTools,
                'enabled': skill.enabled,
                'path': skill.path,
              },
              'files': files,
              'hint':
                  'Set file_path (ex: HEARTBEAT.md or references/api.md), then call load_skill_file again.',
            });
          }

          final resolved = _resolveSkillFile(
            skillDir: skillDir,
            requestedPath: filePath,
          );
          if (resolved.$1 != null) {
            return jsonEncode({
              'error': resolved.$1,
              'available_files': files,
            });
          }

          final file = resolved.$2!;
          if (!await file.exists()) {
            return jsonEncode({
              'error': 'File not found: $filePath',
              'available_files': files,
            });
          }

          final raw = await file.readAsString();
          var selected = raw;
          if (section != null && section.trim().isNotEmpty) {
            final bySection =
                _extractSectionByHeading(raw, section.trim().toLowerCase());
            if (bySection.trim().isNotEmpty) {
              selected = bySection.trim();
            }
          }

          final truncated = selected.length > maxChars;
          final content =
              truncated ? '${selected.substring(0, maxChars)}\n...' : selected;
          final headings = _extractHeadings(raw, maxHeadings: 80);

          return jsonEncode({
            'success': true,
            'skill': {
              'id': skill.id,
              'name': skill.name,
              'description': skill.description,
              'allowed_tools': skill.allowedTools,
              'enabled': skill.enabled,
              'path': skill.path,
            },
            'file': {
              'requested': filePath,
              'resolved': resolved.$3,
              'chars': raw.length,
              'lines': _countLines(raw),
              'heading_count': headings.length,
              'headings': headings,
            },
            'selection': {
              'section': section ?? '',
              'max_chars': maxChars,
            },
            'content': content,
            'truncated': truncated,
            'hint': 'Need another file? Call load_skill_file with file_path.',
          });
        }

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

      case 'http_request':
        {
          final rawUrl = (arguments['url'] as String?)?.trim() ?? '';
          if (rawUrl.isEmpty) {
            return jsonEncode({'error': 'url is required'});
          }
          final uri = Uri.tryParse(rawUrl);
          if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
            return jsonEncode(
                {'error': 'url must start with http:// or https://'});
          }

          final rawBody = arguments['body'];
          final methodInput = (arguments['method'] as String?)?.trim();
          final method = ((methodInput == null || methodInput.isEmpty)
                  ? (rawBody == null ? 'GET' : 'POST')
                  : methodInput)
              .toUpperCase();
          const supportedMethods = <String>{
            'GET',
            'POST',
            'PUT',
            'PATCH',
            'DELETE',
            'HEAD',
          };
          if (!supportedMethods.contains(method)) {
            return jsonEncode({
              'error':
                  'Unsupported method: $method (supported: ${supportedMethods.join(", ")})'
            });
          }

          final headers = <String, String>{};
          final rawHeaders = arguments['headers'];
          if (rawHeaders is Map) {
            rawHeaders.forEach((key, value) {
              final k = key.toString().trim();
              if (k.isEmpty || value == null) return;
              headers[k] = value.toString();
            });
          }
          final authProfileId = ((arguments['auth_profile'] ??
                  arguments['authProfile']) as String?)
              ?.trim();
          ToolAuthProfile? authProfile;
          if (authProfileId != null && authProfileId.isNotEmpty) {
            authProfile = _findAuthProfile(authProfiles, authProfileId);
            if (authProfile == null) {
              return jsonEncode({
                'error': 'auth_profile not found: $authProfileId',
                'available_auth_profiles': authProfiles
                    .map((p) => {'id': p.id, 'name': p.name})
                    .toList(growable: false),
              });
            }
            if (authProfile.allowedHosts.isNotEmpty &&
                !_isHostAllowed(uri.host, authProfile.allowedHosts)) {
              return jsonEncode({
                'error':
                    'Host "${uri.host}" is not allowed for auth_profile "${authProfile.id}"',
                'allowed_hosts': authProfile.allowedHosts,
              });
            }

            final headerName = authProfile.headerName.trim().isEmpty
                ? 'Authorization'
                : authProfile.headerName.trim();
            if (!_headerExistsIgnoreCase(headers, headerName)) {
              final prefix = authProfile.valuePrefix.trim();
              final headerValue = prefix.isEmpty
                  ? authProfile.apiKey
                  : '$prefix ${authProfile.apiKey}';
              headers[headerName] = headerValue;
            }
          }

          String? body;
          if (rawBody != null) {
            if (rawBody is String) {
              body = rawBody;
              final trimmed = rawBody.trim();
              final looksLikeJson =
                  (trimmed.startsWith('{') && trimmed.endsWith('}')) ||
                      (trimmed.startsWith('[') && trimmed.endsWith(']'));
              if (looksLikeJson &&
                  !_headerExistsIgnoreCase(headers, 'content-type')) {
                try {
                  jsonDecode(trimmed);
                  headers['content-type'] = 'application/json';
                } catch (_) {
                  // keep as plain string body
                }
              }
            } else {
              body = jsonEncode(rawBody);
              headers.putIfAbsent('content-type', () => 'application/json');
            }
          }

          final timeoutSeconds =
              ((arguments['timeout_seconds'] as num?)?.toInt() ?? 20)
                  .clamp(1, 60);
          final maxResponseBytes =
              ((arguments['max_response_bytes'] as num?)?.toInt() ?? 200000)
                  .clamp(1024, 1000000);
          final followRedirects = arguments['follow_redirects'] != false;

          if (SafetyGate.isRiskyHttpRequest(
            method: method,
            url: rawUrl,
            headers: headers,
            body: body,
          )) {
            final headerNames = headers.keys.join(', ');
            final approved = await SafetyGate.confirm(
              context: context,
              enabled: enableSafetyGate,
              title: 'Safety Gate: http_request',
              summary: [
                'Potentially risky HTTP request detected.',
                '$method $rawUrl',
                if (headerNames.isNotEmpty) 'headers: $headerNames',
                if ((body ?? '').trim().isNotEmpty)
                  'body: ${shorten(body ?? '', max: 400)}',
              ].join('\n'),
            );
            if (!approved) {
              return jsonEncode({'error': 'Blocked by safety gate'});
            }
          }

          final request = http.Request(method, uri);
          request.followRedirects = followRedirects;
          request.headers.addAll(headers);
          if (body != null) {
            request.body = body;
          }

          final client = http.Client();
          try {
            final response = await client
                .send(request)
                .timeout(Duration(seconds: timeoutSeconds));

            final collected = <int>[];
            var readBytes = 0;
            var truncated = false;
            await for (final chunk in response.stream) {
              if (readBytes >= maxResponseBytes) {
                truncated = true;
                break;
              }
              final remaining = maxResponseBytes - readBytes;
              if (chunk.length <= remaining) {
                collected.addAll(chunk);
                readBytes += chunk.length;
              } else {
                collected.addAll(chunk.sublist(0, remaining));
                readBytes += remaining;
                truncated = true;
                break;
              }
            }

            final responseText = utf8.decode(collected, allowMalformed: true);
            return jsonEncode({
              'success':
                  response.statusCode >= 200 && response.statusCode < 300,
              'status': response.statusCode,
              'reason': response.reasonPhrase ?? '',
              'url': rawUrl,
              'method': method,
              if (authProfile != null)
                'auth_profile': {
                  'id': authProfile.id,
                  'name': authProfile.name,
                },
              'request_headers': _redactHeaders(headers),
              'response_headers': response.headers,
              'body': responseText,
              'bytes': readBytes,
              'truncated': truncated,
            });
          } on TimeoutException {
            return jsonEncode({'error': 'HTTP request timed out'});
          } catch (e) {
            return jsonEncode({'error': 'HTTP request failed: $e'});
          } finally {
            client.close();
          }
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

  static Future<List<String>> _listSkillFiles(
    Directory skillDir, {
    int maxFiles = 120,
  }) async {
    final out = <String>[];
    final rootPath = skillDir.absolute.path;
    final rootNorm = rootPath.replaceAll('\\', '/');

    await for (final entity in skillDir.list(recursive: true)) {
      if (entity is! File) continue;
      final normalized = entity.absolute.path.replaceAll('\\', '/');
      if (!normalized.startsWith(rootNorm)) continue;
      var relative = normalized.substring(rootNorm.length);
      if (relative.startsWith('/')) {
        relative = relative.substring(1);
      }
      if (relative.isEmpty) continue;
      out.add(relative);
      if (out.length >= maxFiles) break;
    }

    out.sort((a, b) => a.compareTo(b));
    return out;
  }

  static (String?, File?, String?) _resolveSkillFile({
    required Directory skillDir,
    required String requestedPath,
  }) {
    final normalized = requestedPath.replaceAll('\\', '/').trim();
    if (normalized.isEmpty) {
      return ('file_path is required', null, null);
    }
    if (normalized.startsWith('/') ||
        normalized.startsWith('\\') ||
        RegExp(r'^[a-zA-Z]:').hasMatch(normalized)) {
      return (
        'file_path must be a relative path inside the skill folder',
        null,
        null
      );
    }
    final segments = normalized.split('/');
    if (segments.any((s) => s == '..')) {
      return ('file_path cannot contain ".."', null, null);
    }

    final rootPath = skillDir.absolute.path;
    final file = File('${skillDir.path}/$normalized');
    final targetPath = file.absolute.path;
    if (!_pathStartsWith(targetPath, rootPath)) {
      return ('file_path points outside the skill folder', null, null);
    }

    final relative = _relativePath(rootPath: rootPath, targetPath: targetPath);
    return (null, file, relative);
  }

  static bool _pathStartsWith(String targetPath, String rootPath) {
    final target = targetPath.replaceAll('\\', '/').toLowerCase();
    final root = rootPath.replaceAll('\\', '/').toLowerCase();
    if (target == root) return true;
    return target.startsWith('$root/');
  }

  static String _relativePath({
    required String rootPath,
    required String targetPath,
  }) {
    final root = rootPath.replaceAll('\\', '/');
    final target = targetPath.replaceAll('\\', '/');
    if (target == root) return '';
    if (target.startsWith('$root/')) {
      return target.substring(root.length + 1);
    }
    return target;
  }

  static ToolAuthProfile? _findAuthProfile(
    List<ToolAuthProfile> profiles,
    String key,
  ) {
    final normalized = key.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    for (final profile in profiles) {
      if (profile.id.toLowerCase() == normalized) return profile;
    }
    for (final profile in profiles) {
      if (profile.name.toLowerCase() == normalized) return profile;
    }
    for (final profile in profiles) {
      if (profile.name.toLowerCase().contains(normalized)) return profile;
    }
    return null;
  }

  static bool _headerExistsIgnoreCase(
    Map<String, String> headers,
    String key,
  ) {
    final lower = key.toLowerCase();
    for (final existing in headers.keys) {
      if (existing.toLowerCase() == lower) return true;
    }
    return false;
  }

  static bool _isHostAllowed(String host, List<String> allowedHosts) {
    final lowerHost = host.trim().toLowerCase();
    if (lowerHost.isEmpty) return false;
    for (final raw in allowedHosts) {
      final allowed = raw.trim().toLowerCase();
      if (allowed.isEmpty) continue;
      if (allowed.startsWith('*.')) {
        final suffix = allowed.substring(2);
        if (suffix.isEmpty) continue;
        if (lowerHost == suffix || lowerHost.endsWith('.$suffix')) {
          return true;
        }
        continue;
      }
      if (lowerHost == allowed) return true;
    }
    return false;
  }

  static Map<String, String> _redactHeaders(Map<String, String> headers) {
    const sensitive = <String>{
      'authorization',
      'proxy-authorization',
      'cookie',
      'set-cookie',
      'x-api-key',
    };
    final out = <String, String>{};
    headers.forEach((key, value) {
      final lower = key.toLowerCase();
      if (sensitive.contains(lower)) {
        out[key] = '[REDACTED]';
      } else {
        out[key] = value;
      }
    });
    return out;
  }

  static SkillDefinition? _findSkill(
    List<SkillDefinition> skills, {
    String? skillId,
    String? skillName,
    String? query,
  }) {
    final id = skillId?.toLowerCase();
    if (id != null && id.isNotEmpty) {
      for (final skill in skills) {
        if (skill.id.toLowerCase() == id) return skill;
      }
    }

    final name = skillName?.toLowerCase();
    if (name != null && name.isNotEmpty) {
      for (final skill in skills) {
        if (skill.name.toLowerCase() == name) return skill;
      }
      for (final skill in skills) {
        if (skill.name.toLowerCase().contains(name)) return skill;
      }
    }

    final q = query?.toLowerCase();
    if (q != null && q.isNotEmpty) {
      final scored = skills
          .map((skill) => (skill: skill, score: _scoreSkill(skill, q)))
          .where((entry) => entry.score > 0)
          .toList(growable: false)
        ..sort((a, b) => b.score.compareTo(a.score));
      if (scored.isNotEmpty) {
        return scored.first.skill;
      }
    }

    if (skills.length == 1) {
      return skills.first;
    }
    return null;
  }

  static int _scoreSkill(SkillDefinition skill, String query) {
    var score = 0;
    final id = skill.id.toLowerCase();
    final name = skill.name.toLowerCase();
    final desc = skill.description.toLowerCase();
    if (id == query) score += 120;
    if (name == query) score += 120;
    if (id.contains(query)) score += 60;
    if (name.contains(query)) score += 80;
    if (desc.contains(query)) score += 30;
    return score;
  }

  static ({
    String content,
    bool truncated,
    String mode,
    int? startLine,
    int? endLine,
    int totalLines,
  }) _extractSkillSnippet({
    required SkillDefinition skill,
    required String? section,
    required String? query,
    required int? startLine,
    required int? endLine,
    required int maxChars,
  }) {
    final body = skill.body;
    final totalLines = _countLines(body);
    if (body.trim().isEmpty) {
      return (
        content: '',
        truncated: false,
        mode: 'empty',
        startLine: null,
        endLine: null,
        totalLines: totalLines,
      );
    }

    String selected = body;
    String mode = 'full';
    int? effectiveStartLine;
    int? effectiveEndLine;

    final hasLineRange = (startLine != null) || (endLine != null);
    if (hasLineRange) {
      final byRange = _extractLineRange(
        body,
        startLine: startLine,
        endLine: endLine,
      );
      selected = byRange.content;
      effectiveStartLine = byRange.startLine;
      effectiveEndLine = byRange.endLine;
      mode = 'line_range';
    }

    final sectionName = section?.trim().toLowerCase();
    if (!hasLineRange && sectionName != null && sectionName.isNotEmpty) {
      final bySection = _extractSectionByHeading(body, sectionName);
      if (bySection.trim().isNotEmpty) {
        selected = bySection.trim();
        mode = 'section';
      }
    }

    final queryText = query?.trim().toLowerCase();
    if (queryText != null && queryText.isNotEmpty) {
      final queryHit = selected.toLowerCase().contains(queryText);
      final byQuery = _extractWindowByQuery(selected, queryText, maxChars);
      if (byQuery.trim().isNotEmpty) {
        selected = byQuery.trim();
        if (queryHit) {
          mode = mode == 'full' ? 'query_window' : '$mode+query';
        }
      }
    }

    if (selected.length <= maxChars) {
      return (
        content: selected,
        truncated: false,
        mode: mode,
        startLine: effectiveStartLine,
        endLine: effectiveEndLine,
        totalLines: totalLines,
      );
    }
    return (
      content: '${selected.substring(0, maxChars)}\n...',
      truncated: true,
      mode: mode,
      startLine: effectiveStartLine,
      endLine: effectiveEndLine,
      totalLines: totalLines,
    );
  }

  static ({
    String content,
    int startLine,
    int endLine,
  }) _extractLineRange(
    String text, {
    required int? startLine,
    required int? endLine,
  }) {
    final normalized = text.replaceAll('\r\n', '\n');
    final lines = normalized.split('\n');
    final totalLines = lines.length;
    if (totalLines == 0) {
      return (content: '', startLine: 0, endLine: 0);
    }

    var start = startLine ?? 1;
    var end = endLine ?? totalLines;
    if (start < 1) start = 1;
    if (start > totalLines) start = totalLines;
    if (end < start) end = start;
    if (end > totalLines) end = totalLines;

    final content = lines.sublist(start - 1, end).join('\n');
    return (
      content: content,
      startLine: start,
      endLine: end,
    );
  }

  static String _extractSectionByHeading(String markdown, String sectionName) {
    final lines = markdown.replaceAll('\r\n', '\n').split('\n');
    var start = -1;
    var end = lines.length;
    final heading = RegExp(r'^\s{0,3}(#{1,6})\s+(.+?)\s*$');
    int? startLevel;

    for (var i = 0; i < lines.length; i++) {
      final match = heading.firstMatch(lines[i]);
      if (match == null) continue;
      final level = match.group(1)?.length ?? 1;
      final text = (match.group(2) ?? '').toLowerCase();
      if (start < 0) {
        if (text.contains(sectionName)) {
          start = i;
          startLevel = level;
        }
        continue;
      }
      if (startLevel != null && level <= startLevel) {
        end = i;
        break;
      }
    }

    if (start < 0) return '';
    return lines.sublist(start, end).join('\n').trim();
  }

  static String _extractWindowByQuery(String text, String query, int maxChars) {
    final lower = text.toLowerCase();
    final idx = lower.indexOf(query);
    if (idx < 0 || text.length <= maxChars) return text;

    var start = idx - (maxChars ~/ 3);
    if (start < 0) start = 0;
    var end = start + maxChars;
    if (end > text.length) {
      end = text.length;
      final shifted = end - maxChars;
      start = shifted < 0 ? 0 : shifted;
    }

    final prevBreak = text.lastIndexOf('\n', start);
    if (prevBreak >= 0) start = prevBreak + 1;
    final nextBreak = text.indexOf('\n', end);
    if (nextBreak >= 0) end = nextBreak;

    if (start >= end) {
      final limit = maxChars < text.length ? maxChars : text.length;
      return text.substring(0, limit);
    }
    return text.substring(start, end).trim();
  }

  static int _countLines(String text) {
    if (text.isEmpty) return 0;
    return '\n'.allMatches(text).length + 1;
  }

  static List<Map<String, dynamic>> _extractHeadings(
    String markdown, {
    required int maxHeadings,
  }) {
    final lines = markdown.replaceAll('\r\n', '\n').split('\n');
    final heading = RegExp(r'^\s{0,3}(#{1,6})\s+(.+?)\s*$');
    final markers = <({int level, String title, int startLine})>[];

    for (var i = 0; i < lines.length; i++) {
      final match = heading.firstMatch(lines[i]);
      if (match == null) continue;
      final level = match.group(1)?.length ?? 1;
      final title = (match.group(2) ?? '').trim();
      if (title.isEmpty) continue;
      markers.add((
        level: level,
        title: title,
        startLine: i + 1,
      ));
    }

    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < markers.length; i++) {
      final marker = markers[i];
      var endLine = lines.length;
      for (var j = i + 1; j < markers.length; j++) {
        if (markers[j].level <= marker.level) {
          endLine = markers[j].startLine - 1;
          break;
        }
      }
      if (endLine < marker.startLine) {
        endLine = marker.startLine;
      }
      out.add({
        'level': marker.level,
        'title': marker.title,
        'start_line': marker.startLine,
        'end_line': endLine,
        'line_count': endLine - marker.startLine + 1,
      });
      if (out.length >= maxHeadings) break;
    }
    return out;
  }
}

class _BookmarkLinkEntry {
  final BookmarkNode node;
  final String path;

  const _BookmarkLinkEntry({required this.node, required this.path});
}
