import 'pc_health_snapshot.dart';

abstract class PcHealthCollector {
  Future<PcHealthSnapshot> collect();
}
