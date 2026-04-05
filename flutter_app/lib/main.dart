import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:crisis_response_app/core/constants/app_constants.dart';
import 'package:crisis_response_app/core/router/app_router.dart';
import 'package:crisis_response_app/core/theme/app_theme.dart';
import 'package:crisis_response_app/core/services/notification_service.dart';
import 'package:crisis_response_app/core/services/shared_data_service.dart';
import 'package:crisis_response_app/features/mesh/services/mesh_service.dart';
import 'package:crisis_response_app/core/services/shared_data_service.dart';

final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Initialize Hive and other services
  await Hive.initFlutter();
  await Hive.openBox(AppConstants.cacheBoxName);
  await Hive.openBox(AppConstants.userBoxName);
  await SharedDataService.init();

  await NotificationService.instance.init();
  
  // Start Mesh Networking
  MeshService.instance.start();

  runApp(const CrisisResponseApp());
}

class CrisisResponseApp extends StatefulWidget {
  const CrisisResponseApp({super.key});

  @override
  State<CrisisResponseApp> createState() => _CrisisResponseAppState();
}

class _CrisisResponseAppState extends State<CrisisResponseApp> {
  @override
  void initState() {
    super.initState();
    // Listen for global sync events (new alerts/SOS)
    SharedDataService.instance.eventStream.listen((event) {
      final type = event['type'];
      final data = event['data'];
      
      messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                type == 'alert' ? '🚨 NEW EMERGENCY ALERT' : '🆘 NEW SOS REQUEST',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Text(data['title'] ?? data['type'] ?? 'Updated Information'),
            ],
          ),
          backgroundColor: type == 'alert' ? const Color(0xFFFF3B30) : const Color(0xFFFF9500),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(label: 'VIEW', textColor: Colors.white, onPressed: () {}),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Crisis Response',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,
      scaffoldMessengerKey: messengerKey,
    );
  }
}