import 'package:my_fit/models/bluetooth_model.dart';

enum MiBandServices {
  hardware(uuid: '0000fee0-0000-1000-8000-00805f9b34fb'),
  main(uuid: '0000fee1-0000-1000-8000-00805f9b34fb');

  final String uuid;

  const MiBandServices({required this.uuid});
}

enum MiBandServiceCharacteristics {
  auth(uuid: '00000009-0000-3512-2118-0009af100700'),
  battery(uuid: '00000006-0000-3512-2118-0009af100700'),
  steps(uuid: '00000007-0000-3512-2118-0009af100700'),
  heartRate(uuid: '00002a37-0000-1000-8000-00805f9b34fb'),
  sens(uuid: '00000001–0000–3512–2118–0009af100700');

  final String uuid;

  const MiBandServiceCharacteristics({required this.uuid});
}

class MiBandDataSource {
  final MiBandServices service;
  final MiBandServiceCharacteristics characteristic;

  const MiBandDataSource({
    required this.service,
    required this.characteristic,
  });
}

const gyroscopeService = MiBandDataSource(
    service: MiBandServices.hardware,
    characteristic: MiBandServiceCharacteristics.sens);

const notifierDescriptorHandle = 0x2902;
