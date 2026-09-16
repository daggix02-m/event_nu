import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:event_nu/shared/widgets/event_nu_logo.dart';

void main() {
  testWidgets('default constructor renders the wordmark lockup image', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: EventNuLogo())),
    );

    expect(find.byType(EventNuLogo), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, 'assets/brand/logo.png');
  });

  testWidgets('mark variant renders the square mark image', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: EventNuLogo.mark())),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, 'assets/brand/mark.webp');
  });

  testWidgets('lockup defaults wider than the mark', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: EventNuLogo())),
    );
    expect(tester.getSize(find.byType(EventNuLogo)).width, greaterThan(80));

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: EventNuLogo.mark())),
    );
    expect(tester.getSize(find.byType(EventNuLogo)).width, lessThanOrEqualTo(80));
  });
}