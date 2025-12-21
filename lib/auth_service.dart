import 'dart:async';

class AuthService {
  // A simple mock of an authentication service
  static final Map<String, String> _users = {};

  static Future<bool> login(String email, String password) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    
    if (_users.containsKey(email) && _users[email] == password) {
      return true;
    }
    return false;
  }

  static Future<bool> register(String email, String password) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    if (_users.containsKey(email)) {
      return false; // User already exists
    }
    
    _users[email] = password;
    return true;
  }
}

