import 'dart:io';

class AgentProfile {
  final String id;
  final String name;
  final String directoryPath;
  final String soul;
  final String userProfile;

  const AgentProfile({
    required this.id,
    required this.name,
    required this.directoryPath,
    required this.soul,
    required this.userProfile,
  });

  String buildSystemPrompt() {
    final parts = <String>[];
    if (soul.trim().isNotEmpty) {
      parts.add('SOUL\n$soul');
    }
    if (userProfile.trim().isNotEmpty) {
      parts.add('USER\n$userProfile');
    }
    return parts.join('\n\n');
  }
}

class AgentProfileService {
  Future<List<AgentProfile>> loadProfiles() async {
    final profiles = <AgentProfile>[];
    final multiRoot = Directory('private/agents');
    final singleRoot = Directory('private/agent');

    if (await multiRoot.exists()) {
      final children = multiRoot.listSync().whereType<Directory>().toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      for (final dir in children) {
        final profile = await _loadProfileDir(dir);
        if (profile != null) profiles.add(profile);
      }
    }

    if (profiles.isEmpty && await singleRoot.exists()) {
      final profile = await _loadProfileDir(
        singleRoot,
        forcedId: 'default',
        forcedName: 'default',
      );
      if (profile != null) profiles.add(profile);
    }

    if (profiles.isEmpty) {
      profiles.add(
        const AgentProfile(
          id: 'default',
          name: 'default',
          directoryPath: 'private/agent',
          soul: '',
          userProfile: '',
        ),
      );
    }

    return profiles;
  }

  Future<AgentProfile?> _loadProfileDir(
    Directory dir, {
    String? forcedId,
    String? forcedName,
  }) async {
    final soulFile = File('${dir.path}/SOUL.md');
    final userFile = File('${dir.path}/USER.md');
    final nameFile = File('${dir.path}/NAME.txt');
    if (!await soulFile.exists() && !await userFile.exists()) {
      return null;
    }

    final soul = await _safeRead(soulFile);
    final user = await _safeRead(userFile);
    final id = forcedId ?? _basename(dir.path);
    final customName = (await _safeRead(nameFile)).trim();
    final name = customName.isNotEmpty ? customName : (forcedName ?? id);

    return AgentProfile(
      id: id,
      name: name,
      directoryPath: dir.path,
      soul: soul,
      userProfile: user,
    );
  }

  Future<void> saveProfile({
    required AgentProfile profile,
    required String name,
    required String soul,
    required String userProfile,
  }) async {
    final dir = Directory(profile.directoryPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final soulFile = File('${dir.path}/SOUL.md');
    final userFile = File('${dir.path}/USER.md');
    final nameFile = File('${dir.path}/NAME.txt');
    final normalizedName = name.trim();
    await soulFile.writeAsString(soul);
    await userFile.writeAsString(userProfile);
    if (normalizedName.isNotEmpty) {
      await nameFile.writeAsString(normalizedName);
    } else if (await nameFile.exists()) {
      await nameFile.delete();
    }
  }

  Future<String> _safeRead(File file) async {
    if (!await file.exists()) return '';
    try {
      return await file.readAsString();
    } catch (_) {
      return '';
    }
  }

  String _basename(String path) {
    final normalized = path.replaceAll('\\', '/');
    final index = normalized.lastIndexOf('/');
    if (index < 0 || index + 1 >= normalized.length) return normalized;
    return normalized.substring(index + 1);
  }
}
