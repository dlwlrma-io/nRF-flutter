import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

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
  bool isScanning = false, isScanFinished = false, isConnected = false;
  List<Map<String, String>> devicesList = [
    {"name": "nRF54L15", "mac": "20:AB:5A:7B:AF:4B"},
    {"name": "nRF54L15", "mac": "iOS platform can't read address"},
    {"name": "nRF52832", "mac": "40:AB:5A:7B:AF:4D"},
  ];

  void startScan() {
    if (!isScanning) {
      setState(() {
        isScanning = true;
        isScanFinished = false;
      });
      Future.delayed(Duration(seconds: 5), () => setState(() => isScanFinished = true));
    }
  }

  void connectToDevice(String device) async {
    setState(() => isConnected = false);
    await Future.delayed(Duration(seconds: 1), () => setState(() => isConnected = true));
    Navigator.push(context, MaterialPageRoute(builder: (context) => HomeScreen()));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bluetooth, size: 100, color: Colors.blue),
            SizedBox(height: 16),
            Text("find and connect to a smart ring", style: TextStyle(fontSize: 12)),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: startScan,
              child: Text(isScanning ? "Scanning..." : "Scan for Devices"),
            ),
            SizedBox(height: 16),
            isScanning
                ? (isScanFinished
                ? Expanded(
              child: ListView.builder(
                itemCount: devicesList.length,
                itemBuilder: (context, index) {
                  var device = devicesList[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Text(device["name"]!),
                      subtitle: Text(device["mac"]!),
                      trailing: ElevatedButton(
                        onPressed: () => connectToDevice(device["name"]!),
                        child: Text("Connect"),
                      ),
                    ),
                  );
                },
              ),
            )
                : CircularProgressIndicator())
                : Container(),
          ],
        ),
      ),
    ),
  );
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String heartRate = "75 bpm";
  String spo2 = "98%";
  Timer? _timer;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _startSimulation();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startSimulation() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        heartRate = "${80 + _random.nextInt(21)} bpm"; // Random value between 80 and 100
        spo2 = "${90 + _random.nextInt(11)}%";       // Random value between 90 and 100
      });
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildCard("BLE", [
            buildText("name", "nRF54L15"),
            SizedBox(height: 8),
            buildText("mac address", "20:AB:5A:7B:AF:4B"),
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
            buildAxisRow(["X axis", "Y axis", "Z axis"], ["0", "0", "0"]),
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
          Text(title, style: TextStyle(fontSize: 16, color: Colors.black54)),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
}