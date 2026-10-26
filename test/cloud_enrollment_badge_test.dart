import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:display_app/data/providers/cloud_enrollment_provider.dart';
import 'package:display_app/screens/cloud_info_screen.dart';
import 'package:display_app/utils/cloud_connector.dart';
import 'package:display_app/utils/routing/app_router.dart';
import 'package:display_app/widgets/footer_widget.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class Translations extends AssetLoader {
  const Translations();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('$path/${locale.languageCode}-${locale.countryCode}.json')
          .readAsStringSync()) as Map<String, dynamic>;
}

Future<void> mountFooter(
  WidgetTester tester, {
  bool available = true,
  Future<CloudConnectorState> Function()? query,
  VoidCallback? onTap,
  Locale locale = const Locale('en', 'US'),
  bool online = true,
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      cloudConnectorAvailableProvider.overrideWithValue(available),
      cloudConnectorStateQueryProvider.overrideWithValue(
        query ?? () async => CloudConnectorState.enrolled,
      ),
    ],
    child: EasyLocalization(
      supportedLocales: const [Locale('en', 'US'), Locale('de', 'DE')],
      startLocale: locale,
      saveLocale: false,
      path: 'assets/translations',
      assetLoader: const Translations(),
      child: Builder(builder: (context) {
        return MaterialApp(
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          home: Scaffold(
            bottomNavigationBar: Footer(
              isOnline: online,
              selectedProtocolString: 'ISO 15118-20',
              onCloudTap: onTap,
            ),
          ),
        );
      }),
    ),
  ));
  await tester.pump();
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await EasyLocalization.ensureInitialized();
    EasyLocalization.logger.enableBuildModes = [];
  });

  testWidgets('absent connector hides badge and does not query status',
      (tester) async {
    var calls = 0;
    await mountFooter(tester, available: false, query: () async {
      calls++;
      return CloudConnectorState.enrolled;
    });
    expect(find.textContaining('Cloud:'), findsNothing);
    expect(calls, 0);
    await tester.pumpWidget(const SizedBox());
  });

  for (final state in CloudConnectorState.values) {
    testWidgets('$state label, colors, placement and accessible tap',
        (tester) async {
      var taps = 0;
      tester.view.reset();
      tester.view.physicalSize = const Size(1400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await mountFooter(tester,
          query: () async => state, onTap: () => taps++, online: false);
      final label = switch (state) {
        CloudConnectorState.enrolled => 'Cloud: Enrolled',
        CloudConnectorState.notEnrolled => 'Cloud: Not enrolled',
        CloudConnectorState.notReady => 'Cloud: Unknown',
      };
      final badge = find.text(label);
      expect(badge, findsOneWidget);
      final colors = Theme.of(tester.element(badge)).colorScheme;
      final background = switch (state) {
        CloudConnectorState.enrolled => colors.tertiaryContainer,
        CloudConnectorState.notEnrolled => colors.errorContainer,
        _ => colors.surfaceContainer,
      };
      final foreground = switch (state) {
        CloudConnectorState.enrolled => colors.onTertiaryContainer,
        CloudConnectorState.notEnrolled => colors.onErrorContainer,
        _ => colors.onSurfaceVariant,
      };
      final material = tester.widget<Material>(
          find.ancestor(of: badge, matching: find.byType(Material)).first);
      expect(material.color, background);
      expect(tester.widget<Text>(badge).style!.color, foreground);
      expect(tester.getTopLeft(badge).dx,
          greaterThan(tester.getTopRight(find.text('Offline')).dx));
      expect(tester.getCenter(badge).dy,
          tester.getCenter(find.text('Offline')).dy);
      final semantics = tester.ensureSemantics();
      expect(
          tester.getSemantics(
              find.ancestor(of: badge, matching: find.byType(InkWell))),
          matchesSemantics(
            label: label,
            isButton: true,
            isFocusable: true,
            hasTapAction: true,
            hasFocusAction: true,
          ));
      await tester.tap(badge);
      expect(taps, 1);
      semantics.dispose();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('loading, transitions, errors and completion-based polling',
      (tester) async {
    var calls = 0;
    var pending = Completer<CloudConnectorState>();
    var taps = 0;
    await mountFooter(tester,
        query: () {
          calls++;
          return pending.future;
        },
        onTap: () => taps++);
    expect(calls, 1);
    expect(find.text('Cloud: Unknown'), findsOneWidget);
    await tester.tap(find.text('Cloud: Unknown'));
    expect(taps, 1);
    await tester.pump(const Duration(seconds: 30));
    expect(calls, 1); // A slow check must never overlap another check.
    pending.complete(CloudConnectorState.enrolled);
    await tester.pump();
    await tester.pump();
    expect(find.text('Cloud: Enrolled'), findsOneWidget);
    pending = Completer<CloudConnectorState>();
    await tester.pump(const Duration(seconds: 9));
    expect(calls, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(calls, 2);
    pending.complete(CloudConnectorState.notEnrolled);
    await tester.pump();
    await tester.pump();
    expect(find.text('Cloud: Not enrolled'), findsOneWidget);
    pending = Completer<CloudConnectorState>();
    await tester.pump(const Duration(seconds: 10));
    pending.completeError(StateError('cannot read status'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Cloud: Unknown'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
    expect(calls, 3);
  });

  testWidgets('disposal during a check prevents further polling',
      (tester) async {
    var calls = 0;
    final pending = Completer<CloudConnectorState>();
    await mountFooter(tester, query: () {
      calls++;
      return pending.future;
    });
    await tester.pumpWidget(const SizedBox());
    pending.complete(CloudConnectorState.enrolled);
    await tester.pump(const Duration(seconds: 30));
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });

  for (final locale in [const Locale('en', 'US'), const Locale('de', 'DE')]) {
    for (final width in [320.0, 800.0]) {
      testWidgets('$locale layout wraps at width $width', (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await mountFooter(tester,
            locale: locale, query: () async => CloudConnectorState.notEnrolled);
        expect(
            find.text(locale.languageCode == 'de'
                ? 'Cloud: Nicht registriert'
                : 'Cloud: Not enrolled'),
            findsOneWidget);
        expect(tester.takeException(), isNull);
        if (width == 320) {
          expect(tester.getTopLeft(find.textContaining('Cloud:')).dy,
              greaterThan(tester.getBottomLeft(find.text('Online')).dy));
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  for (final rfc in [true, false]) {
    for (final state in CloudConnectorState.values) {
      testWidgets('shared navigation rfc=$rfc state=$state', (tester) async {
        RouteSettings? destination;
        var queries = 0;
        await tester.pumpWidget(MaterialApp(
          onGenerateRoute: (settings) {
            destination = settings;
            return MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('Destination')));
          },
          home: Builder(
              builder: (context) => Scaffold(
                      body: TextButton(
                    onPressed: () => goToCloud(context, enableRfc7030: rfc,
                        readState: () async {
                      queries++;
                      return state;
                    }),
                    child: const Text('Cloud'),
                  ))),
        ));
        await tester.tap(find.text('Cloud'));
        await tester.pumpAndSettle();
        if (rfc) {
          expect(destination!.name, AppRoutes.configureCloudConnectionScreen);
          expect(queries, 0);
        } else if (state == CloudConnectorState.notReady) {
          expect(find.text('Cloud connector not ready'), findsOneWidget);
          expect(find.text('(re)start cloud connector'), findsOneWidget);
          expect(find.text('wait for startup'), findsOneWidget);
          await tester.tap(find.byIcon(Icons.arrow_back));
          await tester.pumpAndSettle();
          expect(destination, isNull);
        } else if (state == CloudConnectorState.enrolled) {
          expect(find.text('(re)start cloud connection'), findsOneWidget);
          expect(find.text('re-enroll charger'), findsOneWidget);
          await tester.tap(find.text('(re)start cloud connection'));
          await tester.pumpAndSettle();
          expect(destination!.arguments, EnrollMode.restart);
        } else {
          expect(destination!.name, AppRoutes.simpleCloudConfigScreen);
          expect(destination!.arguments, EnrollMode.normal);
        }
      });
    }
  }

  testWidgets('re-enrollment dialog preserves mode', (tester) async {
    RouteSettings? destination;
    await tester.pumpWidget(MaterialApp(
      onGenerateRoute: (settings) {
        destination = settings;
        return MaterialPageRoute<void>(builder: (_) => const SizedBox());
      },
      home: Builder(
          builder: (context) => TextButton(
                onPressed: () => goToCloud(context,
                    enableRfc7030: false,
                    readState: () async => CloudConnectorState.enrolled),
                child: const Text('Cloud'),
              )),
    ));
    await tester.tap(find.text('Cloud'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('re-enroll charger'));
    await tester.pumpAndSettle();
    expect(destination!.name, AppRoutes.simpleCloudConfigScreen);
    expect(destination!.arguments, EnrollMode.reEnroll);
  });
}
