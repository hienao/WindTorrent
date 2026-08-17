class WebDavConfig {
  const WebDavConfig({
    required this.rootUrl,
    required this.remoteDirectory,
    required this.username,
    required this.password,
  });

  final String rootUrl;
  final String remoteDirectory;
  final String username;
  final String password;

  String get normalizedRootUrl {
    final value = rootUrl.trim();
    if (value.endsWith('/')) {
      return value;
    }
    return '$value/';
  }

  String get normalizedRemoteDirectory {
    final segments = remoteDirectory
        .split('/')
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.isEmpty) {
      return 'WindTorrent/Backups';
    }
    return segments.join('/');
  }

  String get maskedSummary {
    final usernameValue = username.trim();
    final account = usernameValue.isEmpty ? 'anonymous' : usernameValue;
    return '$account · $normalizedRemoteDirectory';
  }

  Map<String, dynamic> toJson() => {
    'rootUrl': normalizedRootUrl,
    'remoteDirectory': normalizedRemoteDirectory,
    'username': username.trim(),
    'password': password,
  };

  factory WebDavConfig.fromJson(Map<String, dynamic> json) {
    return WebDavConfig(
      rootUrl: json['rootUrl'] as String? ?? '',
      remoteDirectory:
          json['remoteDirectory'] as String? ?? 'WindTorrent/Backups',
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
    );
  }
}
