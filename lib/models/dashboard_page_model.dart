import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:my_fit/components/gyro_data_component.dart';
import 'package:my_fit/components/heart_rate_component.dart';
import 'package:my_fit/components/sleep_component.dart';
import 'package:my_fit/components/status_data_component.dart';
import 'package:my_fit/constants/shared_prefs_strings.dart';
import 'package:my_fit/models/bluetooth_model.dart';
import 'package:my_fit/utils/bluetooth_utils.dart';
import 'package:my_fit/utils/miband_utils.dart';
import 'package:my_fit/utils/shared_prefs_utils.dart';

class IdentifiedService {
  Service service;
  MiBandServices miService;

  IdentifiedService(this.service, this.miService);

  factory IdentifiedService.fromService(Service service) {
    MiBandServices miService = MiBandServices.values.firstWhere((element) =>
        element.uuid == service.id.toString().trim().toLowerCase());
    return IdentifiedService(service, miService);
  }
}

class IdentifiedCharacteristic {
  Characteristic characteristic;
  MiBandServiceCharacteristics miCharacteristic;
  QualifiedCharacteristic? qualifiedCharacteristic;

  IdentifiedCharacteristic(this.characteristic, this.miCharacteristic,
      [this.qualifiedCharacteristic]);

  factory IdentifiedCharacteristic.fromCharacteristic(
      Characteristic characteristic) {
    MiBandServiceCharacteristics miCharacteristic =
        MiBandServiceCharacteristics.values.firstWhere((element) =>
            element.uuid == characteristic.id.toString().trim().toLowerCase());
    return IdentifiedCharacteristic(characteristic, miCharacteristic);
  }
}

class DashboardPageModel extends ChangeNotifier {
  //DashboardPageModel(this.bluetoothModel);

  //final BluetoothModel bluetoothModel;
  Timer? _timer;
  final List<Widget> _components = [];
  final List<Map<String, int>> _gyroData = [];
  UnmodifiableListView<Widget> get components =>
      UnmodifiableListView(_components);

  String? _deviceId;
  String get deviceId => _deviceId ?? '';
  String batteryLevel = '';
  Stream<List<int>>? batteryStream;

  void init(BluetoothModel bluetoothModel, String deviceIdTemp) async {
    debugPrint('inside init');
    _deviceId = deviceIdTemp;
    debugPrint('model deviceId: $deviceIdTemp');
    var services = await bluetoothModel.discoverServices(deviceIdTemp);
    debugPrint('# services found: ${services.length}');

    final identifiedServices = services
        .map((e) {
          try {
            return IdentifiedService.fromService(e);
          } catch (e) {
            return null;
          }
        })
        .whereType<IdentifiedService>()
        .toList();

    for (var identifiedService in identifiedServices) {
      _components.add(Text("service: ${identifiedService.miService}"));
      for (var characteristic in identifiedService.service.characteristics) {
        try {
          final qualifiedCharacteristic = QualifiedCharacteristic(
            serviceId: identifiedService.service.id,
            characteristicId: characteristic.id,
            deviceId: deviceIdTemp,
          );
          final identifiedCharacteristic =
              IdentifiedCharacteristic.fromCharacteristic(characteristic);
          identifiedCharacteristic.qualifiedCharacteristic =
              qualifiedCharacteristic;
          print(identifiedCharacteristic.miCharacteristic);
          _components.add(
              Text("--> ${identifiedCharacteristic.miCharacteristic.name}"));
          await _handleCharacteristic(identifiedCharacteristic, bluetoothModel);
        } catch (e) {
          continue;
        }
      }
    }
    print(_components);
    notifyListeners();
  }

  _handleCharacteristic(IdentifiedCharacteristic characteristic,
      BluetoothModel bluetoothModel) async {
    if (characteristic.qualifiedCharacteristic == null) {
      return;
    }
    switch (characteristic.miCharacteristic) {
      case MiBandServiceCharacteristics.auth:
        break;
      case MiBandServiceCharacteristics.battery:
        await _handleBattery(
            characteristic.qualifiedCharacteristic!, bluetoothModel);
        break;
      case MiBandServiceCharacteristics.steps:
        break;
      case MiBandServiceCharacteristics.heartRateMeasure:
        break;
      case MiBandServiceCharacteristics.heatRateControl:
        break;
      case MiBandServiceCharacteristics.sens:
        await _handleGyro(
            characteristic.qualifiedCharacteristic!, bluetoothModel);
    }
  }

  _handleBattery(QualifiedCharacteristic batteryCharacteristic,
      BluetoothModel bluetoothModel) async {
    List<int> values =
        await bluetoothModel.getCharacteristicData(batteryCharacteristic);
    debugPrint('battery level data: ${values.toString()}');
    int batteryLevelInt = BluetoothUtils.getBatteryLevel(values);
    debugPrint('battery level: $batteryLevelInt');
    batteryLevel = batteryLevelInt.toString();
  }

  _handleGyro(QualifiedCharacteristic gyroCharacteristic,
      BluetoothModel bluetoothModel) async {
    await bluetoothModel
        .writeCharacteristic(gyroCharacteristic, [0x01, 0x03, 0x19]);
    await bluetoothModel.writeCharacteristic(gyroCharacteristic, [0x02]);

    bluetoothModel
        .subscribeToCharacteristic(gyroCharacteristic)
        .listen((event) {
      print("event!");
      _handleGyroData(event);
    });

    _timer?.cancel(); // Cancel the previous timer if it exists
    _timer = Timer.periodic(Duration(seconds: 12), (Timer t) async {
      print("pinging");
      await bluetoothModel.writeCharacteristic(gyroCharacteristic, [0x16]);
    });
  }

