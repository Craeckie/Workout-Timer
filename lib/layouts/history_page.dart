import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../generated/l10n.dart';
import '../utils/history_helper.dart';
import '../utils/workout.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  HistoryPageState createState() => HistoryPageState();
}

class HistoryPageState extends State<HistoryPage> {
  List<HistoryEntry> _entries = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final entries = await loadHistory();
    entries.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    setState(() {
      _entries = entries;
      _loaded = true;
    });
  }

  String _formatDate(DateTime completedAt) {
    final local = completedAt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(local.year, local.month, local.day);

    if (date == today) {
      return DateFormat('Today, Hm').format(local);
    } else if (date == today.subtract(const Duration(days: 1))) {
      return DateFormat('Yesterday, Hm').format(local);
    } else {
      return DateFormat.yMMMd().add_Hm().format(local);
    }
  }

  void _confirmClear() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(S.of(context).clearHistory),
        content: Text(S.of(context).clearHistoryConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(S.of(context).cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await clearHistory();
              await _load();
            },
            child: Text(S.of(context).delete),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index) {
    final entry = _entries[index];
    final formatted = _formatDate(entry.completedAt);
    return Dismissible(
      key: ValueKey(
        '${entry.completedAt.toIso8601String()}-${entry.title}',
      ),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: Theme.of(context).colorScheme.errorContainer,
        child: Icon(
          Icons.delete,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      onDismissed: (_) async {
        setState(() => _entries.removeAt(index));
        await deleteHistoryEntryByProperties(entry.title, entry.completedAt);
      },
      child: Card(
        child: ListTile(
          title: Text(entry.title),
          subtitle: Text(formatted),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(S.of(context).history),
          actions: [
            if (_entries.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_sweep),
                tooltip: S.of(context).clearHistory,
                onPressed: _confirmClear,
              ),
          ],
        ),
        body: !_loaded
            ? const SizedBox.shrink()
            : _entries.isEmpty
                ? Center(child: Text(S.of(context).noHistory))
                : ListView.builder(
                    itemCount: _entries.length,
                    itemBuilder: _buildItem,
                  ),
      );
}
