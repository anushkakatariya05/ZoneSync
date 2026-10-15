import 'package:flutter_background_service/flutter_background_service.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class ManageZonesScreen extends StatefulWidget {
  const ManageZonesScreen({super.key});

  @override
  State<ManageZonesScreen> createState() => _ManageZonesScreenState();
}

class _ManageZonesScreenState extends State<ManageZonesScreen> {
  static const Color backgroundColor = Color(0xFF07111F);
  static const Color cardColor = Color(0xFF101F33);
  static const Color blue = Color(0xFF36C5F0);
  static const Color lightText = Color(0xFFB8C7D9);

  // A new key keeps your previously saved name-only zones untouched.
  static const String storageKey = 'zonesync_saved_zones_v2';

  final List<Map<String, dynamic>> zones = [];

  final TextEditingController zoneController = TextEditingController();
  final TextEditingController radiusController =
      TextEditingController(text: '100');

  Position? currentPosition;
  bool isLoading = true;
  bool isGettingLocation = false;

  @override
  void initState() {
    super.initState();
    loadZones();
  }

  Future<void> loadZones() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedZones = prefs.getStringList(storageKey) ?? [];

      final loadedZones = savedZones
          .map((item) =>
              Map<String, dynamic>.from(jsonDecode(item) as Map))
          .toList();

      if (!mounted) return;

      setState(() {
        zones
          ..clear()
          ..addAll(loadedZones);
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load saved zones.'),
        ),
      );
    }
  }

  Future<void> saveZones() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(
      storageKey,
      zones.map((zone) => jsonEncode(zone)).toList(),
    );
  }

  Future<void> getCurrentLocation() async {
    setState(() => isGettingLocation = true);

    try {
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw Exception('Turn on Location/GPS on your phone.');
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission was not granted.');
      }

      final position = await Geolocator.getCurrentPosition();

      if (!mounted) return;

      setState(() => currentPosition = position);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Location captured: '
            '${position.latitude.toStringAsFixed(5)}, '
            '${position.longitude.toStringAsFixed(5)}',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => isGettingLocation = false);
      }
    }
  }
  
static const MethodChannel _backgroundDnd =
    MethodChannel('zonesync/dnd_background');

Future<bool> updateDndForCurrentLocation(Position position) async {
  if (zones.isEmpty) return false;

  bool anyInside = false;

  for (final zone in zones) {
    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      (zone['latitude'] as num).toDouble(),
      (zone['longitude'] as num).toDouble(),
    );

    final radius = (zone['radius'] as num).toDouble();

    if (distance <= radius) {
      anyInside = true;
      break;
    }
  }

  final result = await _backgroundDnd.invokeMethod<bool>(
    anyInside ? 'setDndOn' : 'setDndOff',
  );

  if (result != true) {
    showMessage(
      'Could not update DND. Check DND access and native plugin registration.',
    );
    return false;
  }

  return anyInside;
}

  
Future<void> checkZoneStatus() async {
  if (zones.isEmpty) {
    showMessage('Please save a Silent Zone first.');
    return;
  }

  try {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );

    if (!mounted) return;

    bool anyInside = false;
    final messages = <String>[];

    for (final zone in zones) {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        (zone['latitude'] as num).toDouble(),
        (zone['longitude'] as num).toDouble(),
      );

      final inside = distance <= (zone['radius'] as num).toDouble();
      if (inside) anyInside = true;

      messages.add(
        "${zone['name']}: ${inside ? 'INSIDE ZONE' : 'OUTSIDE ZONE'}"
        '\nDistance: ${distance.toStringAsFixed(1)} m',
      );
    }

    final result = await _backgroundDnd.invokeMethod<bool>(
      anyInside ? 'setDndOn' : 'setDndOff',
    );

    if (!mounted) return;

    showMessage(
      '${messages.join('\n\n')}\n\n'
      '${result == true
          ? (anyInside ? 'DND enabled.' : 'Previous DND mode restored.')
          : 'DND update failed. Check native plugin registration and access.'}',
    );
  } on PlatformException catch (error) {
    if (!mounted) return;
    showMessage('DND error: ${error.message ?? error.code}');
  } on MissingPluginException {
    if (!mounted) return;
    showMessage(
      'Background DND plugin is not registered. Check Android plugin setup.',
    );
  } catch (error) {
    if (!mounted) return;
    showMessage('Could not check location: $error');
  }
}



  Future<void> addZone() async {
    final name = zoneController.text.trim();
    final radius = double.tryParse(radiusController.text.trim());

    if (name.isEmpty) {
      showMessage('Enter a zone name first.');
      return;
    }

    if (radius == null || !radius.isFinite ||
        radius < 10 || radius > 10000) {
      showMessage('Radius must be between 10 and 10000 metres.');
      return;
    }

    if (currentPosition == null) {
      showMessage('Tap Get Current Location before saving.');
      return;
    }

    if (zones.any((zone) =>
        (zone['name'] as String).toLowerCase() ==
        name.toLowerCase())) {
      showMessage('This zone name already exists.');
      return;
    }

    final newZone = <String, dynamic>{
      'name': name,
      'latitude': currentPosition!.latitude,
      'longitude': currentPosition!.longitude,
      'radius': radius,
    };

    setState(() {
      zones.add(newZone);
      zoneController.clear();
      currentPosition = null;
    });

    try {
      await saveZones();
    } catch (_) {
      if (!mounted) return;

      setState(() => zones.remove(newZone));
      showMessage('Could not save zone. Please try again.');
      return;
    }

    if (!mounted) return;

    FocusScope.of(context).unfocus();
showMessage('$name saved. Checking your current zone status...');

try {
  final position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 20),
    ),
  );

  if (!mounted) return;
  await updateDndForCurrentLocation(position);
} catch (error) {
  if (mounted) {
    showMessage('Zone saved, but DND could not be updated: $error');
  }
}
  }

  Future<void> deleteZone(int index) async {
    final removedZone = zones[index];

    setState(() => zones.removeAt(index));

    try {
      await saveZones();
    } catch (_) {
      if (!mounted) return;

      setState(() => zones.insert(index, removedZone));
      showMessage('Could not delete zone. Please try again.');
      return;
    }

    if (!mounted) return;

    showMessage('${removedZone['name']} deleted.');
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    zoneController.dispose();
    radiusController.dispose();
    super.dispose();
  }

  
