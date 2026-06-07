import 'package:flutter/material.dart';

enum ProcessMoreAction {
  archive,
  trash,
  sync,
  saveTemplate,
}

enum CollectMoreAction {
  saveTemplate,
  createFromTemplate,
}

class TabMoreMenuButton<T> extends StatelessWidget {
  const TabMoreMenuButton({
    super.key,
    required this.items,
    required this.onSelected,
  });

  final List<PopupMenuEntry<T>> items;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      icon: const Icon(Icons.more_vert),
      tooltip: '更多',
      itemBuilder: (context) => items,
      onSelected: onSelected,
    );
  }
}

PopupMenuItem<T> processMenuItem<T>({
  required T value,
  required IconData icon,
  required String label,
}) {
  return PopupMenuItem(
    value: value,
    child: ListTile(
      leading: Icon(icon),
      title: Text(label),
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    ),
  );
}

PopupMenuItem<T> collectMenuItem<T>({
  required T value,
  required IconData icon,
  required String label,
}) {
  return PopupMenuItem(
    value: value,
    child: ListTile(
      leading: Icon(icon),
      title: Text(label),
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    ),
  );
}

const processMoreMenuDivider = PopupMenuDivider();
