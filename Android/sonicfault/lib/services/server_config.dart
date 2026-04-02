import 'package:shared_preferences/shared_preferences.dart';

class ServerConfig {
  static final ServerConfig instance = ServerConfig._();
  ServerConfig._();

  static const _key            = 'backend_url';
  static const defaultUrl      = 'http://192.168.1.8:8000';

  String _url = defaultUrl;
  String get url => _url;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _url = prefs.getString(_key) ?? defaultUrl;
  }

  Future<void> save(String url) async {
    _url = url.trim().replaceAll(RegExp(r'/$'), ''); // strip trailing slash
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _url);
  }

  Future<void> reset() async {
    _url = defaultUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}