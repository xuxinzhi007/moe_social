import 'dart:io';

import '../models/private_conversation_item.dart';
import '../models/private_message_item.dart';
import 'api_client.dart';
import 'api_service.dart';

class ChatService {
  static Future<({List<PrivateMessageItem> items, bool hasMore})>
      listPrivateMessages({
    required String peerUserId,
    String? beforeId,
    int limit = 30,
  }) =>
          ApiService.listPrivateMessages(
            peerUserId: peerUserId,
            beforeId: beforeId,
            limit: limit,
          );

  static Future<
      ({
        List<PrivateConversationItem> items,
        int total,
        bool hasMore,
      })> listPrivateConversations({
    int limit = 30,
    int offset = 0,
  }) =>
      ApiService.listPrivateConversations(limit: limit, offset: offset);

  static Future<PrivateMessageItem> sendPrivateMessage({
    required String receiverId,
    required String body,
    List<String>? imagePaths,
  }) =>
      ApiService.sendPrivateMessage(
        receiverId: receiverId,
        body: body,
        imagePaths: imagePaths,
      );

  static Future<Map<String, dynamic>> voiceCall(String receiverId) =>
      ApiService.voiceCall(receiverId);

  static Future<Map<String, dynamic>> initiateCall(String receiverId) =>
      ApiService.initiateCall(receiverId);

  static Future<Map<String, dynamic>> answerCall(String callId) =>
      ApiService.answerCall(callId);

  static Future<Map<String, dynamic>> rejectCall(String callId) =>
      ApiService.rejectCall(callId);

  static Future<Map<String, dynamic>> cancelCall() => ApiService.cancelCall();

  static Future<Map<String, dynamic>> getRtcToken(
    String channelName, {
    int role = 1,
  }) =>
      ApiService.getRtcToken(channelName, role: role);

  static Future<String> uploadImage(File image) => ApiClient.uploadImage(image);
}
