import 'package:flutter_test/flutter_test.dart';

import 'package:sporand/app/bootstrap/domain/boot_models.dart';
import 'package:sporand/app/router/deep_links.dart';
import 'package:sporand/app/router/route_guard.dart';
import 'package:sporand/app/router/routes.dart';

const parser = DeepLinkParser(allowedHosts: {'play.example.test'});

BootCompleted completed(BootDestination destination) => BootCompleted(
  BootProgress.initial,
  destination,
  const BootReport(
    total: Duration.zero,
    records: [],
    deadlineHit: false,
    attempt: 1,
  ),
);

String? redirect(
  String location, {
  BootState boot = const BootRunning(BootProgress.initial),
  bool onboarded = true,
  bool blocked = false,
  DeepLinkQueue? queue,
}) => guardRedirect(
  uri: Uri.parse(location),
  boot: boot,
  onboardingCompleted: onboarded,
  ageBlocked: blocked,
  queue: queue ?? DeepLinkQueue(),
  parser: parser,
);

void main() {
  group('DeepLinkParser', () {
    test('parses join links and normalizes Crockford codes', () {
      expect(
        parser.parseUri(Uri.parse('https://play.example.test/j/abc-dlo')),
        const JoinRoomLink('ABCD10'),
      );
      expect(
        parser.parseUri(Uri.parse('/j/7K2M9Q')),
        const JoinRoomLink('7K2M9Q'),
      );
    });

    test('rejects other hosts, schemes, paths and invalid codes', () {
      for (final raw in [
        'https://evil.example/j/7K2M9Q',
        'http://play.example.test/j/7K2M9Q',
        '/lobby/7K2M9Q',
        '/j/7K2M9',
        '/j/7K2M9QQ',
        '/j/UUUUUU',
      ]) {
        expect(parser.parseUri(Uri.parse(raw)), isNull, reason: raw);
      }
    });

    test('parses push payloads', () {
      expect(
        parser.parse(const PushLink({'room_code': 'hjk234'})),
        const JoinRoomLink('HJK234'),
      );
      expect(
        parser.parse(
          const PushLink({'link': 'https://play.example.test/j/HJK234'}),
        ),
        const JoinRoomLink('HJK234'),
      );
      expect(parser.parse(const PushLink({'other': 1})), isNull);
    });
  });

  group('guardRedirect', () {
    test('while booting everything shows the splash and links are queued', () {
      final queue = DeepLinkQueue();
      expect(redirect(Routes.boot, queue: queue), isNull);
      expect(redirect('/j/7K2M9Q', queue: queue), Routes.boot);
      expect(redirect(Routes.home, queue: queue), Routes.boot);
      expect(queue.length, 1);
    });

    test('gates pin the app to their screen', () {
      final update = completed(const ForceUpdateDestination());
      expect(redirect(Routes.home, boot: update), Routes.forceUpdate);
      expect(redirect(Routes.forceUpdate, boot: update), isNull);
      final maintenance = completed(const MaintenanceDestination());
      expect(redirect('/settings', boot: maintenance), Routes.maintenance);
    });

    test('onboarding comes first and defers links', () {
      final queue = DeepLinkQueue();
      final boot = completed(const OnboardingDestination());
      expect(
        redirect('/j/7K2M9Q', boot: boot, onboarded: false, queue: queue),
        Routes.onboarding,
      );
      expect(queue.deferred, const JoinRoomLink('7K2M9Q'));
      expect(
        redirect(Routes.onboardingConsent, boot: boot, onboarded: false),
        isNull,
      );
    });

    test('an age-blocked user only sees the blocked screen', () {
      final boot = completed(const AgeBlockedDestination());
      expect(
        redirect(Routes.home, boot: boot, onboarded: false, blocked: true),
        Routes.onboardingBlocked,
      );
      expect(
        redirect(
          Routes.onboarding,
          boot: boot,
          onboarded: false,
          blocked: true,
        ),
        Routes.onboardingBlocked,
      );
    });

    test('after onboarding, onboarding and status screens bounce home', () {
      final boot = completed(const HomeDestination());
      expect(redirect(Routes.onboarding, boot: boot), Routes.home);
      expect(redirect(Routes.maintenance, boot: boot), Routes.home);
      expect(redirect('/j/7K2M9Q', boot: boot), isNull);
      expect(redirect(Routes.boot, boot: boot), isNull);
    });
  });
}
