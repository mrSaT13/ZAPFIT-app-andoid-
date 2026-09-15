/// Model representing server settings fetched from the server
class ServerSettings {
  const ServerSettings({
    required this.units,
    required this.publicShareableLinks,
    required this.publicShareableLinksUserInfo,
    required this.loginPhotoSet,
    required this.currency,
    required this.numRecordsPerPage,
    required this.signupEnabled,
    required this.ssoEnabled,
    required this.localLoginEnabled,
    required this.ssoAutoRedirect,
    this.tileserverUrl,
    this.tileserverAttribution,
    this.mapBackgroundColor,
    required this.passwordType,
    required this.passwordLengthRegularUsers,
    required this.passwordLengthAdminUsers,
  });

  final String units;
  final bool publicShareableLinks;
  final bool publicShareableLinksUserInfo;
  final bool loginPhotoSet;
  final String currency;
  final int numRecordsPerPage;
  final bool signupEnabled;
  final bool ssoEnabled;
  final bool localLoginEnabled;
  final bool ssoAutoRedirect;
  final String? tileserverUrl;
  final String? tileserverAttribution;
  final String? mapBackgroundColor;
  final String passwordType;
  final int passwordLengthRegularUsers;
  final int passwordLengthAdminUsers;

  factory ServerSettings.fromJson(Map<String, dynamic> json) {
    return ServerSettings(
      units: json['units'] as String? ?? 'metric',
      publicShareableLinks: json['public_shareable_links'] as bool? ?? false,
      publicShareableLinksUserInfo:
          json['public_shareable_links_user_info'] as bool? ?? false,
      loginPhotoSet: json['login_photo_set'] as bool? ?? false,
      currency: json['currency'] as String? ?? 'euro',
      numRecordsPerPage: json['num_records_per_page'] as int? ?? 25,
      signupEnabled: json['signup_enabled'] as bool? ?? false,
      ssoEnabled: json['sso_enabled'] as bool? ?? false,
      localLoginEnabled: json['local_login_enabled'] as bool? ?? true,
      ssoAutoRedirect: json['sso_auto_redirect'] as bool? ?? false,
      tileserverUrl: json['tileserver_url'] as String?,
      tileserverAttribution: json['tileserver_attribution'] as String?,
      mapBackgroundColor: json['map_background_color'] as String?,
      passwordType: json['password_type'] as String? ?? 'strict',
      passwordLengthRegularUsers:
          json['password_length_regular_users'] as int? ?? 8,
      passwordLengthAdminUsers:
          json['password_length_admin_users'] as int? ?? 12,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'units': units,
      'public_shareable_links': publicShareableLinks,
      'public_shareable_links_user_info': publicShareableLinksUserInfo,
      'login_photo_set': loginPhotoSet,
      'currency': currency,
      'num_records_per_page': numRecordsPerPage,
      'signup_enabled': signupEnabled,
      'sso_enabled': ssoEnabled,
      'local_login_enabled': localLoginEnabled,
      'sso_auto_redirect': ssoAutoRedirect,
      'tileserver_url': tileserverUrl,
      'tileserver_attribution': tileserverAttribution,
      'map_background_color': mapBackgroundColor,
      'password_type': passwordType,
      'password_length_regular_users': passwordLengthRegularUsers,
      'password_length_admin_users': passwordLengthAdminUsers,
    };
  }
}