@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: backgroundColor,
    appBar: AppBar(
      backgroundColor: backgroundColor,
      foregroundColor: Colors.white,
      elevation: 0,
      title: const Text(
        'Manage Silent Zones',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Create your quiet spaces',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Save places where you want fewer interruptions.',
                  style: TextStyle(color: lightText, fontSize: 14),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: zoneController,
                  style: const TextStyle(color: Colors.white),
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: 'Zone name, e.g. College Library',
                    hintStyle: const TextStyle(color: lightText),
                    filled: true,
                    fillColor: cardColor,
                    prefixIcon: const Icon(
                      Icons.location_on_outlined,
                      color: blue,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: radiusController,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Zone radius (metres)',
                    labelStyle: const TextStyle(color: lightText),
                    helperText: 'Choose 10–10000 metres',
                    helperStyle: const TextStyle(color: lightText),
                    filled: true,
                    fillColor: cardColor,
                    prefixIcon: const Icon(
                      Icons.radar,
                      color: blue,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: isGettingLocation
                        ? null
                        : getCurrentLocation,
                    icon: isGettingLocation
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.my_location),
                    label: Text(
                      isGettingLocation
                          ? 'Getting Location...'
                          : 'Get Current Location',
                    ),
                  ),
                ),

                if (currentPosition != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Latitude: ${currentPosition!.latitude.toStringAsFixed(5)}\n'
                    'Longitude: ${currentPosition!.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(
                      color: lightText,
                      height: 1.5,
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : addZone,
                    icon: const Icon(Icons.add),
                    label: const Text('Save Silent Zone'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blue,
                      foregroundColor: backgroundColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: checkZoneStatus,
                    icon: const Icon(Icons.radar),
                    label: const Text('Check Zone Status'),
                  ),
                ),
                
const SizedBox(height: 10),

SizedBox(
  width: double.infinity,
  height: 50,
  child: ElevatedButton.icon(
    onPressed: () async {
      if (zones.isEmpty) {
        showMessage('Please save a Silent Zone first.');
        return;
      }

      final service = FlutterBackgroundService();
      final running = await service.isRunning();

      if (!running) {
        await service.startService();
      }

      if (mounted) {
        showMessage('Background monitoring requested.');
      }
    },
    icon: const Icon(Icons.play_arrow),
    label: const Text('Start Background Monitoring'),
  ),
),

const SizedBox(height: 10),

SizedBox(
  width: double.infinity,
  height: 50,
  child: OutlinedButton.icon(
    onPressed: () async {
      FlutterBackgroundService().invoke('stopService');

      if (mounted) {
        showMessage('Stop monitoring requested.');
      }
    },
    icon: const Icon(Icons.stop),
    label: const Text('Stop Monitoring'),
  ),
),

                const SizedBox(height: 24),

                Text(
                  'Your Zones (${zones.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                if (isLoading)
                  const Center(
                    child: CircularProgressIndicator(color: blue),
                  )
                else if (zones.isEmpty)
                  const Text(
                    'No zones saved yet.',
                    style: TextStyle(color: lightText),
                  )
                else
                  ...zones.asMap().entries.map((entry) {
                    final index = entry.key;
                    final zone = entry.value;

                    return Card(
                      color: cardColor,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const Icon(
                          Icons.location_on,
                          color: blue,
                        ),
                        title: Text(
                          zone['name'] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          'Lat: ${(zone['latitude'] as num).toStringAsFixed(5)}\n'
                          'Lng: ${(zone['longitude'] as num).toStringAsFixed(5)}\n'
                          'Radius: ${zone['radius']} m',
                          style: const TextStyle(
                            color: lightText,
                            height: 1.5,
                          ),
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          tooltip: 'Delete zone',
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => deleteZone(index),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
}