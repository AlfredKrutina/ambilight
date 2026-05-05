import 'pc_health_types.dart';

export 'pc_health_types.dart';

import 'pc_health_collector_stub.dart'
    if (dart.library.io) 'pc_health_collector_io.dart' as impl;

/// Na webu vrací prázdné hodnoty; na VM/desktopu platformní sběr.
PcHealthCollector createPcHealthCollector() => impl.createPcHealthCollector();
