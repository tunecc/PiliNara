import 'package:PiliPlus/pages/cdn_diagnostics/controller.dart';
import 'package:PiliPlus/services/cdn_diagnostics_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CdnDiagnosticsPage extends StatefulWidget {
  const CdnDiagnosticsPage({super.key});
  @override
  State<CdnDiagnosticsPage> createState() => _CdnDiagnosticsPageState();
}

class _CdnDiagnosticsPageState extends State<CdnDiagnosticsPage> {
  late final CdnDiagnosticsController _ctrl = Get.put(CdnDiagnosticsController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CDN 测速诊断'),
        actions: [
          Obx(() => _ctrl.isRunning.value
              ? const Padding(padding: EdgeInsets.only(right: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
              : IconButton(icon: const Icon(Icons.play_arrow), onPressed: _ctrl.runDiagnostics)),
        ],
      ),
      body: Obx(() {
        if (_ctrl.error.value.isNotEmpty) {
          return Center(child: Text(_ctrl.error.value, style: TextStyle(color: Theme.of(context).colorScheme.error)));
        }
        if (_ctrl.results.isEmpty && !_ctrl.isRunning.value) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.speed_outlined, size: 48),
            const SizedBox(height: 16),
            const Text('点击右上角按钮开始测速'),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _ctrl.runDiagnostics, child: const Text('开始诊断')),
          ]));
        }
        return RefreshIndicator(
          onRefresh: _ctrl.runDiagnostics,
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _ctrl.results.length,
            itemBuilder: (context, index) {
              final r = _ctrl.results[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(r.success ? Icons.check_circle : Icons.error, color: r.success ? Colors.green : Colors.red),
                  title: Text(r.cdnName),
                  subtitle: Text(r.success
                      ? '${(r.throughputMbps ?? 0).toStringAsFixed(1)} Mbps · TTFB ${r.ttfbMs ?? 0}ms · DNS ${r.dnsMs ?? 0}ms'
                      : r.errorMessage ?? 'Unknown error'),
                  trailing: r.success ? Text('${(r.throughputMbps ?? 0).toStringAsFixed(1)}
Mbps', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium) : null,
                ),
              );
            },
          ),
        );
      }),
    );
  }
}
