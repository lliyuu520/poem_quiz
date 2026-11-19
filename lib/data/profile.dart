import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 全局个人档案：出生年月。
///
/// 学龄不再由用户在首页选择，而是从出生年月推算（见 `gradeForBirth`）。
/// 出生年月是「用户是谁」的属性，不属于任何科目，所以存裸键
/// （不带 `<topicId>_` 前缀），与 `main.dart` 的 `last_topic` 同一层。
class UserProfile extends ChangeNotifier {
  UserProfile._(this._prefs) {
    _load();
  }

  static const _kBirthYear = 'birth_year';
  static const _kBirthMonth = 'birth_month';

  final SharedPreferences _prefs;

  /// 出生年份（如 2018），未设置时为 null。
  int? get birthYear => _birthYear;
  int? _birthYear;

  /// 出生月份（1~12），未设置时为 null。
  int? get birthMonth => _birthMonth;
  int? _birthMonth;

  /// 是否已设置出生年月。未设置时首页会提示去设置页补填。
  bool get hasBirth => _birthYear != null && _birthMonth != null;

  /// 从全局 SharedPreferences 加载（裸键，无科目前缀）。
  static Future<UserProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    return UserProfile._(prefs);
  }

  void _load() {
    _birthYear = _prefs.getInt(_kBirthYear);
    _birthMonth = _prefs.getInt(_kBirthMonth);
  }

  /// 保存出生年月。月份越界视为脏数据，不落盘。
  Future<void> setBirth({required int year, required int month}) async {
    if (month < 1 || month > 12) return;
    _birthYear = year;
    _birthMonth = month;
    await _prefs.setInt(_kBirthYear, year);
    await _prefs.setInt(_kBirthMonth, month);
    notifyListeners();
  }
}
