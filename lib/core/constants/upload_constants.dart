class UploadConstants {
  static const String activityUploadEndpoint =
      '/api/v1/activities/create/upload';
  static const String gpxContentType = 'application/gpx+xml';
  static const String multipartFileField = 'file';
  static const List<String> multipartFileFieldFallbacks = [
    'gpx',
    'gpx_file',
    'upload',
  ];
  static const String defaultGpxFilename = 'activity.gpx';
  static const int defaultUploadRetries = 2;
  static const String idempotencyHeader = 'Idempotency-Key';
  static const String uploadActivityIdHeader = 'X-Upload-Activity-Id';
}
