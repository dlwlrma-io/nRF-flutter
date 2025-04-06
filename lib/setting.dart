import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mcumgr_flutter/mcumgr_flutter.dart';
import 'package:mcumgr_flutter/models/image_upload_alignment.dart';
import 'package:mcumgr_flutter/models/firmware_upgrade_mode.dart';

class SettingScreen extends StatefulWidget {
  final DiscoveredDevice device;

  const SettingScreen({super.key, required this.device});

  @override
  SettingScreenState createState() => SettingScreenState();
}

class SettingScreenState extends State<SettingScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: false,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Device (${widget.device.name})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                Spacer(),
                Icon(Icons.bluetooth, color: Colors.blue, size: 20),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'MAC Address',
              style: TextStyle(fontSize: 14),
            ),
            Text(
              widget.device.id,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 8),
            Text(
              'Firmware Version',
              style: TextStyle(fontSize: 14),
            ),
            Text(
              'v1.0.0',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Region',
              style: TextStyle(fontSize: 14),
            ),
            Text(
              'KOREA (KR)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _firmwareOverTheAir(String deviceId) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['bin'],
      );

      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      final imageData = await file.readAsBytes();

      final managerFactory = FirmwareUpdateManagerFactory();
      final updateManager = await managerFactory.getUpdateManager(deviceId);
      final updateStream = updateManager.setup();

      updateManager.updateStateStream?.listen(
        (event) {
          debugPrint('firmware update state: $event');

          if (event == FirmwareUpgradeState.success) {
            debugPrint('firmware update was successful.');
          }
        },
        onDone: () async {
          await updateManager.kill();
          if (mounted) {
            debugPrint('firmware update was successful.');
          }
        },
        onError: (error) async {
          await updateManager.kill();
          if (mounted) {
            debugPrint('firmware update failed: $error');
          }
        },
      );

      updateManager.progressStream.listen((event) {
        if (mounted) {
          debugPrint('firmware update: ${event.bytesSent} / ${event.imageSize} bytes.');
        }
      });

      updateManager.logger.logMessageStream.listen(
        (log) => debugPrint(log.message),
      );

      const configuration = FirmwareUpgradeConfiguration(
        estimatedSwapTime: Duration(seconds: 30),
        byteAlignment: ImageUploadAlignment.fourByte,
        eraseAppSettings: true,
        pipelineDepth: 1,
        firmwareUpgradeMode: FirmwareUpgradeMode.uploadOnly,
      );

      await updateManager.updateWithImageData(
        imageData: imageData,
        configuration: configuration,
      );
    } catch (e) {
      debugPrint('Firmware update error: $e');
    }
  }
}
