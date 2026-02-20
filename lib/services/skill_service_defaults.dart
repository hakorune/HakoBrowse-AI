part of 'skill_service.dart';

const String _weatherSkillId = 'weather-check';
const String _weatherSkillName = 'Weather Check';
const String _weatherSkillDescription = 'Googleで指定地域の天気を確認する';
const List<String> _weatherAllowedTools = <String>[
  'navigate_to',
  'get_page_content',
  'extract_structured',
];
const String _weatherSkillBody = '''
Goal:
- 指定した地域の天気を確認する。

When to use:
- ユーザーが「天気」「気温」「予報」を知りたい時。

Steps:
1. `navigate_to` で `https://www.google.com/search?q=<地域>+天気` に移動する。
2. `extract_structured` で現在気温・概要・最高/最低を抽出する。
3. 抽出が難しい場合は `get_page_content` でページ内容を取得して要点を返す。
''';

const String _moltbookSkillId = 'moltbook-post';
const String _moltbookSkillName = 'Moltbook Post';
const String _moltbookSkillDescription = 'Moltbook API で投稿/verify/掲示板取得を行う';
const List<String> _moltbookAllowedTools = <String>['http_request'];
const String _moltbookSkillBody = '''
Goal:
- Moltbook API を `http_request` で操作し、掲示板確認と投稿/verifyを行う。

Prerequisite:
- 設定 > Tool API Profiles で Moltbook APIキーを登録する。
- 例: profile id `test-molt-key`

Rules:
- `https://www.moltbook.com/api/v1` だけを使う（wwwなしは禁止）。
- APIキーは本文に書かない。`auth_profile` を毎回指定する。

Examples:
1. 掲示板一覧
```json
{
  "url": "https://www.moltbook.com/api/v1/submolts",
  "method": "GET",
  "auth_profile": "test-molt-key"
}
```

2. 新着投稿
```json
{
  "url": "https://www.moltbook.com/api/v1/posts?sort=new&limit=10",
  "method": "GET",
  "auth_profile": "test-molt-key"
}
```

3. 投稿
```json
{
  "url": "https://www.moltbook.com/api/v1/posts",
  "method": "POST",
  "auth_profile": "test-molt-key",
  "body": {
    "submolt_name": "general",
    "title": "Hello",
    "content": "Posted from HakoBrowseAI"
  }
}
```

4. Verify
```json
{
  "url": "https://www.moltbook.com/api/v1/verify",
  "method": "POST",
  "auth_profile": "test-molt-key",
  "body": {
    "verification_code": "<verification_code>",
    "answer": "<answer>"
  }
}
```
''';

SkillDefinition _buildWeatherDefaultSkillDefinition({
  required bool enabled,
  String? path,
}) {
  return SkillDefinition(
    id: _weatherSkillId,
    name: _weatherSkillName,
    description: _weatherSkillDescription,
    allowedTools: _weatherAllowedTools,
    body: _weatherSkillBody.trim(),
    path: path ?? 'private/skills/$_weatherSkillId/SKILL.md',
    enabled: enabled,
  );
}

SkillDefinition _buildMoltbookDefaultSkillDefinition({
  required bool enabled,
  String? path,
}) {
  return SkillDefinition(
    id: _moltbookSkillId,
    name: _moltbookSkillName,
    description: _moltbookSkillDescription,
    allowedTools: _moltbookAllowedTools,
    body: _moltbookSkillBody.trim(),
    path: path ?? 'private/skills/$_moltbookSkillId/SKILL.md',
    enabled: enabled,
  );
}

List<SkillDefinition> _buildBundledDefaultSkillDefinitions({
  required bool weatherEnabled,
  required bool moltbookEnabled,
  required String pathRoot,
}) {
  return <SkillDefinition>[
    _buildWeatherDefaultSkillDefinition(
      enabled: weatherEnabled,
      path: '$pathRoot/$_weatherSkillId/SKILL.md',
    ),
    _buildMoltbookDefaultSkillDefinition(
      enabled: moltbookEnabled,
      path: '$pathRoot/$_moltbookSkillId/SKILL.md',
    ),
  ];
}
