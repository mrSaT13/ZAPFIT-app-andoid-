/// Identity Provider model for SSO/OAuth authentication
class IdentityProvider {
  final int id;
  final String slug;
  final String name;
  final String? icon;

  const IdentityProvider({
    required this.id,
    required this.slug,
    required this.name,
    this.icon,
  });

  /// Create IdentityProvider from JSON
  factory IdentityProvider.fromJson(Map<String, dynamic> json) {
    return IdentityProvider(
      id: json['id'] as int,
      name: json['name'] as String,
      slug: json['slug'] as String,
      icon: json['icon'] as String?,
    );
  }

  /// Convert IdentityProvider to JSON
  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'slug': slug, 'icon': icon};
  }
}
