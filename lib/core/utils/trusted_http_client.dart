import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Creates an HTTP client that trusts all certificates, including
/// self-signed ones commonly used by self-hosted Endurain servers.
///
/// WARNING: This disables certificate verification. Only use when
/// connecting to known self-hosted servers. For production cloud
/// servers with valid certs, this has no negative effect — it simply
/// adds trust for certificates that would otherwise be rejected.
http.Client createTrustedHttpClient() {
  final ioClient = HttpClient()
    ..badCertificateCallback = (X509Certificate cert, String host, int port) {
      return true; // Trust all certificates
    }
    ..connectionTimeout = const Duration(seconds: 30)
    ..idleTimeout = const Duration(seconds: 30);
  return IOClient(ioClient);
}

/// Singleton trusted HTTP client for reuse across the app.
http.Client? _sharedClient;

http.Client get trustedHttpClient {
  _sharedClient ??= createTrustedHttpClient();
  return _sharedClient!;
}
