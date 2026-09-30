import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:flutter/material.dart';

class CoinLogPage extends StatelessWidget {
  const CoinLogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SimpleScaffold(
      title: '硬币日志',
      child: const Center(child: Text('暂无数据')),
    );
  }
}
