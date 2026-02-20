class ToolAuthProfile {
  final String id;
  final String name;
  final String apiKey;
  final String headerName;
  final String valuePrefix;
  final List<String> allowedHosts;

  const ToolAuthProfile({
    required this.id,
    required this.name,
    required this.apiKey,
    required this.headerName,
    required this.valuePrefix,
    required this.allowedHosts,
  });

  ToolAuthProfile copyWith({
    String? id,
    String? name,
    String? apiKey,
    String? headerName,
    String? valuePrefix,
    List<String>? allowedHosts,
  }) {
    return ToolAuthProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      apiKey: apiKey ?? this.apiKey,
      headerName: headerName ?? this.headerName,
      valuePrefix: valuePrefix ?? this.valuePrefix,
      allowedHosts: allowedHosts ?? this.allowedHosts,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'apiKey': apiKey,
      'headerName': headerName,
      'valuePrefix': valuePrefix,
      'allowedHosts': allowedHosts,
    };
  }

  static ToolAuthProfile fromJson(Map<String, dynamic> json) {
    final rawHosts = json['allowedHosts'];
    final hosts = <String>[];
    if (rawHosts is List) {
      for (final item in rawHosts) {
        final text = item.toString().trim().toLowerCase();
        if (text.isNotEmpty) hosts.add(text);
      }
    }
    return ToolAuthProfile(
      id: json['id']?.toString().trim() ?? '',
      name: json['name']?.toString().trim() ?? '',
      apiKey: json['apiKey']?.toString() ?? '',
      headerName: json['headerName']?.toString().trim().isNotEmpty == true
          ? json['headerName'].toString().trim()
          : 'Authorization',
      valuePrefix: json['valuePrefix']?.toString().trim().isNotEmpty == true
          ? json['valuePrefix'].toString().trim()
          : 'Bearer',
      allowedHosts: hosts,
    );
  }

  String maskedKey() {
    final raw = apiKey.trim();
    if (raw.isEmpty) return '(empty)';
    if (raw.length <= 8) {
      return '${raw.substring(0, 2)}***';
    }
    return '${raw.substring(0, 4)}...${raw.substring(raw.length - 4)}';
  }
}
