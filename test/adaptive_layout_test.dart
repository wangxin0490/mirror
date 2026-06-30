import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/layout/adaptive_layout.dart';

void main() {
  testWidgets('isTabletLayout false at Size(375,812)', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(375, 812)),
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                expect(isTabletLayout(context), isFalse);
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
  });

  testWidgets('isTabletLayout true at Size(1024,768)', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(1024, 768)),
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                expect(isTabletLayout(context), isTrue);
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
  });

  testWidgets('adaptiveSquareSize returns 200 on phone', (tester) async {
    double? result;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(375, 812)),
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                result = adaptiveSquareSize(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
    expect(result, 200);
  });

  testWidgets('adaptiveSquareSize returns 360 (capped) on tablet Size(1024,768)',
      (tester) async {
    double? result;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(1024, 768)),
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                result = adaptiveSquareSize(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
    expect(result, 360);
  });

  testWidgets('adaptiveAspectFrame phone: inner widget height equals phoneHeight 172',
      (tester) async {
    const phoneHeight = 172.0;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(375, 812)),
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return adaptiveAspectFrame(
                  context: context,
                  phoneHeight: phoneHeight,
                  child: const ColoredBox(color: Colors.red),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
    expect(sizedBox.height, phoneHeight);
  });

  testWidgets('adaptiveAspectFrame tablet: cover height > 172 at width 800',
      (tester) async {
    const phoneHeight = 172.0;
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(800, 600)),
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              child: Builder(
                builder: (context) {
                  return adaptiveAspectFrame(
                    context: context,
                    phoneHeight: phoneHeight,
                    child: const ColoredBox(
                      key: Key('adaptive-aspect-child'),
                      color: Colors.red,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final renderBox =
        tester.renderObject(find.byKey(const Key('adaptive-aspect-child')))
            as RenderBox;
    expect(renderBox.size.height, greaterThan(phoneHeight));
  });
}
