import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'manage_zones_screen.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isSilentModeEnabled = false;
  
Future<void> openDndSettings() async {
  try {
    await const MethodChannel('zonesync/dnd')
        .invokeMethod('requestDndAccess');
  } on PlatformException catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not open DND settings: ${e.message}'),
      ),
    );
  } on MissingPluginException {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please rebuild the app and try again.'),
      ),
    );
  }
}

Future<void> toggleSilentMode(bool value) async {
  try {
    if (value) {
      final locationEnabled = await Geolocator.isLocationServiceEnabled();
      if (!locationEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable Location on your phone.')),
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission is required.')),
        );
        return;
      }

      // Start the configured background monitoring service.
      await FlutterBackgroundService().startService();

      if (!mounted) return;
      setState(() => isSilentModeEnabled = true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silent Mode enabled. Zone monitoring started.'),
        ),
      );
    } else {
      // Stop monitoring. Native code should restore DND before this
      // service is stopped if ZoneSync previously enabled it.
      try {
        await const MethodChannel('zonesync/dnd_background')
            .invokeMethod<bool>('setDndOff');
      } on PlatformException catch (e) {
        debugPrint('Could not restore DND: ${e.message}');
      } on MissingPluginException {
        debugPrint('Background DND plugin is not registered.');
      }

      FlutterBackgroundService().invoke('stopService');

      if (!mounted) return;
      setState(() => isSilentModeEnabled = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silent Mode disabled.')),
      );
    }
  } on PlatformException catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not change Silent Mode: ${e.message}')),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not start monitoring: $e')),
    );
  }
}


  static const Color backgroundColor = Color(0xFF07111F);
  static const Color cardColor = Color(0xFF111E30);
  static const Color blue = Color(0xFF00C8FF);
  static const Color lightText = Color(0xFFB8C7D9);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: blue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: blue.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Icon(
                      Icons.notifications_active_outlined,
                      color: blue,
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'ZoneSync',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Settings coming soon'),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.settings_outlined,
                      color: Colors.white,
                      size: 27,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 35),

              // Welcome section
              const Text(
                'Welcome back!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Manage your silent zones effortlessly.',
                style: TextStyle(
                  color: lightText,
                  fontSize: 15,
                ),
              ),

              const SizedBox(height: 30),

              // Location status card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: blue.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          height: 45,
                          width: 45,
                          decoration: BoxDecoration(
                            color: blue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.location_on_outlined,
                            color: blue,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Location Status',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Not tracking yet',
                                style: TextStyle(
                                  color: lightText,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Inactive',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 12),
                    const Text(
                      'Your location is not being monitored.',
                      style: TextStyle(
                        color: lightText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Silent mode card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: blue.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: blue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.volume_off_outlined,
                        color: blue,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Silent Mode',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Manual control',
                            style: TextStyle(
                              color: lightText,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: isSilentModeEnabled,
                      activeThumbColor: blue,
                      onChanged: toggleSilentMode,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Manage zones button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ManageZonesScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blue,
                    foregroundColor: backgroundColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.location_on_outlined),
                  label: const Text(
                    'Manage Silent Zones',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
           const SizedBox(height: 12),   
SizedBox(
  width: double.infinity,
  height: 55,
  child: OutlinedButton.icon(
    onPressed: openDndSettings,
    style: OutlinedButton.styleFrom(
      foregroundColor: blue,
      side: const BorderSide(color: blue),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
    ),
    icon: const Icon(Icons.do_not_disturb_on_outlined),
    label: const Text(
      'Grant DND Access',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    ),
  ),
),

const SizedBox(height: 20),

              const SizedBox(height: 25),
              
              // Footer
              const Center(
                child: Text(
                  'Stay focused. Stay connected.',
                  style: TextStyle(
                    color: lightText,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}