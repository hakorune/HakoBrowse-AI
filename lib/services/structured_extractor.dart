import 'dart:convert';

import '../content_sanitizer.dart';

class StructuredExtractor {
  static String buildScript({
    required String selector,
    required Map<String, dynamic> schema,
  }) {
    final selectorJson = jsonEncode(selector);
    final schemaJson = jsonEncode(schema);
    return '''
(() => {
  const rootSelector = $selectorJson;
  const schema = $schemaJson;
  const root = rootSelector ? document.querySelector(rootSelector) : document;
  if (!root) {
    return JSON.stringify({ error: 'Root selector not found' });
  }
  const props = (schema && typeof schema === 'object' && schema.properties && typeof schema.properties === 'object')
    ? schema.properties
    : {};
  const data = {};
  for (const [key, cfgRaw] of Object.entries(props)) {
    const cfg = (cfgRaw && typeof cfgRaw === 'object') ? cfgRaw : {};
    const targetSelector = (typeof cfg.selector === 'string' && cfg.selector.trim().length > 0)
      ? cfg.selector
      : null;
    const attr = typeof cfg.attribute === 'string' ? cfg.attribute : 'text';
    const type = typeof cfg.type === 'string' ? cfg.type : 'string';
    const multiple = cfg.multiple === true;
    const nodes = targetSelector
      ? Array.from(root.querySelectorAll(targetSelector))
      : [root];
    const values = [];
    for (const node of nodes) {
      let raw = '';
      if (attr === 'html') raw = node.innerHTML || '';
      else if (attr === 'text') raw = node.textContent || '';
      else raw = node.getAttribute(attr) || '';
      raw = String(raw).trim();
      if (!raw) continue;
      if (type === 'number') {
        const n = Number(raw.replaceAll(',', ''));
        values.push(Number.isFinite(n) ? n : null);
      } else if (type === 'boolean') {
        values.push(/^(true|1|yes|on)\$/i.test(raw));
      } else {
        values.push(raw);
      }
    }
    data[key] = multiple ? values : (values.length > 0 ? values[0] : null);
  }
  return JSON.stringify({ data });
})();
''';
  }

  static dynamic sanitizeStructuredValue(dynamic value) {
    if (value is String) {
      return sanitizeUntrustedContent(value, sampleLimit: 0).content;
    }
    if (value is List) {
      return value.map(sanitizeStructuredValue).toList();
    }
    if (value is Map) {
      final out = <String, dynamic>{};
      value.forEach((k, v) {
        out[k.toString()] = sanitizeStructuredValue(v);
      });
      return out;
    }
    return value;
  }
}
