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
    setState(() {
      _entries = entries;
      _loaded = true;
    });
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

  Widget _buildItem(BuildContext context, int displayIndex) {
    final storageIndex = _entries.length - 1 - displayIndex;
    final entry = _entries[storageIndex];
    final formatted =
        DateFormat.yMMMd().add_Hm().format(entry.completedAt.toLocal());
    return Dismissible(
      key: ValueKey(
        '${entry.completedAt.toIso8601String()}-${entry.title}-$storageIndex',
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
        setState(() => _entries.removeAt(storageIndex));
        await deleteHistoryEntry(storageIndex);
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
