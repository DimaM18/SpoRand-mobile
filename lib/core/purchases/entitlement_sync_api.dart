import 'package:sporand/core/net/api_client.dart';

/// `POST /v1/me/entitlements/sync`: after a purchase or restore the server
/// re-fetches the RevenueCat subscriber (brief §6 "Purchase validation").
abstract interface class EntitlementSyncApi {
  Future<void> sync();
}

final class HttpEntitlementSyncApi implements EntitlementSyncApi {
  HttpEntitlementSyncApi(this._client);

  final ApiClient _client;

  @override
  Future<void> sync() async {
    // Limited-use App Check token (brief §7 "Attestation").
    await _client.post(
      '/v1/me/entitlements/sync',
      appCheck: AppCheckUse.limitedUse,
    );
  }
}

final class FakeEntitlementSyncApi implements EntitlementSyncApi {
  int calls = 0;
  Object? failWith;

  @override
  Future<void> sync() async {
    calls++;
    final error = failWith;
    if (error != null) throw error;
  }
}
