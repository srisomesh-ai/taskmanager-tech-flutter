import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

// The live technician portal — the WebView loads this exact page.
const String kStartUrl =
    'https://salmon-goldfish-110661.hostingersite.com/app/login.html';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  runApp(const TechApp());
}

class TechApp extends StatelessWidget {
  const TechApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BharatGPS Technician',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF0E5C5C),
        scaffoldBackgroundColor: const Color(0xFF0E5C5C),
      ),
      home: const WebShell(),
    );
  }
}

class WebShell extends StatefulWidget {
  const WebShell({super.key});
  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _requestPermissions();

    late final PlatformWebViewControllerCreationParams params;
    params = const PlatformWebViewControllerCreationParams();
    final controller = WebViewController.fromPlatformCreationParams(params);

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFEFF3F2))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
          onNavigationRequest: (req) {
            final url = req.url;
            // Open external links (WhatsApp, tel:, maps, mailto) outside the WebView
            if (url.startsWith('tel:') ||
                url.startsWith('mailto:') ||
                url.startsWith('whatsapp:') ||
                url.startsWith('sms:') ||
                url.contains('wa.me') ||
                url.contains('api.whatsapp.com') ||
                url.contains('google.com/maps') ||
                url.contains('maps.google') ||
                url.contains('maps.app.goo.gl')) {
              _launchExternal(url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(kStartUrl));

    // Android: allow geolocation prompts inside the WebView
    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(false);
      (controller.platform as AndroidWebViewController)
          .setGeolocationPermissionsPromptCallbacks(
        onShowPrompt: (request) async {
          final ok = await Permission.locationWhenInUse.isGranted;
          return GeolocationPermissionsResponse(allow: ok, retain: true);
        },
      );
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    _controller = controller;
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.location,
      Permission.locationWhenInUse,
      Permission.camera,
    ].request();
    // Ensure device location services are on for geolocation
    await Geolocator.isLocationServiceEnabled();
  }

  Future<void> _launchExternal(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<bool> _onBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onBack,
      child: Scaffold(
        backgroundColor: const Color(0xFFEFF3F2),
        body: SafeArea(
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (_loading)
                const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF0E5C5C),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
