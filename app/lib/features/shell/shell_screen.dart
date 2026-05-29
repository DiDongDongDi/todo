import 'package:flutter/material.dart';
import 'package:todo_app/features/collect/collect_screen.dart';
import 'package:todo_app/features/process/process_screen.dart';
import 'package:todo_app/shared/layout/app_layout.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          CollectScreen(),
          ProcessScreen(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayout.navBarMaxWidth,
              ),
              child: NavigationBar(
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
            ),
          ),
        ),
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
