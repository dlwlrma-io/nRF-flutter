import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mcumgr_flutter/mcumgr_flutter.dart';
import 'package:mcumgr_flutter/models/image_upload_alignment.dart';
import 'package:mcumgr_flutter/models/firmware_upgrade_mode.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(
    [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ],
  );

  runApp(const MyApp());
}

// BLE UUIDs
class BleUuids {
  static final serviceId = Uuid.parse('00001000-0000-1000-8000-00805f9b34fb');
  static final heartRateServiceId =
      Uuid.parse('0000180D-0000-1000-8000-00805f9b34fb');
  static final heartRateUuid =
      Uuid.parse('00002a37-0000-1000-8000-00805f9b34fb');
  static final spo2Uuid = Uuid.parse('00001002-0000-1000-8000-00805f9b34fb');
  static final axisXUuid = Uuid.parse('00001003-0000-1000-8000-00805f9b34fb');
  static final axisYUuid = Uuid.parse('00001004-0000-1000-8000-00805f9b34fb');
  static final axisZUuid = Uuid.parse('00001005-0000-1000-8000-00805f9b34fb');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'nRF54L15',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const IntroScreen(),
      );
}

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});
  @override
  _IntroScreenState createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final _ble = FlutterReactiveBle();
  bool _isScanning = false;
  bool _isScanFinished = false;
  bool _isConnected = false;
  final List<DiscoveredDevice> _devicesList = [];

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Future.wait([
      Permission.bluetooth.request(),
      Permission.bluetoothScan.request(),
      Permission.bluetoothConnect.request(),
      Permission.location.request(),
      Permission.storage.request(),
    ]);
  }

  void _startScan() {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _isScanFinished = false;
      _devicesList.clear();
    });

    _ble.scanForDevices(
      withServices: [],
      scanMode: ScanMode.lowLatency,
    ).listen(
      (device) {
        final deviceIndex = _devicesList.indexWhere((d) => d.id == device.id);
        setState(() {
          deviceIndex >= 0
              ? _devicesList[deviceIndex] = device
              : _devicesList.add(device);
        });
      },
      onError: (error) {
        debugPrint('BLE scan error: $error');
        setState(() {
          _isScanning = false;
          _isScanFinished = true;
        });
      },
    );

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _isScanFinished = true;
        });
      }
    });
  }

  void _connectToDevice(DiscoveredDevice device) async {
    setState(() => _isConnected = false);
    try {
      await _ble
          .connectToDevice(
            id: device.id,
            connectionTimeout: const Duration(seconds: 5),
          )
          .first;

      if (mounted) {
        setState(() => _isConnected = true);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(
              deviceId: device.id,
              deviceName: device.name,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Connection error: $e');
      if (mounted) {
        setState(() => _isConnected = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 80),
                const Icon(Icons.bluetooth, size: 100, color: Colors.blue),
                const SizedBox(height: 16),
                const Text("find and connect to a smart ring",
                    style: TextStyle(fontSize: 12)),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _startScan,
                  child: Text(_isScanning ? "Finding..." : "Find Devices"),
                ),
                const SizedBox(height: 16),
                if (_isScanning || _isScanFinished)
                  Expanded(
                    child: _devicesList.isEmpty
                        ? Center(
                            child: _isScanning
                                ? const CircularProgressIndicator()
                                : const Text("No devices found"),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: _devicesList.length,
                            itemBuilder: (_, index) => _DeviceListItem(
                              device: _devicesList[index],
                              onConnect: () =>
                                  _connectToDevice(_devicesList[index]),
                            ),
                          ),
                  ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      );
}

class _DeviceListItem extends StatelessWidget {
  final DiscoveredDevice device;
  final VoidCallback onConnect;

  const _DeviceListItem({
    required this.device,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: ListTile(
          title: Text(device.name.isEmpty ? "Unknown Device" : device.name),
          subtitle: Text(device.id),
          trailing: ElevatedButton(
            onPressed: onConnect,
            child: const Text("Connect"),
          ),
        ),
      );
}

class HomeScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;

  const HomeScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _ble = FlutterReactiveBle();
  final Map<String, String> _sensorValues = {
    'heartRate': "0 bpm",
    'spo2': "0%",
    'axisX': "0",
    'axisY': "0",
    'axisZ': "0",
  };
  final String _firmwareVersion = "v1.0.0";

  bool _isUpdatingFirmware = false;
  double _updateProgress = 0.0;
  String _updateStatus = "";

  late final Map<String, QualifiedCharacteristic> _characteristics;
  final Map<String, StreamSubscription?> _subscriptions = {};
  DeviceConnectionState _deviceState = DeviceConnectionState.disconnected;

  @override
  void initState() {
    super.initState();
    _initializeCharacteristics();
    _maintainConnection();
  }

  void _initializeCharacteristics() {
    _characteristics = {
      'heartRate': QualifiedCharacteristic(
        characteristicId: BleUuids.heartRateUuid,
        serviceId: BleUuids.heartRateServiceId,
        deviceId: widget.deviceId,
      ),
      'spo2': QualifiedCharacteristic(
        characteristicId: BleUuids.spo2Uuid,
        serviceId: BleUuids.serviceId,
        deviceId: widget.deviceId,
      ),
      'axisX': QualifiedCharacteristic(
        characteristicId: BleUuids.axisXUuid,
        serviceId: BleUuids.serviceId,
        deviceId: widget.deviceId,
      ),
      'axisY': QualifiedCharacteristic(
        characteristicId: BleUuids.axisYUuid,
        serviceId: BleUuids.serviceId,
        deviceId: widget.deviceId,
      ),
      'axisZ': QualifiedCharacteristic(
        characteristicId: BleUuids.axisZUuid,
        serviceId: BleUuids.serviceId,
        deviceId: widget.deviceId,
      ),
    };
  }

  void _maintainConnection() {
    _subscriptions['connection'] = _ble
        .connectToDevice(
      id: widget.deviceId,
      connectionTimeout: const Duration(seconds: 5),
    )
        .listen(
      (connectionState) {
        if (mounted) {
          setState(() {
            _deviceState = connectionState.connectionState;
            if (_deviceState == DeviceConnectionState.connected) {
              _startNotifications();

              Future.delayed(const Duration(milliseconds: 500), () {
                _setCurrentTime();
              });
            }
          });
        }
      },
      onError: (error) => debugPrint('Connection error: $error'),
    );
  }

  void _startNotifications() {
    // Heart rate
    _subscriptions['heartRate'] =
        _ble.subscribeToCharacteristic(_characteristics['heartRate']!).listen(
      (data) {
        if (mounted) {
          setState(() =>
              _sensorValues['heartRate'] = "${_parseHeartRate(data)} bpm");
        }
      },
      onError: (e) => debugPrint('Heart rate error: $e'),
    );

    // SpO2
    _subscriptions['spo2'] =
        _ble.subscribeToCharacteristic(_characteristics['spo2']!).listen(
      (data) {
        if (mounted) {
          setState(
              () => _sensorValues['spo2'] = "${_parseSingleByteInt(data)}%");
        }
      },
      onError: (e) => debugPrint('SpO2 error: $e'),
    );

    // Axis data
    _subscribeToAxisData('axisX');
    _subscribeToAxisData('axisY');
    _subscribeToAxisData('axisZ');
  }

  void _subscribeToAxisData(String axis) {
    _subscriptions[axis] =
        _ble.subscribeToCharacteristic(_characteristics[axis]!).listen(
      (data) {
        if (mounted) {
          setState(() => _sensorValues[axis] = _parseSignedInt16(data));
        }
      },
      onError: (e) => debugPrint('$axis error: $e'),
    );
  }

  Future<void> _performFirmwareUpdate() async {
    if (_isUpdatingFirmware) return;

    try {
      setState(() {
        _isUpdatingFirmware = true;
        _updateStatus = "Selecting firmware file...";
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['bin'],
      );

      if (result == null) {
        setState(() {
          _isUpdatingFirmware = false;
          _updateStatus = "File selection cancelled";
        });
        return;
      }

      setState(() => _updateStatus = "Reading firmware file...");

      final file = File(result.files.single.path!);
      final imageData = await file.readAsBytes();

      setState(() => _updateStatus = "Initializing update manager...");

      final managerFactory = FirmwareUpdateManagerFactory();
      final updateManager =
          await managerFactory.getUpdateManager(widget.deviceId);
      final updateStream = updateManager.setup();

      updateManager.updateStateStream?.listen(
        (event) {
          setState(() => _updateStatus = "Update state: $event");

          if (event == FirmwareUpgradeState.success) {
            setState(() {
              _isUpdatingFirmware = false;
              _updateStatus = "Update successful";
            });
          }
        },
        onDone: () async {
          await updateManager.kill();

          if (mounted) {
            setState(() {
              _isUpdatingFirmware = false;
              _updateStatus = "Update completed";
            });

            _showDialog("Firmware OTA", "The firmware update was successful.");
          }
        },
        onError: (error) async {
          await updateManager.kill();

          if (mounted) {
            setState(() {
              _isUpdatingFirmware = false;
              _updateStatus = "Update error: $error";
            });

            _showDialog("Firmware OTA", "The firmware update failed: $error");
          }
        },
      );

      updateManager.progressStream.listen((event) {
        if (mounted) {
          setState(() {
            _updateProgress = event.bytesSent / event.imageSize;
            _updateStatus =
                "Uploading: ${event.bytesSent} / ${event.imageSize} bytes";
          });
        }
      });

      updateManager.logger.logMessageStream
          .listen((log) => debugPrint(log.message));

      const configuration = FirmwareUpgradeConfiguration(
        estimatedSwapTime: Duration(seconds: 30),
        byteAlignment: ImageUploadAlignment.fourByte,
        eraseAppSettings: true,
        pipelineDepth: 1,
        firmwareUpgradeMode: FirmwareUpgradeMode.uploadOnly,
      );

      setState(() => _updateStatus = "Starting firmware upload...");

      await updateManager.updateWithImageData(
        imageData: imageData,
        configuration: configuration,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUpdatingFirmware = false;
          _updateStatus = "Update failed: $e";
        });
      }
      debugPrint('Firmware update error: $e');
    }
  }

  Future<void> _setCurrentTime() async {
    try {
      // Check if we're connected first
      if (_deviceState != DeviceConnectionState.connected) {
        debugPrint('Cannot set time: device not connected');
        return;
      }

      debugPrint('Setting current time on device...');

      // Current time characteristic
      final characteristic = QualifiedCharacteristic(
        serviceId: Uuid.parse('00001805-0000-1000-8000-00805f9b34fb'),
        characteristicId: Uuid.parse('00002A2B-0000-1000-8000-00805f9b34fb'),
        deviceId: widget.deviceId,
      );

      // Convert to bytes according to BLE Current Time format
      // Format based on BLE specification for Current Time Service

      // Fractions of a second (0-255 = 0-999ms)
      // This field represents milliseconds, but mapped to a single byte (0-255)

      // Reason for change
      // 0 = No reason for change/manual user update
      // 1 = External reference time update
      // 2 = Change of time zone
      // 3 = Change of DST (Daylight Saving Time)
      // 4-254 = Reserved values
      // 255 = Other reason

      // Get current time
      final now = DateTime.now();
      final List<int> timeBytes = [
        now.year & 0xFF,
        (now.year >> 8) & 0xFF,
        now.month,
        now.day,
        now.hour,
        now.minute,
        now.second,
        now.weekday,
        (now.millisecond * 256) ~/ 1000,
        1,
      ];

      // Write time to the device
      await _ble.writeCharacteristicWithResponse(
        characteristic,
        value: timeBytes,
      );

      debugPrint('Time set successfully: ${now.toString()}');
    } catch (e) {
      debugPrint('Error setting time: $e');
    }
  }

  String _parseHeartRate(List<int> data) {
    if (data.isEmpty) return "0";

    final flags = data[0];
    final isHeartRate16Bit = (flags & 0x01) != 0;

    if (isHeartRate16Bit && data.length >= 3) {
      return ((data[2] << 8) | data[1]).toString();
    } else if (!isHeartRate16Bit && data.length >= 2) {
      return data[1].toString();
    }
    return "0";
  }

  String _parseSingleByteInt(List<int> data) =>
      data.isNotEmpty ? data[0].toString() : "0";

  String _parseSignedInt16(List<int> data) {
    if (data.length < 2) return "0";
    return ByteData.sublistView(Uint8List.fromList(data))
        .getInt16(0, Endian.little)
        .toString();
  }

  void _disconnectAndReturn() async {
    for (final subscription in _subscriptions.values) {
      await subscription?.cancel();
    }

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const IntroScreen()),
        (_) => false,
      );
    }
  }

  void _showDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions.values) {
      subscription?.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildHeaderRow(),
              if (_isUpdatingFirmware) _buildUpdateProgressCard(),
              _buildInfoCard("BLE", [
                _buildInfoRow(
                    "name",
                    widget.deviceName.isEmpty
                        ? "Unknown Device"
                        : widget.deviceName),
                const SizedBox(height: 8),
                _buildInfoRow("mac address", widget.deviceId),
                const SizedBox(height: 8),
                _buildInfoRow("firmware version", _firmwareVersion),
              ]),
              _buildInfoCard("PPG", [
                _buildIconRow(
                    "HRM", _sensorValues['heartRate']!, Icons.favorite),
                const SizedBox(height: 8),
                _buildIconRow("SpO2", _sensorValues['spo2']!, Icons.bloodtype),
                const SizedBox(height: 8),
                _buildIconRow("R-R", "-", Icons.air),
              ]),
              _buildInfoCard("ACC (Gyro)", [
                _buildAxisRow(
                  ["X axis", "Y axis", "Z axis"],
                  [
                    _sensorValues['axisX']!,
                    _sensorValues['axisY']!,
                    _sensorValues['axisZ']!
                  ],
                ),
              ]),
              _buildInfoCard("ACC (Tap)", [
                _buildAxisRow(["Single", "Double", "Drop"], ["0", "0", "0"]),
              ]),
              _buildInfoCard("Wearable Algorithm Suite", [
                _buildInfoRow("SDNN", "not supported this version."),
                const SizedBox(height: 8),
                _buildInfoRow("RDMII", "not supported this version."),
                const SizedBox(height: 8),
                _buildInfoRow("Stress", "not supported this version."),
                const SizedBox(height: 8),
                _buildInfoRow("Sleep Quality", "not supported this version."),
              ]),
            ],
          ),
        ),
      );

  Widget _buildHeaderRow() => Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            icon: Icon(
              Icons.bluetooth,
              color: _deviceState == DeviceConnectionState.connected
                  ? Colors.blue
                  : Colors.grey,
            ),
            onPressed: _disconnectAndReturn,
          ),
          IconButton(
            icon: Icon(
              Icons.system_update,
              color: _deviceState == DeviceConnectionState.connected
                  ? Colors.blue
                  : Colors.grey,
            ),
            onPressed: _deviceState == DeviceConnectionState.connected &&
                    !_isUpdatingFirmware
                ? _performFirmwareUpdate
                : null,
          ),
        ],
      );

  Widget _buildUpdateProgressCard() => Card(
        margin: const EdgeInsets.symmetric(vertical: 10),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Firmware Update",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(_updateStatus),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: _updateProgress),
            ],
          ),
        ),
      );

  Widget _buildInfoCard(String title, List<Widget> children) => Card(
        margin: const EdgeInsets.symmetric(vertical: 10),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.black),
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      );

  Widget _buildInfoRow(String title, String value) => Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
              Text(
                value,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const Spacer(),
        ],
      );

  Widget _buildIconRow(String title, String value, IconData icon) => Row(
        children: [
          Icon(icon, size: 40, color: Colors.red),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
              Text(
                value,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      );

  Widget _buildAxisRow(List<String> axes, List<String> values) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          axes.length,
          (i) => Column(
            children: [
              Text(
                axes[i],
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
              Text(
                values[i],
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
}
