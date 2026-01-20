import '../models/user_memory.dart';
import 'api_service.dart';

class MemoryService {
  // 获取用户记忆列表
  static Future<List<UserMemory>> getUserMemories(String userId) async {
    final result = await ApiService.get('/api/user/$userId/memories');
    final List<dynamic> list = result['data'] ?? [];
    return list.map((json) => UserMemory.fromJson(json)).toList();
  }

  // 删除用户记忆
  static Future<void> deleteUserMemory(String userId, String key) async {
    // API endpoint needs query parameter for key if using DELETE method standardly,
    // but check super.api definition:
    // delete /api/user/:user_id/memories (DeleteUserMemoryReq)
    // DeleteUserMemoryReq: UserId path, Key form.
    // Usually DELETE requests with body are discouraged but go-zero supports it.
    // However, looking at ApiService.delete, it supports body.
    
    await ApiService.delete(
      '/api/user/$userId/memories',
      // The API definition says Key is 'form:"key"', which usually means query param for GET/DELETE
      // or body form data. In go-zero, 'form' tag maps to query params for GET/DELETE.
      // So we should append it to URL.
    ); 
    // Wait, let me double check the api definition.
    // type DeleteUserMemoryReq {
    // 	UserId string `path:"user_id"`
    // 	Key    string `form:"key"`
    // }
    // For DELETE, 'form' usually means query parameters.
    // Let's try sending as query param.
  }

  // Implementing delete with query param support
  static Future<void> deleteUserMemoryByKey(String userId, String key) async {
    // Encode the key to be safe for URL
    final encodedKey = Uri.encodeComponent(key);
    await ApiService.delete('/api/user/$userId/memories?key=$encodedKey');
  }
}
