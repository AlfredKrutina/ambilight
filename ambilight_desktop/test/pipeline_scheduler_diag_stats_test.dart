import 'package:ambilight_desktop/application/pipeline_diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PipelineSchedulerDiagStats reset clears counters', () {
    PipelineSchedulerDiagStats.distributeCalls = 7;
    PipelineSchedulerDiagStats.resetWindow();
    expect(PipelineSchedulerDiagStats.distributeCalls, 0);
    expect(PipelineSchedulerDiagStats.noopTickSmartLightsOnly, 0);
    expect(PipelineSchedulerDiagStats.eagerFlushFromIsolate, 0);
  });

  test(
    'PipelineSchedulerDiagStats stale seq does not record when diagnostics on',
    () {
      PipelineDiagCaptureTimeline.markCapture();
      PipelineSchedulerDiagStats.resetWindow();
      PipelineSchedulerDiagStats.markScreenSubmit(2);
      PipelineSchedulerDiagStats.recordIsolateOutForSubmit(1);
      expect(PipelineSchedulerDiagStats.captureToIsolateOutSamples, 0);
      PipelineSchedulerDiagStats.markScreenSubmit(3);
      PipelineSchedulerDiagStats.recordIsolateOutForSubmit(3);
      expect(PipelineSchedulerDiagStats.captureToIsolateOutSamples, 1);
    },
    skip: !const bool.fromEnvironment('AMBI_PIPELINE_DIAGNOSTICS', defaultValue: false),
  );

  test('PipelineSchedulerDiagStats: no capture samples without diagnostics flag', () {
    if (const bool.fromEnvironment('AMBI_PIPELINE_DIAGNOSTICS', defaultValue: false)) {
      return;
    }
    PipelineSchedulerDiagStats.resetWindow();
    PipelineSchedulerDiagStats.markScreenSubmit(3);
    PipelineSchedulerDiagStats.recordIsolateOutForSubmit(3);
    expect(PipelineSchedulerDiagStats.captureToIsolateOutSamples, 0);
  });
}
