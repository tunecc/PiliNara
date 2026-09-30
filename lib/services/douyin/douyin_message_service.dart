/// Douyin messaging service with fingerprint spoofing.
import 'dart:async';
import 'dart:convert';
import 'package:PiliPlus/services/douyin/douyin_cookie_service.dart';
import 'package:PiliPlus/services/douyin/douyin_fingerprint.dart';
import 'package:PiliPlus/services/logger.dart';
import 'package:dio/dio.dart';

abstract final class DouyinMessageService {
  static Dio? _dio;
  static Timer? _pollTimer;
  static StreamController<List<DouyinMessage>>? _stream;

  static Dio get dio {
    _dio ??= Dio(BaseOptions(connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 15)));
    return _dio!;
  }

  static Future<List<DouyinConversation>> getConversations() async {
    try {
      final params = {...DouyinFingerprint.buildCommonParams(), 'count': 20, 'cursor': 0};
      final r = await dio.get('https://www.douyin.com/aweme/v1/web/im/conversation/list/',
        queryParameters: params, options: Options(headers: DouyinFingerprint.buildHeaders(cookie: DouyinCookieService.cookie)));
      if (r.statusCode == 200 && r.data is Map) {
        final list = (r.data as Map<String, dynamic>)['conversation_list'] as List<dynamic>?;
        if (list != null) return list.whereType<Map<String, dynamic>>().map(DouyinConversation.fromMap).toList();
      }
    } catch (e) { logger.e('DouyinMsg.getConversations failed: $e'); }
    return [];
  }

  static Future<List<DouyinMessage>> getMessages(String convId, {int count = 30}) async {
    try {
      final params = {...DouyinFingerprint.buildCommonParams(), 'conversation_id': convId, 'count': count, 'cursor': 0};
      final r = await dio.get('https://www.douyin.com/aweme/v1/web/im/message/list/',
        queryParameters: params, options: Options(headers: DouyinFingerprint.buildHeaders(cookie: DouyinCookieService.cookie)));
      if (r.statusCode == 200 && r.data is Map) {
        final list = (r.data as Map<String, dynamic>)['message_list'] as List<dynamic>?;
        if (list != null) return list.whereType<Map<String, dynamic>>().map(DouyinMessage.fromMap).toList();
      }
    } catch (e) { logger.e('DouyinMsg.getMessages failed: $e'); }
    return [];
  }

  static Future<bool> sendMessage({required String conversationId, required String content}) async {
    try {
      final r = await dio.post('https://www.douyin.com/aweme/v1/web/im/message/send/',
        data: {'conversation_id': conversationId, 'content': jsonEncode({'text': content}), 'msg_type': 1},
        options: Options(headers: {...DouyinFingerprint.buildHeaders(cookie: DouyinCookieService.cookie), 'Content-Type': 'application/json'}));
      return r.statusCode == 200;
    } catch (e) { logger.e('DouyinMsg.sendMessage failed: $e'); return false; }
  }

  static Stream<List<DouyinMessage>> startPolling(String convId, {Duration interval = const Duration(seconds: 5)}) {
    _stream?.close(); _stream = StreamController<List<DouyinMessage>>.broadcast();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(interval, (_) async { _stream?.add(await getMessages(convId)); });
    return _stream!.stream;
  }

  static void stopPolling() { _pollTimer?.cancel(); _pollTimer = null; _stream?.close(); _stream = null; }
}

class DouyinConversation {
  final String id, peerName, peerAvatar, lastMessage;
  final int lastMessageTime, unreadCount;
  const DouyinConversation({required this.id, required this.peerName, required this.peerAvatar, this.lastMessage = '', this.lastMessageTime = 0, this.unreadCount = 0});
  factory DouyinConversation.fromMap(Map<String, dynamic> map) {
    final peer = map['peer_user'] as Map<String, dynamic>? ?? {};
    final lastMsg = map['last_message'] as Map<String, dynamic>? ?? {};
    return DouyinConversation(id: map['conversation_id'] as String? ?? '', peerName: peer['nickname'] as String? ?? '',
      peerAvatar: (peer['avatar_thumb'] as Map<String, dynamic>?)?['url_list']?[0] as String? ?? '',
      lastMessage: lastMsg['content'] as String? ?? '', lastMessageTime: lastMsg['create_time'] as int? ?? 0,
      unreadCount: map['unread_count'] as int? ?? 0);
  }
}

class DouyinMessage {
  final String id, content; final bool isSelf; final int timestamp, msgType;
  const DouyinMessage({required this.id, required this.content, this.isSelf = false, this.timestamp = 0, this.msgType = 1});
  factory DouyinMessage.fromMap(Map<String, dynamic> map) {
    String content = '';
    try { final parsed = jsonDecode(map['content'] as String? ?? '{}') as Map<String, dynamic>; content = parsed['text'] as String? ?? ''; } catch (_) { content = map['content'] as String? ?? ''; }
    return DouyinMessage(id: map['message_id'] as String? ?? '', content: content,
      isSelf: (map['from_id'] as String?) == DouyinCookieService.userInfo?['uid'],
      timestamp: map['create_time'] as int? ?? 0, msgType: map['msg_type'] as int? ?? 1);
  }
}
