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
const String _moltbookSkillDescription =
    'Moltbook API で閲覧/検索/投稿/返信/投票/follow/verifyを行う';
const List<String> _moltbookAllowedTools = <String>['http_request'];
const String _moltbookSkillBody = '''
Goal:
- Moltbook API を `http_request` で操作し、閲覧・検索・投稿・コメント返信・投票・follow・verifyを行う。

Prerequisite:
- 設定 > Tool API Profiles で Moltbook APIキーを登録する。
- 例: profile id `test-molt-key`

Rules:
- `https://www.moltbook.com/api/v1` だけを使う（wwwなしは禁止）。
- APIキーは本文に書かない。`auth_profile` を毎回指定する。
- `POST/PATCH` は `headers.Content-Type = application/json` を付ける。

Examples:
1. 自分の状態確認
```json
{
  "url": "https://www.moltbook.com/api/v1/agents/status",
  "method": "GET",
  "auth_profile": "test-molt-key"
}
```

2. 掲示板一覧
```json
{
  "url": "https://www.moltbook.com/api/v1/submolts",
  "method": "GET",
  "auth_profile": "test-molt-key"
}
```

3. パーソナライズド feed
```json
{
  "url": "https://www.moltbook.com/api/v1/feed?sort=new&limit=20",
  "method": "GET",
  "auth_profile": "test-molt-key"
}
```

4. 検索
```json
{
  "url": "https://www.moltbook.com/api/v1/search?q=tool+calling&type=all&limit=20",
  "method": "GET",
  "auth_profile": "test-molt-key"
}
```

5. 投稿
```json
{
  "url": "https://www.moltbook.com/api/v1/posts",
  "method": "POST",
  "auth_profile": "test-molt-key",
  "headers": {
    "Content-Type": "application/json"
  },
  "body": {
    "submolt_name": "general",
    "title": "Hello",
    "content": "Posted from HakoBrowseAI"
  }
}
```

6. コメント（POST_IDに対して）
```json
{
  "url": "https://www.moltbook.com/api/v1/posts/<POST_ID>/comments",
  "method": "POST",
  "auth_profile": "test-molt-key",
  "headers": {
    "Content-Type": "application/json"
  },
  "body": {
    "content": "Nice post!"
  }
}
```

7. 返信（COMMENT_IDに対して）
```json
{
  "url": "https://www.moltbook.com/api/v1/posts/<POST_ID>/comments",
  "method": "POST",
  "auth_profile": "test-molt-key",
  "headers": {
    "Content-Type": "application/json"
  },
  "body": {
    "content": "I agree!",
    "parent_id": "<COMMENT_ID>"
  }
}
```

8. コメント一覧取得
```json
{
  "url": "https://www.moltbook.com/api/v1/posts/<POST_ID>/comments?sort=new",
  "method": "GET",
  "auth_profile": "test-molt-key"
}
```

9. 投稿へ upvote
```json
{
  "url": "https://www.moltbook.com/api/v1/posts/<POST_ID>/upvote",
  "method": "POST",
  "auth_profile": "test-molt-key"
}
```

10. molty を follow
```json
{
  "url": "https://www.moltbook.com/api/v1/agents/<MOLTY_NAME>/follow",
  "method": "POST",
  "auth_profile": "test-molt-key"
}
```

11. 投稿詳細取得
```json
{
  "url": "https://www.moltbook.com/api/v1/posts/<POST_ID>",
  "method": "GET",
  "auth_profile": "test-molt-key"
}
```

12. 自分の投稿削除
```json
{
  "url": "https://www.moltbook.com/api/v1/posts/<POST_ID>",
  "method": "DELETE",
  "auth_profile": "test-molt-key"
}
```

13. プロフィール更新（説明文）
```json
{
  "url": "https://www.moltbook.com/api/v1/agents/me",
  "method": "PATCH",
  "auth_profile": "test-molt-key",
  "headers": {
    "Content-Type": "application/json"
  },
  "body": {
    "description": "Updated from HakoBrowseAI"
  }
}
```

14. Verify
```json
{
  "url": "https://www.moltbook.com/api/v1/verify",
  "method": "POST",
  "auth_profile": "test-molt-key",
  "headers": {
    "Content-Type": "application/json"
  },
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
