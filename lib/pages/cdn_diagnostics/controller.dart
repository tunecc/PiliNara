import 'package:PiliPlus/pages/cdn_diagnostics/model.dart';
import 'package:PiliPlus/services/cdn_diagnostics_service.dart';
import 'package:PiliPlus/services/logger.dart';
import 'package:get/get.dart';

class CdnDiagnosticsController extends GetxController {
  final RxBool isRunning = false.obs;
  final RxList<CdnTestResult> results = <CdnTestResult>[].obs;
  final RxString error = ''.obs;

  Future<void> runDiagnostics() async {
    if (isRunning.value) return;
    isRunning.value = true;
    error.value = '';
    try {
      final r = await CdnDiagnosticsService.runDiagnostics();
      results.assignAll(r);
    } catch (e) {
      logger.e('CDN diagnostics failed: $e');
      error.value = e.toString();
    } finally {
      isRunning.value = false;
    }
  }
}
