import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'nRF54L15',
    theme: ThemeData(primarySwatch: Colors.blue),
    home: IntroScreen(),
  );
}

class IntroScreen extends StatefulWidget {
  @override
  _IntroScreenState createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final _ble = FlutterReactiveBle();
  bool isScanning = false, isScanFinished = false, isConnected = false;
  List<DiscoveredDevice> devicesList = [];

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.bluetooth.request();
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.location.request();
  }

  void startScan() {
    if (!isScanning) {
      setState(() {
        isScanning = true;
        isScanFinished = false;
        devicesList.clear();
      });

      _ble.scanForDevices(
        withServices: [],
        scanMode: ScanMode.lowLatency,
      ).listen((device) {
        final deviceIndex = devicesList.indexWhere((d) => d.id == device.id);
        setState(() {
          if (deviceIndex >= 0) {
            devicesList[deviceIndex] = device;
          } else {
            devicesList.add(device);
          }
        });
      }, onError: (Object error) {
        print('BLE scan error: $error');
        setState(() {
          isScanning = false;
          isScanFinished = true;
        });
      });

      Future.delayed(Duration(seconds: 5), () {
        setState(() {
          isScanning = false;
          isScanFinished = true;
        });
      });
    }
  }

  void connectToDevice(DiscoveredDevice device) async {
    setState(() => isConnected = false);
    try {
      await _ble.connectToDevice(
        id: device.id,
        connectionTimeout: const Duration(seconds: 5),
      ).first;
      setState(() => isConnected = true);
      Navigator.push(
        context, 
        MaterialPageRoute(
          builder: (context) => HomeScreen(deviceId: device.id, deviceName: device.name)
        )
      );
    } catch (e) {
      print('Connection error: $e');
      setState(() => isConnected = false);
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
            SizedBox(height: 80),
            Icon(Icons.bluetooth, size: 100, color: Colors.blue),
            SizedBox(height: 16),
            Text("find and connect to a smart ring", style: TextStyle(fontSize: 12)),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: startScan,
              child: Text(isScanning ? "Finding..." : "Find for Devices"),
            ),
            SizedBox(height: 16),
            isScanning || isScanFinished
                ? Expanded(
                    child: devicesList.isEmpty
                        ? Center(
                            child: isScanning
                                ? CircularProgressIndicator()
                                : Text("No devices found"))
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: devicesList.length,
                            itemBuilder: (context, index) {
                              var device = devicesList[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: ListTile(
                                  title: Text(device.name.isEmpty 
                                    ? "Unknown Device" 
                                    : device.name),
                                  subtitle: Text(device.id),
                                  trailing: ElevatedButton(
                                    onPressed: () => connectToDevice(device),
                                    child: Text("Connect"),
                                  ),
                                ),
                              );
                            },
                          ),
                  )
                : Container(),
              SizedBox(height: 80),
          ],
        ),
      ),
    ),
  );
}

class HomeScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;

  HomeScreen({required this.deviceId, required this.deviceName});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String heartRate = "0";  // Default value for heart rate
  String spo2 = "0";       // Default value for SpO2
  String axisX = "0";      // Default value for axis X
  String axisY = "0";      // Default value for axis Y
  String axisZ = "0";      // Default value for axis Z

  final _ble = FlutterReactiveBle();
  
  // Define the UUIDs for the characteristics
  late QualifiedCharacteristic spo2Characteristic;
  late QualifiedCharacteristic axisXCharacteristic;
  late QualifiedCharacteristic axisYCharacteristic;
  late QualifiedCharacteristic axisZCharacteristic;
  late QualifiedCharacteristic heartRateCharacteristic;
  
  // Stream subscriptions for notifications
  StreamSubscription? _connectionStream;
  StreamSubscription? _spo2Subscription;
  StreamSubscription? _axisXSubscription;
  StreamSubscription? _axisYSubscription;
  StreamSubscription? _axisZSubscription;
  StreamSubscription? _heartRateSubscription;
 
  DeviceConnectionState _deviceState = DeviceConnectionState.disconnected;
 
  @override
  void initState() {
    super.initState();
    _maintainConnection();
  }

  void _maintainConnection() async {
    _connectionStream = _ble.connectToDevice(
      id: widget.deviceId,
      connectionTimeout: const Duration(seconds: 5),
    ).listen(
      (connectionState) {
        if (connectionState.connectionState == DeviceConnectionState.connected) {
          _deviceState = connectionState.connectionState;
          _startNotifications();
        }
        print('Connection state: $connectionState');
      },
      onError: (Object error) {
        print('Connection error: $error');
      },
    );
  }

  void _startNotifications() {
    // Define the UUIDs for the characteristics
    final heartRateUuid = Uuid.parse('00002a37-0000-1000-8000-00805f9b34fb');
    final spo2Uuid = Uuid.parse('00001002-0000-1000-8000-00805f9b34fb');
    final axisXUuid = Uuid.parse('00001003-0000-1000-8000-00805f9b34fb');
    final axisYUuid = Uuid.parse('00001004-0000-1000-8000-00805f9b34fb');
    final axisZUuid = Uuid.parse('00001005-0000-1000-8000-00805f9b34fb');

    // Initialize the characteristics
    spo2Characteristic = QualifiedCharacteristic(
      characteristicId: spo2Uuid,
      serviceId: Uuid.parse('00001000-0000-1000-8000-00805f9b34fb'),
      deviceId: widget.deviceId,
    );
    
    axisXCharacteristic = QualifiedCharacteristic(
      characteristicId: axisXUuid,
      serviceId: Uuid.parse('00001000-0000-1000-8000-00805f9b34fb'),
      deviceId: widget.deviceId,
    );

    axisYCharacteristic = QualifiedCharacteristic(
      characteristicId: axisYUuid,
      serviceId: Uuid.parse('00001000-0000-1000-8000-00805f9b34fb'),
      deviceId: widget.deviceId,
    );
    
    axisZCharacteristic = QualifiedCharacteristic(
      characteristicId: axisZUuid,
      serviceId: Uuid.parse('00001000-0000-1000-8000-00805f9b34fb'),
      deviceId: widget.deviceId,
    );

    heartRateCharacteristic = QualifiedCharacteristic(
      characteristicId: heartRateUuid,
      serviceId: Uuid.parse('0000180D-0000-1000-8000-00805f9b34fb'),
      deviceId: widget.deviceId,
    );

    // Subscribe to Heart Rate characteristic notifications
    _heartRateSubscription = _ble.subscribeToCharacteristic(heartRateCharacteristic).listen(
      (data) {
        setState(() => heartRate = "${_parseHeartRate(data)} bpm");
      },
      onError: (e) {
        print('Error subscribing to Heart Rate characteristic: $e');
      },
    );

    // Subscribe to notifications for each characteristic
    _spo2Subscription = _ble.subscribeToCharacteristic(spo2Characteristic).listen(
      (data) {
        setState(() => spo2 = "${_parseSingleByteInt(data)}%");
      },
      onError: (e) {
        print('Error subscribing to SpO2 characteristic: $e');
      },
    );

    _axisXSubscription = _ble.subscribeToCharacteristic(axisXCharacteristic).listen(
      (data) {
        setState(() => axisX = _parseSignedInt16(data));
      },
      onError: (e) {
        print('Error subscribing to axis X characteristic: $e');
      },
    );

    _axisYSubscription = _ble.subscribeToCharacteristic(axisYCharacteristic).listen(
      (data) {
        setState(() => axisY = _parseSignedInt16(data));
      },
      onError: (e) {
        print('Error subscribing to axis Y characteristic: $e');
      },
    );

    _axisZSubscription = _ble.subscribeToCharacteristic(axisZCharacteristic).listen(
      (data) {
        setState(() => axisZ = _parseSignedInt16(data));
      },
      onError: (e) {
        print('Error subscribing to axis Z characteristic: $e');
      },
    );
  }

  String _parseHeartRate(List<int> data) {
    if (data.isEmpty) return "0";

    int flags = data[0];
    bool isHeartRate16Bit = (flags & 0x01) != 0;

    int heartRate;
    if (isHeartRate16Bit && data.length >= 3) {
      heartRate = (data[2] << 8) | data[1];
    } else if (!isHeartRate16Bit && data.length >= 2) {
      heartRate = data[1];
    } else {
      return "Invalid Data";
    }

    return "$heartRate";
  }

  String _parseSingleByteInt(List<int> data) {
    return data.isNotEmpty ? data[0].toString() : "0";
  }

  String _parseSignedInt16(List<int> data) {
    if (data.length < 2) return "0";
    return ByteData.sublistView(Uint8List.fromList(data)).getInt16(0, Endian.little).toString();
  }

  @override
  void dispose() {
    _connectionStream?.cancel();
    _spo2Subscription?.cancel();
    _axisXSubscription?.cancel();
    _axisYSubscription?.cancel();
    _axisZSubscription?.cancel();
    _heartRateSubscription?.cancel();  // Cancel Heart Rate subscription
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Spacer(flex: 1),
              IconButton(
                icon: Icon(Icons.bluetooth, color: _deviceState == DeviceConnectionState.connected ? Colors.blue : Colors.grey),
                onPressed: _disconnectAndReturn,
              ),
            ],
          ),
          buildCard("BLE", [
            buildText("name", widget.deviceName.isEmpty ? "Unknown Device" : widget.deviceName),
            SizedBox(height: 8),
            buildText("mac address", widget.deviceId),
            SizedBox(height: 8),
            buildText("firmware version", "1.0.0"),
          ]),
          buildCard("PPG", [
            buildTextWithIcon("HRM", heartRate, Icons.favorite),
            SizedBox(height: 8),
            buildTextWithIcon("SpO2", spo2, Icons.bloodtype),
            SizedBox(height: 8),
            buildTextWithIcon("R-R", "0", Icons.air),
          ]),
          buildCard("ACC (Gyro)", [
            buildAxisRow(["X axis", "Y axis", "Z axis"], [axisX, axisY, axisZ]),
          ]),
          buildCard("Wearable Algorithm Suite", [
            buildText("SDNN", "not supported this version."),
            SizedBox(height: 8),
            buildText("RDMII", "not supported this version."),
            SizedBox(height: 8),
            buildText("Stress", "not supported this version."),
            SizedBox(height: 8),
            buildText("Sleep Quality", "not supported this version."),
          ]),
        ],
      ),
    ),
  );

  Widget buildCard(String title, List<Widget> children) => Card(
    margin: const EdgeInsets.symmetric(vertical: 10),
    elevation: 4,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Spacer(),
              IconButton(icon: Icon(Icons.settings, color: Colors.black), onPressed: () {}),
            ],
          ),
          SizedBox(height: 16),
          ...children,
        ],
      ),
    ),
  );

  Widget buildText(String title, String value) => Row(
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 16, color: Colors.black54)
          ),
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis
          ),
        ],
      ),
      Spacer(),
    ],
  );

  Widget buildTextWithIcon(String title, String value, IconData icon) => Row(
    children: [
      Icon(icon, size: 40, color: Colors.red),
      SizedBox(width: 20),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 16, color: Colors.black54)),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),  
    ],
  );

  Widget buildAxisRow(List<String> axes, List<String> values) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: List.generate(axes.length, (i) {
      return Column(
        children: [
          Text(axes[i], style: TextStyle(fontSize: 16, color: Colors.black54)),
          Text(values[i], style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      );
    }),
  );

  void _disconnectAndReturn() async {
    await _connectionStream?.cancel();  // BLE 연결 해제
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => IntroScreen()), 
      (Route<dynamic> route) => false,
    );
  }
}
