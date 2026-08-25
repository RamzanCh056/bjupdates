import 'dart:io';
import 'package:beatjerky/config/openai_config.dart';
import 'package:beatjerky/notification_services/notification_services.dart';
import 'package:beatjerky/providers/feeds_provider/feed_comments_provider.dart';
import 'package:beatjerky/providers/feeds_provider/feeds_provider.dart';
import 'package:beatjerky/providers/music_store_provider/music_store_provider.dart';
import 'package:beatjerky/providers/music_style_provider/music_style_provider.dart';
import 'package:beatjerky/providers/song_provider/song_provider.dart';
import 'package:beatjerky/providers/user_provider.dart';
import 'package:beatjerky/screens/splash_screen.dart';
import 'package:beatjerky/services/navigation_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:get/get.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'notification_services/notification_services.dart'
    as notification_services;

void main() async {
  await WidgetsFlutterBinding.ensureInitialized();
  //await RiveNative.init();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Register background message handler (must be top-level)
    FirebaseMessaging.onBackgroundMessage(
      notification_services.firebaseMessageBackgroundHandle,
    );

    // Initialize notification service
    NotificationService().initInfo();

    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );

    print("✅ Firebase and Notifications Initialized Successfully");
  } catch (e) {
    print("❌ Firebase initialization failed: $e");
  }

  Provider.debugCheckInvalidValueType = null;
  if (Platform.isAndroid) {
    AndroidGoogleMapsFlutter.useAndroidViewSurface = true;
  }

  try {
    // Root .env overrides stripe/.env so a filled root key isn't wiped by an empty stripe line.
    await dotenv.load(
      fileName: 'assets/stripe/.env',
      overrideWithFiles: const ['.env'],
      isOptional: true,
    );
    print('✅ Loaded assets/stripe/.env + .env');
  } catch (e) {
    print('⚠️ Env load failed, trying .env only: $e');
    await dotenv.load(fileName: '.env', isOptional: true);
  }

  final stripePk = (dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '').trim();
  if (stripePk.isNotEmpty) {
    Stripe.publishableKey = stripePk;
  }
  final openAiLen = OpenAiConfig.resolveApiKey().length;
  print(
    '✅ Env keys: GOOGLE_PLACE=${dotenv.env['GOOGLE_PLACE_API_KEY']?.isNotEmpty == true}, '
    'TAVILY=${dotenv.env['TAVILY_API_KEY']?.isNotEmpty == true}, '
    'OPENAI=${openAiLen > 0} (len=$openAiLen)',
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserStatusProvider()),
        ChangeNotifierProvider(create: (_) => FeedsProvider()),
        ChangeNotifierProvider(create: (_) => FeedProvider()),
        ChangeNotifierProvider(create: (_) => CommentsProvider()),
        ChangeNotifierProvider(create: (_) => CommentProvider()),
        ChangeNotifierProvider(create: (_) => MusicStyleProvider()),
        ChangeNotifierProvider(create: (_) => MusicStoreProvider()),
        ChangeNotifierProvider(create: (_) => SongProvider()),
        ChangeNotifierProvider(create: (_) => UserStatusProvider()),
      ],
      child: const MyApp(),
    ),
  );
  configLoading();
}

void configLoading() {
  EasyLoading.instance
    ..displayDuration = const Duration(milliseconds: 2000)
    ..indicatorType = EasyLoadingIndicatorType.fadingCircle
    ..loadingStyle = EasyLoadingStyle.light
    ..indicatorSize = 45.0
    ..radius = 10.0
    ..progressColor = Colors.yellow
    ..backgroundColor = Colors.green
    ..indicatorColor = Colors.yellow
    ..textColor = Colors.yellow
    ..maskColor = Colors.blue.withOpacity(0.5)
    ..userInteractions = true
    ..dismissOnTap = false;
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      navigatorKey: navigatorKey, // Set global navigator key for deep linking
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // brightness: Brightness.dark,
        // //   colorScheme: ColorScheme.dark(background: blackColor),
        // scaffoldBackgroundColor: blackColor,
        // primarySwatch: Colors.blue,
      ),
      home: const SplashScreen(),
      builder: EasyLoading.init(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Check for pending navigation when app resumes
      NavigationService.checkPendingNavigation();
    }
  }
}
