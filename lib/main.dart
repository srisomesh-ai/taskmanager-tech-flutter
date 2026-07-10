import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// The live technician portal — the WebView loads this exact page.
const String kStartUrl =
    'https://salmon-goldfish-110661.hostingersite.com/app/login.html';
const String kBaseUrl =
    'https://salmon-goldfish-110661.hostingersite.com/app/';

// Background handler (must be a top-level function)
@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage message) async {
  // Firebase shows the notification automatically when the app is in background.
}

final FlutterLocalNotificationsPlugin _localNotif =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'bgps_tasks',
  'Task Notifications',
  description: 'New tasks and updates for technicians',
  importance: Importance.high,
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_bgHandler);

    // Local-notifications channel (for showing pushes while app is open)
    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
    await _localNotif.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  } catch (_) {
    // If Firebase isn't configured yet, the app still runs as a plain WebView.
  }

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
  String? _fcmToken;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _setupWebView();
    _setupMessaging();
  }

  void _setupWebView() {
    late final PlatformWebViewControllerCreationParams params;
    params = const PlatformWebViewControllerCreationParams();
    final controller = WebViewController.fromPlatformCreationParams(params);

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFEFF3F2))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) {
            setState(() => _loading = false);
            _injectFcmToken();
          },
          onNavigationRequest: (req) {
            final url = req.url;
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

  Future<void> _setupMessaging() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      _fcmToken = await messaging.getToken();
      _injectFcmToken();

      messaging.onTokenRefresh.listen((t) {
        _fcmToken = t;
        _injectFcmToken();
      });

      // Foreground: show a local notification (Android won't auto-show these)
      FirebaseMessaging.onMessage.listen((RemoteMessage m) {
        final n = m.notification;
        if (n != null) {
          _localNotif.show(
            n.hashCode,
            n.title,
            n.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                _channel.id,
                _channel.name,
                channelDescription: _channel.description,
                importance: Importance.high,
                priority: Priority.high,
                icon: '@mipmap/ic_launcher',
              ),
            ),
            payload: m.data['url'] as String?,
          );
        }
      });

      // Tap on a notification that opened the app
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage m) {
        final url = m.data['url'] as String?;
        if (url != null && url.isNotEmpty) {
          _controller.loadRequest(Uri.parse(kBaseUrl + url));
        }
      });
    } catch (_) {
      // Firebase not ready — ignore, app still works as WebView.
    }
  }

  void _injectFcmToken() {
    if (_fcmToken == null) return;
    final safe = _fcmToken!.replaceAll("'", "");
    _controller.runJavaScript(
      "window.BGPS_FCM_TOKEN='$safe';",
    );
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.location,
      Permission.locationWhenInUse,
      Permission.camera,
      Permission.notification,
    ].request();
    await Geolocator.isLocationServiceEnabled();
  }

  Future<void> _launchExternal(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<bool> _confirmExit() async {
    final exit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit app?'),
        content: const Text('Do you want to close BharatGPS Technician?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF0E5C5C)),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    return exit == true;
  }

  Future<bool> _onBack() async {
    // Determine current page URL
    String url = '';
    try { url = (await _controller.currentUrl()) ?? ''; } catch (_) {}
    final isHome = url.contains('dashboard.html') ||
                   url.contains('login.html') ||
                   url.endsWith('/app/') ||
                   url.endsWith('/app');

    // On the home/dashboard (or login) screen → confirm exit, close app if confirmed
    if (isHome) {
      if (await _confirmExit()) { SystemNavigator.pop(); }
      return false; // we handle exit ourselves; never auto-pop
    }

    // Otherwise, navigate back within the WebView if possible
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return false;
    }

    // Not home and can't go back → confirm exit as a safe fallback
    if (await _confirmExit()) { SystemNavigator.pop(); }
    return false;
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
