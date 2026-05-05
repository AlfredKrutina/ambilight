import 'pc_health_snapshot.dart';
import 'pc_health_types.dart';

PcHealthCollector createPcHealthCollector() => _StubCollector();

class _StubCollector implements PcHealthCollector {
  @override
  Future<PcHealthSnapshot> collect() async => PcHealthSnapshot.empty;
}
