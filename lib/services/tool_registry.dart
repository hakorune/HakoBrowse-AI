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
      name: 'load_skill',
      description:
          'ローカル保存済みスキルを必要なときだけ読み込みます。section/queryや行番号(start_line/end_line)で部分取得できます。',
      risk: 'low',
      parameters: {
        'skill_id': {'type': 'string', 'description': '読み込むスキルID'},
        'skill_name': {'type': 'string', 'description': '読み込むスキル名'},
        'query': {
          'type': 'string',
          'description': '本文内で関連部分を探すキーワード',
        },
        'section': {
          'type': 'string',
          'description': 'Markdown見出し名（例: Steps / API）',
        },
        'start_line': {
          'type': 'integer',
          'description': '取得開始行(1始まり)。end_line未指定なら末尾まで',
        },
        'end_line': {
          'type': 'integer',
          'description': '取得終了行(1始まり、含む)。start_line以上',
        },
        'max_chars': {
          'type': 'integer',
          'description': '返却本文の最大文字数（既定: 3500, 範囲: 800-8000）',
        },
      },
      required: <String>[],
    ),
    ToolDefinition(
      name: 'load_skill_file',
      description: 'スキルフォルダ内の追加ファイル（例: HEARTBEAT.md / RULES.md）を相対パスで読み込みます。',
      risk: 'low',
      parameters: {
        'skill_id': {'type': 'string', 'description': '対象スキルID'},
        'skill_name': {'type': 'string', 'description': '対象スキル名'},
        'query': {'type': 'string', 'description': '対象スキルを絞る検索語'},
        'file_path': {
          'type': 'string',
          'description': 'スキルフォルダ基準の相対パス（例: HEARTBEAT.md）',
        },
        'section': {
          'type': 'string',
          'description': 'Markdown見出し名（例: Rules / API）',
        },
        'max_chars': {
          'type': 'integer',
          'description': '返却本文の最大文字数（既定: 3500, 範囲: 800-12000）',
        },
      },
      required: <String>[],
    ),
    ToolDefinition(
      name: 'load_skill_index',
      description: 'スキルの見出し一覧とメタ情報を取得します。本文は含みません。',
      risk: 'low',
      parameters: {
        'skill_id': {'type': 'string', 'description': '対象スキルID'},
        'skill_name': {'type': 'string', 'description': '対象スキル名'},
        'query': {
          'type': 'string',
          'description': '検索キーワード（該当スキル候補の絞り込み）',
        },
        'max_headings': {
          'type': 'integer',
          'description': '返却する見出し数上限（既定: 60, 範囲: 10-200）',
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
      name: 'http_request',
      description: 'HTTPリクエストを実行してレスポンスを取得します。',
      risk: 'high',
      parameters: {
        'url': {'type': 'string', 'description': 'リクエスト先URL'},
        'method': {
          'type': 'string',
          'description': 'HTTPメソッド（GET/POST/PUT/PATCH/DELETE/HEAD）',
        },
        'headers': {
          'type': 'object',
          'description': 'HTTPヘッダー（文字列キー/値）',
          'additionalProperties': {'type': 'string'},
        },
        'auth_profile': {
          'type': 'string',
          'description': '登録済みAPIプロファイルIDまたは名前（Authorization等を自動注入）',
        },
        'body': {
          'description': 'リクエストボディ（文字列またはJSONオブジェクト）',
        },
        'timeout_seconds': {
          'type': 'integer',
          'description': 'タイムアウト秒（既定: 20, 上限: 60）',
        },
        'max_response_bytes': {
          'type': 'integer',
          'description': 'レスポンス最大取得バイト数（既定: 200000）',
        },
        'follow_redirects': {
          'type': 'boolean',
          'description': 'リダイレクト追従（既定: true）',
        },
      },
      required: <String>['url'],
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
