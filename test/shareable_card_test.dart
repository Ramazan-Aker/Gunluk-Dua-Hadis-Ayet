import 'package:daily_dua_hadith/models/daily_item.dart';
import 'package:daily_dua_hadith/widgets/shareable_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('paylaşım kartları tüm sosyal medya ölçülerinde taşmaz',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    final cases = <({DailyItem item, Size size})>[
      (
        item: DailyItem(
          type: 'hadith',
          text:
              'Müslüman, Müslümanların elinden ve dilinden emin oldukları kimsedir.',
          source: 'Buhârî',
        ),
        size: const Size(1080, 1080),
      ),
      (
        item: DailyItem(
          type: 'ayah',
          text:
              'Şüphesiz güçlükle beraber bir kolaylık vardır. Gerçekten, güçlükle beraber bir kolaylık vardır.',
          source: 'İnşirah Suresi, 5-6',
        ),
        size: const Size(1080, 1350),
      ),
      (
        item: DailyItem(
          type: 'dua',
          text: List.filled(
            6,
            'Allah’ım, kalbimize huzur, işlerimize kolaylık ve ömrümüze bereket ihsan eyle.',
          ).join(' '),
          source: 'Günün Duası',
        ),
        size: const Size(1080, 1920),
      ),
    ];

    for (final testCase in cases) {
      tester.view.physicalSize = testCase.size;
      await tester.pumpWidget(
        MaterialApp(
          home: ShareableCard(
            item: testCase.item,
            width: testCase.size.width,
            height: testCase.size.height,
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });
}
