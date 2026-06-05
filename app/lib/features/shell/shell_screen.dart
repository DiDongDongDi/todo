import 'package:flutter/material.dart';
import 'package:todo_app/features/collect/collect_screen.dart';
import 'package:todo_app/features/process/process_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;

  Widget _buildTab(int index) {
    switch (index) {
      case 0:
        return const CollectScreen(key: ValueKey('collect'));
      case 1:
        return const ProcessScreen(key: ValueKey('process'));
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: _buildTab(_index),
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
