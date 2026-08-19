import 'package:url_launcher/url_launcher.dart';

typedef ExternalLinkOpener = Future<bool> Function(Uri uri);

Future<bool> openExternalLink(Uri uri) {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
