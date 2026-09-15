import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:zapfit/l10n/app_localizations.dart';
import 'package:zapfit/core/services/auth_service.dart';
import 'package:zapfit/core/services/secure_storage_service.dart';
import 'package:zapfit/core/services/sso_service.dart';
import 'package:zapfit/core/services/server_settings_service.dart';
import 'package:zapfit/core/models/identity_provider.dart';
import 'package:zapfit/core/models/server_settings.dart';
import 'package:zapfit/core/utils/platform_utils.dart';
import 'package:zapfit/core/utils/validators.dart';
import 'package:zapfit/core/utils/dialog_utils.dart';
import 'package:zapfit/core/constants/ui_constants.dart';
import 'package:zapfit/features/auth/sso_webview_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.onLoginSuccess});

  final VoidCallback? onLoginSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverUrlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _mfaCodeController = TextEditingController();
  final _authService = AuthService();
  final _ssoService = SsoService();
  final _serverSettingsService = ServerSettingsService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _showMfaInput = false;
  bool _isStep2 =
      false; // Two-step flow: Step 1 = server URL, Step 2 = login/SSO
  String? _mfaUsername;
  List<IdentityProvider> _availableIdPs = [];
  ServerSettings? _serverSettings;

  /// Whether local login (username/password) is enabled
  bool get _localLoginEnabled => _serverSettings?.localLoginEnabled ?? true;

  @override
  void initState() {
    super.initState();
    // Auto-fill server URL and username from secure storage on first build,
    // so user does not have to re-enter them after a session expiry.
    _autofillFromStorage();
  }

  /// Pre-fill server URL and username from secure storage.
  /// [comment removed - encoding corrupted]
  /// once the user taps "Next" on the server URL step (see [_handleServerUrlNext]).
  Future<void> _autofillFromStorage() async {
    try {
      final storage = SecureStorageService();
      final savedUrl = await storage.getServerUrl();
      final savedUser = await storage.getUsername();
      final savedPassword = await storage.getPassword();
      if (!mounted) return;
      if (savedUrl != null && savedUrl.isNotEmpty) {
        _serverUrlController.text = savedUrl;
      }
      if (savedUser != null && savedUser.isNotEmpty) {
        _usernameController.text = savedUser;
      }
      if (savedPassword != null && savedPassword.isNotEmpty) {
        _passwordController.text = savedPassword;
        // Если логин и пароль уже есть — автопереход на шаг 2
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isStep2 && !_showMfaInput) {
            _handleServerUrlNext();
          }
        });
      }
    } catch (_) {
      // Безопасно игнорируем ошибки чтения из хранилища
    }
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _mfaCodeController.dispose();
    super.dispose();
  }

  /// Step 1: Validate server URL, fetch server settings and available IdPs
  Future<void> _handleServerUrlNext() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final serverUrl = _serverUrlController.text.trim();

      // First, fetch server settings
      final settings = await _serverSettingsService.getServerSettings(
        serverUrl: serverUrl,
      );

      // Store settings
      _serverSettings = settings;

      // Only fetch SSO providers if SSO is enabled
      List<IdentityProvider> idps = [];
      if (settings.ssoEnabled) {
        try {
          idps = await _ssoService.getEnabledProviders(serverUrl: serverUrl);
        } catch (e) {
          // If SSO fetch fails, continue with empty list
          idps = [];
        }
      }

      if (mounted) {
        setState(() {
          _availableIdPs = idps;
          _isStep2 = true;
          _isLoading = false;
        });

        // Auto-redirect to SSO if:
        // - SSO is enabled
        // - Only one provider available
        // - sso_auto_redirect is true
        if (settings.ssoEnabled &&
            settings.ssoAutoRedirect &&
            idps.length == 1) {
          // Slight delay to show the step 2 briefly before redirecting
          await Future<void>.delayed(const Duration(milliseconds: 100));
          if (mounted) {
            _handleSsoLogin(idps.first);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // If server settings fetch fails, show error
        _showError(e.toString());
      }
    }
  }

  /// Handle SSO provider selection
  Future<void> _handleSsoLogin(IdentityProvider idp) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final oauthUrl = await _ssoService.initiateOAuth(
        idp.slug,
        serverUrl: _serverUrlController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Open WebView
        await Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (context) => SsoWebViewScreen(
              oauthUrl: oauthUrl,
              onSessionIdReceived: (sessionId) async {
                // Exchange session for tokens
                try {
                  await _ssoService.exchangeSessionForTokens(sessionId);
                  if (mounted) {
                    widget.onLoginSuccess?.call();
                  }
                } catch (e) {
                  if (mounted) {
                    _showError(e.toString());
                  }
                }
              },
              onError: (error) {
                if (mounted) {
                  _showError(error);
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showError(e.toString());
      }
    }
  }

  /// Step 2: Traditional username/password login
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _authService.login(
        _usernameController.text.trim(),
        _passwordController.text,
        serverUrl: _serverUrlController.text.trim(),
      );

      if (mounted) {
        if (result.mfaRequired) {
          // Show MFA input
          setState(() {
            _showMfaInput = true;
            _mfaUsername = result.username;
            _isLoading = false;
          });
        } else {
          // Login successful, notify parent or navigate
          widget.onLoginSuccess?.call();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showError(e.toString());
      }
    }
  }

  Future<void> _handleMfaVerification() async {
    final l10n = AppLocalizations.of(context)!;
    if (_mfaCodeController.text.trim().isEmpty) {
      _showError(l10n.mfaCodeRequired);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.verifyMfa(
        _mfaUsername!,
        _mfaCodeController.text.trim(),
      );

      if (mounted) {
        // Предложить сохранить MFA-секрет для авто-входа
        final storage = SecureStorageService();
        final existingSecret = await storage.getMfaSecret();
        if (existingSecret == null || existingSecret.isEmpty) {
          _showSaveMfaSecretDialog();
        } else {
          widget.onLoginSuccess?.call();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showError(e.toString());
      }
    }
  }

  void _showSaveMfaSecretDialog() {
    final secretController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сохранить MFA-секрет?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Вставьте MFA-секрет (из QR-кода или приложения-аутентификатора) для автоматического входа.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: secretController,
              decoration: const InputDecoration(
                labelText: 'MFA Secret',
                border: OutlineInputBorder(),
                hintText: 'JBSWY3DPEHPK3PXP',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onLoginSuccess?.call();
            },
            child: const Text('Пропустить'),
          ),
          FilledButton(
            onPressed: () async {
              if (secretController.text.trim().isNotEmpty) {
                await SecureStorageService().setMfaSecret(secretController.text.trim());
              }
              if (mounted) {
                Navigator.pop(ctx);
                widget.onLoginSuccess?.call();
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    DialogUtils.showErrorDialog(context, message);
  }

  /// Build SSO provider icon widget
  /// Checks for local asset first, then tries URL, with fallback icon
  Widget _buildSsoIcon(IdentityProvider idp, {bool isCupertino = false}) {
    if (idp.icon == null || idp.icon!.isEmpty) {
      return Icon(
        isCupertino ? CupertinoIcons.person_circle : Icons.person_outline,
        size: 24,
        color: isCupertino ? CupertinoColors.white : null,
      );
    }

    // List of available local assets
    const localAssets = [
      'authelia',
      'authentik',
      'casdoor',
      'keycloak',
      'pocketid',
    ];

    // Check if icon matches a local asset (case-insensitive)
    final iconLower = idp.icon!.toLowerCase();

    if (localAssets.contains(iconLower)) {
      final assetPath = 'assets/sso/$iconLower.svg';
      try {
        return SvgPicture.asset(
          assetPath,
          width: 24,
          height: 24,
          fit: BoxFit.contain,
        );
      } catch (e) {
        return Icon(
          isCupertino ? CupertinoIcons.person_circle : Icons.person_outline,
          size: 24,
          color: isCupertino ? CupertinoColors.white : null,
        );
      }
    }

    // Try to load from URL
    return Image.network(
      idp.icon!,
      width: 24,
      height: 24,
      errorBuilder: (context, error, stackTrace) => Icon(
        isCupertino ? CupertinoIcons.person_circle : Icons.person_outline,
        size: 24,
        color: isCupertino ? CupertinoColors.white : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Cupertino style for iOS/macOS
    if (PlatformUtils.isApplePlatform) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(_showMfaInput ? l10n.mfaTitle : l10n.loginTitle),
          leading: _isStep2 && !_showMfaInput
              ? CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    setState(() {
                      _isStep2 = false;
                      _availableIdPs = [];
                      _serverSettings = null;
                    });
                  },
                  child: const Icon(CupertinoIcons.back),
                )
              : null,
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CupertinoActivityIndicator())
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(UIConstants.paddingStandard),
                    children: [
                      const SizedBox(height: 40),
                      // App logo or title
                      Center(
                        child: Image.asset(
                          'assets/logo/logo.png',
                          width: 120,
                          height: 120,
                        ),
                      ),
                      const SizedBox(height: 40),
                      if (!_showMfaInput) ...[
                        // Step 1: Server URL only
                        if (!_isStep2) ...[
                          CupertinoListSection.insetGrouped(
                            header: Text(l10n.serverUrl.toUpperCase()),
                            children: [
                              CupertinoTextFormFieldRow(
                                controller: _serverUrlController,
                                placeholder: l10n.serverUrlHint,
                                keyboardType: TextInputType.url,
                                textInputAction: TextInputAction.done,
                                validator: (value) =>
                                    Validators.validateUrl(value, l10n),
                                onFieldSubmitted: (_) => _handleServerUrlNext(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            child: CupertinoButton.filled(
                              onPressed: _handleServerUrlNext,
                              child: Text(l10n.next),
                            ),
                          ),
                        ]
                        // Step 2: SSO providers + username/password
                        else ...[
                          // Local login (username/password) - only if enabled
                          if (_localLoginEnabled) ...[
                            // Username field
                            CupertinoListSection.insetGrouped(
                              header: Text(l10n.username.toUpperCase()),
                              children: [
                                CupertinoTextFormFieldRow(
                                  controller: _usernameController,
                                  placeholder: l10n.usernameHint,
                                  textInputAction: TextInputAction.next,
                                  validator: (value) =>
                                      Validators.validateRequired(
                                        value,
                                        l10n,
                                        l10n.username,
                                      ),
                                ),
                              ],
                            ),
                            // Password field
                            CupertinoListSection.insetGrouped(
                              header: Text(l10n.password.toUpperCase()),
                              children: [
                                CupertinoTextFormFieldRow(
                                  controller: _passwordController,
                                  placeholder: l10n.passwordHint,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  validator: (value) =>
                                      Validators.validateRequired(
                                        value,
                                        l10n,
                                        l10n.password,
                                      ),
                                  onFieldSubmitted: (_) => _handleLogin(),
                                ),
                                CupertinoListTile(
                                  title: Text(l10n.showPassword),
                                  trailing: CupertinoSwitch(
                                    value: !_obscurePassword,
                                    onChanged: (value) {
                                      setState(() {
                                        _obscurePassword = !value;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              child: CupertinoButton.filled(
                                onPressed: _handleLogin,
                                child: Text(l10n.login),
                              ),
                            ),
                          ],
                          // SSO providers (if available)
                          if (_availableIdPs.isNotEmpty) ...[
                            // OR divider - only show if local login is also enabled
                            if (_localLoginEnabled) ...[
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  const Expanded(child: Divider()),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0,
                                    ),
                                    child: Text(
                                      l10n.ssoOrDivider,
                                      style: const TextStyle(
                                        color: CupertinoColors.systemGrey,
                                      ),
                                    ),
                                  ),
                                  const Expanded(child: Divider()),
                                ],
                              ),
                            ],
                            const SizedBox(height: 16),
                            for (final idp in _availableIdPs)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                  horizontal: 16.0,
                                ),
                                child: CupertinoButton(
                                  color: CupertinoColors.systemBlue,
                                  onPressed: () => _handleSsoLogin(idp),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (idp.icon != null &&
                                          idp.icon!.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 8.0,
                                          ),
                                          child: _buildSsoIcon(
                                            idp,
                                            isCupertino: true,
                                          ),
                                        ),
                                      Text(
                                        l10n.ssoSignInWith(idp.name),
                                        style: const TextStyle(
                                          color: CupertinoColors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ] else ...[
                        // MFA code field
                        CupertinoListSection.insetGrouped(
                          header: Text(l10n.mfaCode.toUpperCase()),
                          children: [
                            CupertinoTextFormFieldRow(
                              controller: _mfaCodeController,
                              placeholder: l10n.mfaCodeHint,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              validator: (value) => Validators.validateRequired(
                                value,
                                l10n,
                                l10n.mfaCode,
                              ),
                              onFieldSubmitted: (_) => _handleMfaVerification(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: UIConstants.paddingStandard,
                          ),
                          child: CupertinoButton.filled(
                            onPressed: _handleMfaVerification,
                            child: Text(l10n.verify),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: CupertinoButton(
                            onPressed: () {
                              setState(() {
                                _showMfaInput = false;
                                _mfaCodeController.clear();
                              });
                            },
                            child: Text(l10n.back),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      );
    }

    // Material style for Android
    return Scaffold(
      appBar: AppBar(
        title: Text(_showMfaInput ? l10n.mfaTitle : l10n.loginTitle),
        leading: _isStep2 && !_showMfaInput
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _isStep2 = false;
                    _availableIdPs = [];
                    _serverSettings = null;
                  });
                },
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(UIConstants.paddingStandard),
                children: [
                  const SizedBox(height: 40),
                  // App logo or title
                  Center(
                    child: Image.asset(
                      'assets/logo/logo.png',
                      width: 120,
                      height: 120,
                    ),
                  ),
                  const SizedBox(height: 40),
                  if (!_showMfaInput) ...[
                    // Step 1: Server URL only
                    if (!_isStep2) ...[
                      TextFormField(
                        controller: _serverUrlController,
                        decoration: InputDecoration(
                          labelText: l10n.serverUrl,
                          hintText: l10n.serverUrlHint,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.dns),
                        ),
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.done,
                        validator: (value) =>
                            Validators.validateUrl(value, l10n),
                        onFieldSubmitted: (_) => _handleServerUrlNext(),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _handleServerUrlNext,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(l10n.next),
                      ),
                    ]
                    // Step 2: SSO providers + username/password
                    else ...[
                      // Local login (username/password) - only if enabled
                      if (_localLoginEnabled) ...[
                        // Username field
                        TextFormField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: l10n.username,
                            hintText: l10n.usernameHint,
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.person),
                          ),
                          textInputAction: TextInputAction.next,
                          validator: (value) => Validators.validateRequired(
                            value,
                            l10n,
                            l10n.username,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Password field
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: l10n.password,
                            hintText: l10n.passwordHint,
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          validator: (value) => Validators.validateRequired(
                            value,
                            l10n,
                            l10n.password,
                          ),
                          onFieldSubmitted: (_) => _handleLogin(),
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _handleLogin,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(l10n.login),
                        ),
                      ],
                      // SSO providers (if available)
                      if (_availableIdPs.isNotEmpty) ...[
                        // OR divider - only show if local login is also enabled
                        if (_localLoginEnabled) ...[
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              const Expanded(child: Divider()),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                ),
                                child: Text(
                                  l10n.ssoOrDivider,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.color,
                                  ),
                                ),
                              ),
                              const Expanded(child: Divider()),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                        for (final idp in _availableIdPs)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: ElevatedButton.icon(
                              onPressed: () => _handleSsoLogin(idp),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              icon: _buildSsoIcon(idp),
                              label: Text(l10n.ssoSignInWith(idp.name)),
                            ),
                          ),
                      ],
                    ],
                  ] else ...[
                    // MFA code field
                    TextFormField(
                      controller: _mfaCodeController,
                      decoration: InputDecoration(
                        labelText: l10n.mfaCode,
                        hintText: l10n.mfaCodeHint,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.security),
                      ),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      validator: (value) => Validators.validateRequired(
                        value,
                        l10n,
                        l10n.mfaCode,
                      ),
                      onFieldSubmitted: (_) => _handleMfaVerification(),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _handleMfaVerification,
                      child: Padding(
                        padding: const EdgeInsets.all(
                          UIConstants.paddingMedium,
                        ),
                        child: Text(l10n.verify),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _showMfaInput = false;
                          _mfaCodeController.clear();
                        });
                      },
                      child: Text(l10n.back),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
