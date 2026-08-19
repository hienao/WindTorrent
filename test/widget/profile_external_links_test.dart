import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/features/home/presentation/pages/profile_tab.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('Contact Developer opens WindTorrent GitHub Issues', (
    tester,
  ) async {
    Uri? openedUri;

    await tester.pumpWidget(
      createTestApp(
        downloaderController: MockDownloaderController(),
        child: ProfileTab(
          externalLinkOpener: (uri) async {
            openedUri = uri;
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Report issues on GitHub Issues'), findsOneWidget);
    await tester.ensureVisible(find.text('Contact Developer'));
    await tester.tap(find.text('Contact Developer'));
    await tester.pump();

    expect(openedUri, Uri.parse(AppConstants.githubIssuesUrl));
  });
}
