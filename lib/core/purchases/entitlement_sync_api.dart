import 'package:sporand/core/net/api_client.dart';
import 'package:sporand/core/security/app_check_service.dart';
import 'package:sporand/core/security/session_repository.dart';

/// `POST /v1/me/entitlements/sync`: after a purchase or restore the server
/// re-fetches the RevenueCat subscriber (brief §6 "Purchase validation").
abstract interface class EntitlementSyncApi {
  Future<void> sync();
}

final class HttpEntitlementSyncApi implements EntitlementSyncApi {
  HttpEntitlementSyncApi({
    required ApiClient client,
    required SessionRepository sessions,
    required AppCheckService appCheck,
  }) : _client = client,
       _sessions = sessions,
       _appCheck = appCheck;

  final ApiClient _client;
  final SessionRepository _sessions;
  final AppCheckService _appCheck;

  @override
  Future<void> sync() async {
    final session = _sessions.current;
    if (session == null) return;
    await _client.postJson(
      '/v1/me/entitlements/sync',
      bearer: session.accessToken,
      appCheckToken: await _appCheck.getLimitedUseToken(),
    );
  }
}

final class FakeEntitlementSyncApi implements EntitlementSyncApi {
  int calls = 0;

  @override
  Future<void> sync() async => calls++;
}
