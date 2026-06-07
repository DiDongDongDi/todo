import 'package:flutter/material.dart';
import 'package:todo_app/features/collect/collect_screen.dart';
import 'package:todo_app/features/process/process_screen.dart';
import 'package:todo_app/features/settings/settings_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;

  Widget _tabPage(int index, Widget child) {
    final visible = _index == index;
    return Visibility(
      visible: visible,
      maintainState: true,
      maintainAnimation: true,
      maintainSize: false,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // body 高度不随键盘变化，避免 expands TextField 在键盘动画期间逐帧重排。
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        // 仅当前 tab 参与布局，避免键盘动画期间三个页面一起重排。
        child: Stack(
          fit: StackFit.expand,
          children: [
            _tabPage(0, const CollectScreen(key: ValueKey('collect'))),
            _tabPage(1, const ProcessScreen(key: ValueKey('process'))),
            _tabPage(2, const SettingsScreen(key: ValueKey('settings'))),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: '收集',
          ),
          NavigationDestination(
            icon: Icon(Icons.swipe_outlined),
            selectedIcon: Icon(Icons.swipe),
            label: '处理',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}

/// 供 go_router 使用的无状态包装
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
