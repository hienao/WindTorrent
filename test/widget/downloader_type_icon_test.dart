import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/features/downloaders/presentation/widgets/downloader_type_icon.dart';

void main() {
  testWidgets('renders all downloader type icons with stable keys', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Row(
          children: [
            DownloaderTypeIcon(
              type: DownloaderType.aria2,
              size: DownloaderTypeIconSize.large,
            ),
            DownloaderTypeIcon(
              type: DownloaderType.qbittorrent,
              size: DownloaderTypeIconSize.medium,
            ),
            DownloaderTypeIcon(
              type: DownloaderType.transmission,
              size: DownloaderTypeIconSize.small,
            ),
          ],
        ),
      ),
    );

    expect(
      find.byKey(const Key('downloader-type-icon-aria2-large')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('downloader-type-icon-qbittorrent-medium')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('downloader-type-icon-transmission-small')),
      findsOneWidget,
    );
  });

  testWidgets('aria2 icon uses the aria2 raster asset', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DownloaderTypeIcon(
          type: DownloaderType.aria2,
          size: DownloaderTypeIconSize.large,
        ),
      ),
    );

    final image = tester.widget<Image>(
      find.byKey(const Key('downloader-type-asset-aria2')),
    );
    expect(
      (image.image as AssetImage).assetName,
      endsWith('downloader_type_aria2.png'),
    );
  });

  testWidgets('qbittorrent icon uses the qbittorrent raster asset', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DownloaderTypeIcon(
          type: DownloaderType.qbittorrent,
          size: DownloaderTypeIconSize.large,
        ),
      ),
    );

    final image = tester.widget<Image>(
      find.byKey(const Key('downloader-type-asset-qbittorrent')),
    );
    expect(
      (image.image as AssetImage).assetName,
      endsWith('downloader_type_qbittorrent.png'),
    );
  });
}
