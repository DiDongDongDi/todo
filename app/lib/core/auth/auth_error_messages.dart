import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:todo_app/shared/widgets/app_snackbar.dart';

/// 将 Supabase 登录异常转为面向用户的中文说明。
String authSignInErrorMessage(Object error) {
  if (error is AuthApiException) {
    return switch (error.code) {
      'over_email_send_rate_limit' =>
        '发送太频繁，请约 1 小时后再试，或先查收邮箱中已有的登录链接（含垃圾箱）。',
      'email_address_invalid' => '邮箱格式不正确，请检查后重试。',
      'signup_disabled' => '当前项目未开启邮箱登录，请检查 Supabase 配置。',
      _ => error.message.isNotEmpty ? error.message : '登录失败，请稍后重试。',
    };
  }
  return '登录失败，请稍后重试。';
}

AppSnackType authSignInErrorSnackType(Object error) {
  if (error is AuthApiException &&
      error.code == 'over_email_send_rate_limit') {
    return AppSnackType.warning;
  }
  return AppSnackType.error;
}
