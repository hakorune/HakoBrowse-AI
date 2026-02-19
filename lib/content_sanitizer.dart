class ContentSanitizationResult {
  final String content;
  final int removedLines;
  final List<String> removedSamples;

  const ContentSanitizationResult({
    required this.content,
    required this.removedLines,
    required this.removedSamples,
  });
}

ContentSanitizationResult sanitizeUntrustedContent(
  String input, {
  int sampleLimit = 2,
}) {
  if (input.isEmpty) {
    return const ContentSanitizationResult(
      content: '',
      removedLines: 0,
      removedSamples: <String>[],
    );
  }

  final normalized = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final lines = normalized.split('\n');
  final suspiciousPattern = RegExp(
    r'(<<\s*sys\s*>>|\[/?inst\]|^\s*(system|assistant|developer|user)\s*[:>]|<\s*/?\s*system\s*>|ignore\s+(all\s+)?(previous|prior)\s+instructions|output\s+only\s+the\s+corrected\s+code|you are an expert python programmer)',
    caseSensitive: false,
  );

  var removed = 0;
  final kept = <String>[];
  final samples = <String>[];

  for (final line in lines) {
    if (suspiciousPattern.hasMatch(line)) {
      removed++;
      if (samples.length < sampleLimit) {
        final trimmed = line.trim();
        samples.add(trimmed.length > 120 ? '${trimmed.substring(0, 120)}...' : trimmed);
      }
      continue;
    }
    kept.add(line);
  }

  return ContentSanitizationResult(
    content: kept.join('\n'),
    removedLines: removed,
    removedSamples: samples,
  );
}
