/// Removes connection schemes from a downloader server address.
///
/// The connection protocol is controlled exclusively by the HTTPS toggle in
/// the downloader editor. Both normal (`https://`) and escaped (`https\://`)
/// prefixes are accepted because users may paste either form.
String normalizeDownloaderHostInput(String input) {
  var normalized = input.trim();
  const prefixes = <String>['https://', 'http://', r'https\://', r'http\://'];

  while (true) {
    final lowerCase = normalized.toLowerCase();
    String? matchedPrefix;
    for (final prefix in prefixes) {
      if (lowerCase.startsWith(prefix)) {
        matchedPrefix = prefix;
        break;
      }
    }
    if (matchedPrefix == null) {
      return normalized;
    }
    normalized = normalized.substring(matchedPrefix.length).trimLeft();
  }
}
