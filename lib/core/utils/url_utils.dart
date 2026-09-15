class UrlUtils {
  static String normalizeBaseUrl(String url) {
    var normalized = url.trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  static String normalizeEndpointPath(String path) {
    var normalized = path.trim();
    if (normalized.isEmpty) {
      return '/';
    }
    if (!normalized.startsWith('/')) {
      normalized = '/$normalized';
    }
    while (normalized.length > 1 && normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  static Uri buildUrl(String baseUrl, String endpointPath) {
    final base = normalizeBaseUrl(baseUrl);
    final endpoint = normalizeEndpointPath(endpointPath);
    return Uri.parse('$base$endpoint');
  }
}
