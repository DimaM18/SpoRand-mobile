import 'package:url_launcher/url_launcher.dart';

/// Opens store listings and legal pages outside the app.
abstract interface class ExternalLinkLauncher {
  Future<bool> open(Uri uri);
}

final class UrlLauncherExternalLinkLauncher implements ExternalLinkLauncher {
  const UrlLauncherExternalLinkLauncher();

  @override
  Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }
}

final class FakeExternalLinkLauncher implements ExternalLinkLauncher {
  final List<Uri> opened = [];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }
}
