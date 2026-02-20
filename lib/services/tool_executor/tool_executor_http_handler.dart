part of '../tool_executor.dart';

Future<String> _handleHttpRequestTool({
  required BuildContext context,
  required Map<String, dynamic> arguments,
  required List<ToolAuthProfile> authProfiles,
  required bool enableSafetyGate,
  required String Function(String value, {int max}) shorten,
}) async {
  final rawUrl = (arguments['url'] as String?)?.trim() ?? '';
  if (rawUrl.isEmpty) {
    return jsonEncode({'error': 'url is required'});
  }
  final uri = Uri.tryParse(rawUrl);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return jsonEncode({'error': 'url must start with http:// or https://'});
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
  final authProfileId =
      ((arguments['auth_profile'] ?? arguments['authProfile']) as String?)
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
      final headerValue =
          prefix.isEmpty ? authProfile.apiKey : '$prefix ${authProfile.apiKey}';
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
      if (looksLikeJson && !_headerExistsIgnoreCase(headers, 'content-type')) {
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
      ((arguments['timeout_seconds'] as num?)?.toInt() ?? 20).clamp(1, 60);
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
    final response =
        await client.send(request).timeout(Duration(seconds: timeoutSeconds));

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
      'success': response.statusCode >= 200 && response.statusCode < 300,
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
