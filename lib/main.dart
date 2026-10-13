
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';

const String notificationChannelId = 'zonesync_background';
const int notificationId = 888;

const MethodChannel dndChannel = MethodChannel('zonesync/dnd');


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();
  runApp(const ZoneSyncApp());
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    notificationChannelId,
    'ZoneSync Background Monitoring',
    description: 'Shows when ZoneSync background monitoring is active.',
    importance: Importance.low,
  );

  final notifications = FlutterLocalNotificationsPlugin();

  await notifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: zoneSyncServiceStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: notificationChannelId,
      initialNotificationTitle: 'ZoneSync',
      initialNotificationContent: 'Background monitoring is starting',
      foregroundServiceNotificationId: notificationId,
      foregroundServiceTypes: [AndroidForegroundType.location],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: zoneSyncServiceStart,
    ),
  );
}

class ZoneSyncApp extends StatelessWidget {
  const ZoneSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZoneSync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF07111F),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}


@pragma('vm:entry-point')
void zoneSyncServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: 'ZoneSync is monitoring',
      content: 'Checking your saved silent zones',
    );
  }

  Timer? timer;
  bool isChecking = false;

  service.on('stopService').listen((event) {
    timer?.cancel();
    service.stopSelf();
  });

  timer = Timer.periodic(const Duration(seconds: 15), (timer) async {
    if (isChecking) return;
    isChecking = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      final savedZones =
          prefs.getStringList('zonesync_saved_zones_v2');

      if (savedZones == null || savedZones.isEmpty) return;

      final zones = savedZones
          .map((item) =>
              Map<String, dynamic>.from(jsonDecode(item) as Map))
          .toList();

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      for (final zone in zones) {
        final name = zone['name'] as String? ?? 'Silent Zone';
        final latitude = (zone['latitude'] as num).toDouble();
        final longitude = (zone['longitude'] as num).toDouble();
        final radius = (zone['radius'] as num).toDouble();

        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          latitude,
          longitude,
        );

        final inside = distance <= radius;

        // Use a consistent key for each saved zone.
        final stateKey =
            'zonesync_bg_state_${Uri.encodeComponent(name)}';
        final wasInside = prefs.getBool(stateKey);

        if (wasInside == null || wasInside != inside) {
          await prefs.setBool(stateKey, inside);

          service.invoke('zoneStatusChanged', {
            'name': name,
            'inside': inside,
            'distance': distance,
          });

          if (service is AndroidServiceInstance) {
            service.setForegroundNotificationInfo(
              title: inside ? 'Entered: $name' : 'Exited: $name',
              content: inside
                  ? 'You are inside this zone'
                  : 'You are outside this zone',
            );
          }
        }
      }
    } catch (e, stackTrace) {
      // Log errors so we can diagnose permission or location failures.
      print('ZoneSync background monitoring error: $e');
      print(stackTrace);
    } finally {
      isChecking = false;
    }
  });
}
