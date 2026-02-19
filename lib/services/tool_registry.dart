import '../models/tool_definition.dart';

class ToolRegistry {
  static const List<ToolDefinition> definitions = [
    ToolDefinition(
      name: 'get_page_content',
      description: '現在ブラウザで開いているページの内容を取得します。',
      risk: 'low',
      parameters: {},
      required: <String>[],
    ),
    ToolDefinition(
      name: 'navigate_to',
      description: '指定したURLにブラウザで移動します。',
      risk: 'medium',
      parameters: {
        'url': {'type': 'string', 'description': '移動先のURL'},
      },
      required: <String>['url'],
    ),
    ToolDefinition(
      name: 'open_new_tab',
      description: '新しいタブを開きます。URL指定時はそのURLを開きます。',
      risk: 'medium',
      parameters: {
        'url': {'type': 'string', 'description': '開くURL（省略可）'},
        'activate': {
          'type': 'boolean',
          'description': 'trueなら新タブに切り替える（既定: true）',
        },
      },
      required: <String>[],
    ),
    ToolDefinition(
      name: 'get_current_url',
      description: '現在ブラウザで開いているページのURLを取得します。',
      risk: 'low',
      parameters: {},
      required: <String>[],
    ),
    ToolDefinition(
      name: 'execute_script',
      description: 'ブラウザでJavaScriptを実行します。',
      risk: 'high',
      parameters: {
        'script': {'type': 'string', 'description': '実行するJavaScript'},
      },
      required: <String>['script'],
    ),
    ToolDefinition(
      name: 'extract_structured',
      description: 'ページから指定schemaに沿って構造化データを抽出します。',
      risk: 'medium',
      parameters: {
        'selector': {'type': 'string', 'description': '抽出の起点となるCSSセレクタ'},
        'schema': {
          'type': 'object',
          'description':
              'JSON schema風定義。properties.<field>.selector/attribute/type/multiple',
        },
      },
      required: <String>['schema'],
    ),
    ToolDefinition(
      name: 'add_bookmark',
      description: 'ブックマークを追加または更新します。',
      risk: 'low',
      parameters: {
        'url': {'type': 'string', 'description': '保存するURL（省略時は現在のURL）'},
        'title': {'type': 'string', 'description': 'ブックマーク表示タイトル'},
        'folder': {'type': 'string', 'description': 'フォルダ名（例: General, Work）'},
        'duplicate_strategy': {
          'type': 'string',
          'description': 'overwrite または keep_both'
        },
      },
      required: <String>[],
    ),
    ToolDefinition(
      name: 'list_bookmarks',
      description: '保存済みブックマーク一覧を取得します。',
      risk: 'low',
      parameters: {},
      required: <String>[],
    ),
    ToolDefinition(
      name: 'open_bookmark',
      description: 'ブックマークを開きます。',
      risk: 'medium',
      parameters: {
        'id': {'type': 'string', 'description': 'ブックマークID'},
        'url': {'type': 'string', 'description': '対象URL'},
        'query': {'type': 'string', 'description': 'タイトル/URLの検索文字列'},
      },
      required: <String>[],
    ),
  ];

  static List<Map<String, dynamic>> anthropicTools(
      {Set<String>? allowedNames}) {
    final defs = _filter(allowedNames);
    return defs
        .map(
          (d) => {
            'name': d.name,
            'description': d.description,
            'input_schema': {
              'type': 'object',
              'properties': d.parameters,
              if (d.required.isNotEmpty) 'required': d.required,
            },
          },
        )
        .toList();
  }

  static List<Map<String, dynamic>> openaiTools({Set<String>? allowedNames}) {
    final defs = _filter(allowedNames);
    return defs
        .map(
          (d) => {
            'type': 'function',
            'function': {
              'name': d.name,
              'description': d.description,
              'parameters': {
                'type': 'object',
                'properties': d.parameters,
                if (d.required.isNotEmpty) 'required': d.required,
              },
            },
          },
        )
        .toList();
  }

  static List<ToolDefinition> _filter(Set<String>? allowedNames) {
    if (allowedNames == null || allowedNames.isEmpty) return definitions;
    return definitions.where((d) => allowedNames.contains(d.name)).toList();
  }
}
