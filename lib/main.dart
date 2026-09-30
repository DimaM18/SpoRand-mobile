import 'package:sporand/app/bootstrap/bootstrap.dart';

/// Single entry point for every flavor. The flavor is chosen with
/// `--dart-define=FLAVOR=dev|staging|prod|spotifyProto` (default: dev).
void main() => bootstrap();
