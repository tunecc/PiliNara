import 'dart:async';
import 'package:PiliPlus/services/douyin/douyin_message_service.dart';
import 'package:flutter/material.dart';

class DouyinChatPage extends StatefulWidget {
  final String conversationId, peerName;
  const DouyinChatPage({super.key, required this.conversationId, required this.peerName});
  @override State<DouyinChatPage> createState() => _DouyinChatPageState();
}

class _DouyinChatPageState extends State<DouyinChatPage> {
  final _msgs = <DouyinMessage>[]; final _inputCtrl = TextEditingController(); final _scrollCtrl = ScrollController();
  bool _sending = false; StreamSubscription? _sub;

  @override void initState() { super.initState(); _load();
    _sub = DouyinMessageService.startPolling(widget.conversationId).listen((m) { setState(() { _msgs..clear()..addAll(m); }); _scrollBottom(); }); }

  Future<void> _load() async { _msgs.clear(); _msgs.addAll(await DouyinMessageService.getMessages(widget.conversationId)); setState(() {}); _scrollBottom(); }

  Future<void> _send() async {
    final t = _inputCtrl.text.trim(); if (t.isEmpty || _sending) return;
    setState(() => _sending = true);
    if (await DouyinMessageService.sendMessage(conversationId: widget.conversationId, content: t)) _inputCtrl.clear();
    setState(() => _sending = false);
  }

  void _scrollBottom() { WidgetsBinding.instance.addPostFrameCallback((_) { if (_scrollCtrl.hasClients) _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut); }); }

  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text(widget.peerName)), body: Column(children: [
      Expanded(child: ListView.builder(controller: _scrollCtrl, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), itemCount: _msgs.length,
        itemBuilder: (_, i) { final m = _msgs[i]; return Align(alignment: m.isSelf ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
            decoration: BoxDecoration(color: m.isSelf ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(16)),
            child: Text(m.content, style: TextStyle(color: m.isSelf ? Theme.of(context).colorScheme.onPrimaryContainer : null))))),
      SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 8), child: Row(children: [
        Expanded(child: TextField(controller: _inputCtrl, decoration: const InputDecoration(hintText: '输入消息...', border: OutlineInputBorder()), onSubmitted: (_) => _send())),
        const SizedBox(width: 8), FilledButton.icon(onPressed: _sending ? null : _send, icon: _sending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send), label: const Text('发送')),
      ]))),
    ]));
  }
  @override void dispose() { _sub?.cancel(); DouyinMessageService.stopPolling(); _inputCtrl.dispose(); _scrollCtrl.dispose(); super.dispose(); }
}
