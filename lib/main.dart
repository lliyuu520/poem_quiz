import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/account_service.dart';
import 'data/profile.dart';
import 'data/progress_store.dart';
import 'data/topic.dart';
import 'data/topics.dart';
import 'pages/home_page.dart';
import 'theme/app_theme.dart';

/// 上次使用的科目 id。独立于科目存档键（那些带 `<topicId>_` 前缀），不会冲突。
/// 顶层分组不单独落盘——它由科目所属组推出，科目是更精确的定位。
const String _kLastTopic = 'last_topic';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final savedId = prefs.getString(_kLastTopic);
  final topic = kTopics.firstWhere(
    (t) => t.id == savedId,
    orElse: () => kDefaultTopic,
  );
  // 所有科目的存档一次读齐：切 tab 时只是换指针，不再 await 磁盘 IO，
  // 避免出现卡顿的空档。
  final stores = <String, ProgressStore>{
    for (final t in kTopics) t.id: await ProgressStore.load(topicId: t.id),
  };
  final profile = await UserProfile.load();
  final account = AccountService();
  await account.load(); // 读本地 token；过期会就地清除，界面不会误显示已登录
  runApp(PoemQuizApp(
    initialTopic: topic,
    stores: stores,
    initialProfile: profile,
    account: account,
  ));
}

/// 根壳：持有当前科目、全部科目存档与全局个人档案。
///
/// 切换科目只换 [_topic]/[_store] 指针并通知重建——存档在启动时已全部加载，
/// 切换路径上没有异步等待，所以 tab 切换是即时的。
class PoemQuizApp extends StatefulWidget {
  const PoemQuizApp({
    super.key,
    required this.initialTopic,
    required this.stores,
    required this.initialProfile,
    required this.account,
  });

  final Topic initialTopic;
  final Map<String, ProgressStore> stores;
  final UserProfile initialProfile;

  /// 账号会话。未登录时也是同一个实例，登录/登出后由它通知界面刷新。
  final AccountService account;

  @override
  State<PoemQuizApp> createState() => _PoemQuizAppState();
}

class _PoemQuizAppState extends State<PoemQuizApp> {
  late Topic _topic = widget.initialTopic;
  late ProgressStore _store = widget.stores[widget.initialTopic.id]!;
  late final UserProfile _profile = widget.initialProfile;

  @override
  void initState() {
    super.initState();
    // 启动时各组都先落在当前科目所在组；其它组取该组第一个。
    for (final t in kTopics) {
      _lastGroupTopic.putIfAbsent(t.group, () => t.id);
    }
    _lastGroupTopic[widget.initialTopic.group] = widget.initialTopic.id;
  }

  /// 持久化「上次科目」不挡切换：fire-and-forget，失败也不影响体验。
  void _saveLastTopic(String id) {
    unawaited(SharedPreferences.getInstance().then(
      (prefs) => prefs.setString(_kLastTopic, id),
      onError: (Object _) {},
    ));
  }

  void switchTopic(Topic topic) {
    if (topic.id == _topic.id) return;
    setState(() {
      _topic = topic;
      _store = widget.stores[topic.id]!;
    });
    _lastGroupTopic[topic.group] = topic.id;
    _saveLastTopic(topic.id);
  }

  /// 切换顶层分组：落到该组的上次科目或第一个科目。
  void switchGroup(TopicGroup group) {
    if (group == _topic.group) return;
    final candidates = kTopics.where((t) => t.group == group).toList();
    if (candidates.isEmpty) return;
    // 优先回到该组里上次用过的科目，否则取该组第一个。
    final lastId = _lastGroupTopic[group];
    final topic = candidates.firstWhere(
      (t) => t.id == lastId,
      orElse: () => candidates.first,
    );
    switchTopic(topic);
  }

  /// 各组上次用过的科目，内存态即可——切组时优先回到它。
  /// 持久化由 `last_topic` 负责：它存的是精确科目，组由科目推出。
  final Map<TopicGroup, String> _lastGroupTopic = <TopicGroup, String>{};

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '拾',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // 不用 ValueKey 强制整树重建：HomePage 在 didUpdateWidget 里自行同步
      // 本科目的范围/难度状态，切换更平滑、不丢滚动位置与动画。
      home: HomePage(
        store: _store,
        topic: _topic,
        profile: _profile,
        account: widget.account,
        stores: widget.stores,
        topics: kTopics,
        onSwitchTopic: switchTopic,
        onSwitchGroup: switchGroup,
      ),
    );
  }
}
