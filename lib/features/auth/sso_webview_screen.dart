import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:endurain/l10n/app_localizations.dart';
import 'package:endurain/core/utils/platform_utils.dart';

/// Screen for SSO/OAuth authentication via WebView
class SsoWebViewScreen extends StatefulWidget {
  const SsoWebViewScreen({
    super.key,
    required this.oauthUrl,
    required this.onSessionIdReceived,
    required this.onError,
  });

  final String oauthUrl;
  final void Function(String sessionId) onSessionIdReceived;
  final void Function(String error) onError;

  @override
  State<SsoWebViewScreen> createState() => _SsoWebViewScreenState();
}

class _SsoWebViewScreenState extends State<SsoWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _errorMessage = null;
            });
            _checkForCallback(url);
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _isLoading = false;
              _errorMessage = error.description;
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            _checkForCallback(request.url);
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.oauthUrl));
  }

  void _checkForCallback(String url) {
    final uri = Uri.parse(url);

    // Check for success callback pattern: /login?sso=success&session_id={uuid}
    if (uri.path.contains('/login') &&
        uri.queryParameters.containsKey('sso') &&
        uri.queryParameters['sso'] == 'success') {
      final sessionId = uri.queryParameters['session_id'];

      if (sessionId != null && sessionId.isNotEmpty) {
        // Session ID found - close WebView and return to app
        widget.onSessionIdReceived(sessionId);
        if (mounted) {
          Navigator.pop(context);
        }
        return;
      }
    }

    // Check for error callback pattern: /login?sso=error&message={error}
    if (uri.path.contains('/login') &&
        uri.queryParameters.containsKey('sso') &&
        uri.queryParameters['sso'] == 'error') {
      final errorMessage =
          uri.queryParameters['message'] ?? 'SSO authentication failed';
      widget.onError(errorMessage);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _handleCancel() {
    widget.onError('User cancelled SSO authentication');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (PlatformUtils.isApplePlatform) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(l10n.ssoWebViewTitle),
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _handleCancel,
            child: Text(l10n.ssoCancel),
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (_isLoading) const Center(child: CupertinoActivityIndicator()),
              if (_errorMessage != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          CupertinoIcons.exclamationmark_triangle,
                          size: 48,
                          color: CupertinoColors.systemRed,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: CupertinoColors.systemRed,
                          ),
                        ),
                        const SizedBox(height: 16),
                        CupertinoButton(
                          onPressed: () {
                            setState(() {
                              _errorMessage = null;
                            });
                            _controller.reload();
                          },
                          child: Text(l10n.retry),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // Android Material Design
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.ssoWebViewTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _handleCancel,
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
          if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                        });
                        _controller.reload();
                      },
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
