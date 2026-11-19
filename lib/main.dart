import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/profile.dart';
import 'data/progress_store.dart';
import 'data/topic.dart';
import 'data/topics.dart';
import 'pages/home_page.dart';
import 'theme/app_theme.dart';

/// 上次使用的科目 id。独立于科目存档键（那些带 `<topicId>_` 前缀），不会冲突。
const String _kLastTopic = 'last_topic';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final savedId = prefs.getString(_kLastTopic);
  final topic = kTopics.firstWhere(
    (t) => t.id == savedId,
    orElse: () => kDefaultTopic,
  );
  final store = await ProgressStore.load(topicId: topic.id);
  final profile = await UserProfile.load();
  runApp(PoemQuizApp(
    initialStore: store,
    initialTopic: topic,
    initialProfile: profile,
  ));
}

/// 根壳：持有当前科目、对应存档与全局个人档案。
///
/// 切换科目时重建 [ProgressStore]（每个科目一份独立存档），
/// 并整棵树重建，避免上一个科目的引擎、错题本缓存残留。
class PoemQuizApp extends StatefulWidget {
  const PoemQuizApp({
    super.key,
    required this.initialStore,
    required this.initialTopic,
    required this.initialProfile,
  });

  final ProgressStore initialStore;
  final Topic initialTopic;
  final UserProfile initialProfile;

  @override
  State<PoemQuizApp> createState() => _PoemQuizAppState();
}

class _PoemQuizAppState extends State<PoemQuizApp> {
  late Topic _topic = widget.initialTopic;
  late ProgressStore _store = widget.initialStore;
  late final UserProfile _profile = widget.initialProfile;

  /// 切换科目。存档按科目隔离，所以必须换一份 [ProgressStore]。
  Future<void> switchTopic(Topic topic) async {
    if (topic.id == _topic.id) return;
    final store = await ProgressStore.load(topicId: topic.id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastTopic, topic.id);
    if (!mounted) return;
    setState(() {
      _topic = topic;
      _store = store;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '日知',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // key 让切换科目时 HomePage 整棵重建，不会残留上一个科目的选中态。
      home: HomePage(
        key: ValueKey<String>(_topic.id),
        store: _store,
        topic: _topic,
        profile: _profile,
        onSwitchTopic: switchTopic,
      ),
    );
  }
}