  void _handleGyroData(List<int> event) {
    _gyroData.addAll(BluetoothUtils.getGyro(event));
    notifyListeners();
  }
}


    // for (var service in services) {
    //   var serviceUuid = service.id;
    //   var serviceIdStr = serviceUuid.toString().trim().toLowerCase();
    //   var characteristicIds = service.characteristics.map((e) => e.id);
    //   if (serviceIdStr.contains('183e')) {
    //     // physical activity monitor service
    //     debugPrint('found physical activity monitor service');
    //     for (var characteristicId in characteristicIds) {
    //       String characteristicIdStr = characteristicId.toString().trim();
    //       if (characteristicIdStr.contains('00002b40')) {
    //         // steps
    //         final characteristic = QualifiedCharacteristic(
    //           serviceId: serviceUuid,
    //           characteristicId: characteristicId,
    //           deviceId: deviceId,
    //         );
    //         try {
    //           int goalSteps = await SharedPrefsUtils.getInt(
    //                   SharedPrefsStrings.GOAL_STEPS_KEY) ??
    //               5000;
    //           _components.insert(
    //             0,
    //             StatusDataComponent(
    //               isMi: false,
    //               goalSteps: goalSteps,
    //               statusStream:
    //                   bluetoothModel.subscribeToCharacteristic(characteristic),
    //             ),
    //           );
    //           print('components steps: $_components');
    //         } catch (err) {
    //           debugPrint('steps error');
    //           debugPrint(err.toString());
    //         }
    //       } else if (characteristicIdStr.contains('00002b41')) {
    //         // sleep instantaneous data
    //         final characteristic = QualifiedCharacteristic(
    //           serviceId: serviceUuid,
    //           characteristicId: characteristicId,
    //           deviceId: deviceId,
    //         );
    //         _components.add(SleepComponent(
    //           bluetoothModel.subscribeToCharacteristic(characteristic),
    //           isSummaryData: false,
    //         ));
    //       } else if (characteristicIdStr.contains('00002b42')) {
    //         // sleep summary data
    //         final characteristic = QualifiedCharacteristic(
    //           serviceId: serviceUuid,
    //           characteristicId: characteristicId,
    //           deviceId: deviceId,
    //         );
    //         _components.add(SleepComponent(
    //           bluetoothModel.subscribeToCharacteristic(characteristic),
    //           isSummaryData: true,
    //         ));
    //       }
    //     }
    //   } else if (serviceIdStr.contains('180d')) {
    //     // heart rate service
    //     debugPrint('found heart rate service');
    //     for (var characteristicId in characteristicIds) {
    //       String characteristicIdStr = characteristicId.toString().trim();
    //       if (characteristicIdStr.contains('00002a37')) {
    //         // heart rate measurement
    //         final characteristic = QualifiedCharacteristic(
    //           serviceId: serviceUuid,
    //           characteristicId: characteristicId,
    //           deviceId: deviceId,
    //         );
    //         // _components.add(HeartRateComponent(
    //         //     bluetoothModel.subscribeToCharacteristic(characteristic)));
    //         print('components hr: $_components');
    //       }
    //     }
    //   } else if (serviceIdStr.contains('180f')) {
    //     // battery service
    //     debugPrint('found battery service');
    //     for (var characteristicId in characteristicIds) {
    //       String characteristicIdStr = characteristicId.toString().trim();
    //       if (characteristicIdStr.contains('00002a19')) {
    //         // battery level
    //         final characteristic = QualifiedCharacteristic(
    //           serviceId: serviceUuid,
    //           characteristicId: characteristicId,
    //           deviceId: deviceId,
    //         );
    //         try {
    //           List<int> values =
    //               await bluetoothModel.getCharacteristicData(characteristic);
    //           debugPrint('battery level data: ${values.toString()}');
    //           int batteryLevelInt = BluetoothUtils.getBatteryLevel(values);
    //           debugPrint('battery level: $batteryLevelInt');
    //           batteryLevel = batteryLevelInt.toString();
    //         } catch (err) {
    //           debugPrint('battery level error');
    //           debugPrint(err.toString());
    //         }
    //       }
    //     }
    //     // } else if (serviceIdStr.contains('fee0')) {
    //   } else if (serviceIdStr == MiBandServices.hardware.uuid) {
    //     debugPrint('found mi band Hardware service');
    //     for (var characteristicId in characteristicIds) {
    //       String characteristicIdStr = characteristicId.toString().trim();
    //       if (characteristicIdStr == MiBandServiceCharacteristics.sens.uuid) {
    //         final characteristic = QualifiedCharacteristic(
    //           serviceId: serviceUuid,
    //           characteristicId: characteristicId,
    //           deviceId: deviceId,
    //         );
    //         // _components.add(GyroDataComponent(
    //         //     bluetoothModel.subscribeToCharacteristic(characteristic)));
    //         print('component gyro: $characteristic');
    //       }
    //     }
    //   } else {
    //     // debugPrint('other service: $serviceIdStr');
    //   }
    // }