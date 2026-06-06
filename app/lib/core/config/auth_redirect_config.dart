/// 魔法链接登录回调地址。
///
/// 须与 Supabase Dashboard → Authentication → URL Configuration
/// → Redirect URLs 中的条目完全一致。
class AuthRedirectConfig {
  AuthRedirectConfig._();

  static const String url = 'com.todo.app.todo_app://login-callback/';
}
