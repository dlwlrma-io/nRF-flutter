import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SensorScreen extends StatefulWidget {
  final DiscoveredDevice device;

  const SensorScreen({super.key, required this.device});

  @override
  SensorScreenState createState() => SensorScreenState();
}

class SensorScreenState extends State<SensorScreen> {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  final Map<String, StreamSubscription?> _subscriptions = {};
  late final Map<String, QualifiedCharacteristic> _characteristics;

  int _x = 0;
  int _y = 0;
  int _z = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions.values) {
      subscription?.cancel();
    }
    super.dispose();
  }

  void _init() async {
    _characteristics = {
      'x': QualifiedCharacteristic(
        characteristicId: Uuid.parse('0000190E-0000-1000-8000-00805f9b34fb'),
        serviceId: Uuid.parse('00001902-0000-1000-8000-00805f9b34fb'),
        deviceId: widget.device.id,
      ),
      'y': QualifiedCharacteristic(
        characteristicId: Uuid.parse('0000190F-0000-1000-8000-00805f9b34fb'),
        serviceId: Uuid.parse('00001902-0000-1000-8000-00805f9b34fb'),
        deviceId: widget.device.id,
      ),
      'z': QualifiedCharacteristic(
        characteristicId: Uuid.parse('00001910-0000-1000-8000-00805f9b34fb'),
        serviceId: Uuid.parse('00001902-0000-1000-8000-00805f9b34fb'),
        deviceId: widget.device.id,
      ),
    };

    _subscriptions['x'] = _ble.subscribeToCharacteristic(_characteristics['x']!).listen(
      (data) => setState(() =>
          _x = ByteData.sublistView(Uint8List.fromList(data)).getInt16(0, Endian.little)),
      onError: (e) => debugPrint('$e'),
    );

    _subscriptions['y'] = _ble.subscribeToCharacteristic(_characteristics['y']!).listen(
      (data) => setState(() =>
          _y = ByteData.sublistView(Uint8List.fromList(data)).getInt16(0, Endian.little)),
      onError: (e) => debugPrint('$e'),
    );

    _subscriptions['z'] = _ble.subscribeToCharacteristic(_characteristics['z']!).listen(
      (data) => setState(() =>
          _z = ByteData.sublistView(Uint8List.fromList(data)).getInt16(0, Endian.little)),
      onError: (e) => debugPrint('$e'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensor'),
        centerTitle: false,
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(FontAwesomeIcons.microchip, color: Colors.black, size: 20),
            title: const Text('X axis', style: TextStyle(fontSize: 14)),
            trailing: Text(
              '$_x',
              style: const TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Divider(),
          ),
          ListTile(
            leading: const Icon(FontAwesomeIcons.microchip, color: Colors.black, size: 20),
            title: const Text('Y axis', style: TextStyle(fontSize: 14)),
            trailing: Text(
              '$_y',
              style: const TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Divider(),
          ),
          ListTile(
            leading: const Icon(FontAwesomeIcons.microchip, color: Colors.black, size: 20),
            title: const Text('Z axis', style: TextStyle(fontSize: 14)),
            trailing: Text(
              '$_z',
              style: const TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Divider(),
          ),
          ListTile(
            leading: const Icon(Icons.touch_app, color: Colors.black, size: 20),
            title: const Text('Tap', style: TextStyle(fontSize: 14)),
            trailing: const Text(
              '0',
              style: TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Divider(),
          ),
          ListTile(
            leading: const Icon(Icons.directions_run, color: Colors.black, size: 20),
            title: const Text('Activity', style: TextStyle(fontSize: 14)),
            trailing: const Text(
              'Idle',
              style: TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Divider(),
          ),
          ListTile(
            leading: const Icon(FontAwesomeIcons.shoePrints, color: Colors.black, size: 18),
            title: const Text('Step', style: TextStyle(fontSize: 14)),
            trailing: const Text(
              '0',
              style: TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Divider(),
          ),
          ListTile(
            leading: const Icon(Icons.warning, color: Colors.orange, size: 20),
            title: const Text('Freefall Alarm', style: TextStyle(fontSize: 14)),
            trailing: const Text(
              '-',
              style: TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Divider(),
          ),
          ListTile(
            leading: const Icon(Icons.thermostat, color: Colors.red, size: 20),
            title: const Text('Temperature', style: TextStyle(fontSize: 14)),
            trailing: const Text(
              '-',
              style: TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Divider(),
          ),
          ListTile(
            leading: const Icon(Icons.battery_full, color: Colors.black, size: 20),
            title: const Text('Battery', style: TextStyle(fontSize: 14)),
            trailing: const Text(
              '-',
              style: TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
