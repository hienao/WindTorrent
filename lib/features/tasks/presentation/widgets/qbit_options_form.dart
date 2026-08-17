import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/qbit_task_options_controller.dart';
import 'package:windwalker/l10n/app_localizations.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/models/qbit_task_options_update.dart';

/// qBit 选项表单。
///
/// 交互语义：
/// - 队列优先级：立即生效，不依赖保存按钮
/// - 分类 / 标签：更新草稿，点击保存后生效
class QBitOptionsForm extends StatefulWidget {
  const QBitOptionsForm({
    super.key,
    required this.taskId,
    required this.downloaderId,
  });

  final String taskId;
  final String downloaderId;

  @override
  State<QBitOptionsForm> createState() => _QBitOptionsFormState();
}

class _QBitOptionsFormState extends State<QBitOptionsForm> {
  String _queueActionLabel(AppLocalizations l10n, QBitQueuePriorityAction a) {
    return switch (a) {
      QBitQueuePriorityAction.top => l10n.qbitQueueActionTop,
      QBitQueuePriorityAction.increase => l10n.qbitQueueActionIncrease,
      QBitQueuePriorityAction.decrease => l10n.qbitQueueActionDecrease,
      QBitQueuePriorityAction.bottom => l10n.qbitQueueActionBottom,
      QBitQueuePriorityAction.unchanged => l10n.qbitQueueActionUnchanged,
    };
  }

  Future<void> _pickCategory(BuildContext context) async {
    final controller = context.read<QBitTaskOptionsController>();
    final l10n = AppLocalizations.of(context)!;
    final options = controller.availableCategories.toList(growable: true);

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(title: Text(l10n.qbitCategoryLabel)),
              for (final category in options)
                ListTile(
                  title: Text(category),
                  trailing: category == controller.categoryDraft
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () => Navigator.pop(sheetContext, category),
                ),
              ListTile(
                leading: const Icon(Icons.add_rounded),
                title: Text(l10n.addButton),
                onTap: () async {
                  final created = await _promptForNewValue(
                    sheetContext,
                    title: l10n.qbitCategoryLabel,
                  );
                  if (!sheetContext.mounted) return;
                  Navigator.pop(sheetContext, created);
                },
              ),
            ],
          ),
        );
      },
    );

    if (result != null && result.trim().isNotEmpty) {
      controller.updateCategory(result);
    }
  }

  Future<void> _pickTags(BuildContext context) async {
    final controller = context.read<QBitTaskOptionsController>();
    final l10n = AppLocalizations.of(context)!;
    final selected = controller.tagDrafts.toSet();
    final options = controller.availableTags.toList(growable: true);

    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(title: Text(l10n.qbitTagsLabel)),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final tag in options)
                          CheckboxListTile(
                            value: selected.contains(tag),
                            title: Text(tag),
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (_) {
                              setSheetState(() {
                                if (!selected.add(tag)) {
                                  selected.remove(tag);
                                }
                              });
                            },
                          ),
                        ListTile(
                          leading: const Icon(Icons.add_rounded),
                          title: Text(l10n.addButton),
                          onTap: () async {
                            final created = await _promptForNewValue(
                              sheetContext,
                              title: l10n.qbitTagsLabel,
                            );
                            if (created == null || created.trim().isEmpty) {
                              return;
                            }
                            setSheetState(() {
                              if (!options.contains(created)) {
                                options.add(created);
                              }
                              selected.add(created);
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            child: Text(l10n.cancel),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.pop(
                              sheetContext,
                              selected.toList()..sort(),
                            ),
                            child: Text(l10n.saveButton),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      controller.updateTags(result);
    }
  }

  Future<String?> _promptForNewValue(
    BuildContext context, {
    required String title,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final textController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: textController,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                textController.text.trim(),
              ),
              child: Text(l10n.addButton),
            ),
          ],
        );
      },
    );

    textController.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Consumer<QBitTaskOptionsController>(
      builder: (context, controller, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.qbitQueuePriorityTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    for (final action in const [
                      QBitQueuePriorityAction.top,
                      QBitQueuePriorityAction.increase,
                      QBitQueuePriorityAction.decrease,
                      QBitQueuePriorityAction.bottom,
                    ]) ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: controller.queueActionsEnabled &&
                                  !controller.isApplyingQueueAction
                              ? () => controller.applyQueueActionNow(
                                    taskId: widget.taskId,
                                    downloader: _resolveDownloader(context),
                                    action: action,
                                  )
                              : null,
                          child: Text(_queueActionLabel(l10n, action)),
                        ),
                      ),
                      if (action != QBitQueuePriorityAction.bottom)
                        const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.qbitOptionsEntry,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _pickCategory(context),
                        child: _FieldSummary(
                          label: l10n.qbitCategoryLabel,
                          value: controller.categoryDraft,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _pickTags(context),
                        child: _FieldSummary(
                          label: l10n.qbitTagsLabel,
                          value: controller.tagDrafts.join(', '),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (controller.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          controller.errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: controller.isDirty && !controller.isSaving
                            ? () => controller.save(
                                  taskId: widget.taskId,
                                  downloader: _resolveDownloader(context),
                                )
                            : null,
                        child: Text(l10n.saveButton),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Downloader _resolveDownloader(BuildContext context) {
    return context
        .read<DownloaderController>()
        .getDownloader(widget.downloaderId)!;
  }
}

class _FieldSummary extends StatelessWidget {
  const _FieldSummary({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final displayValue = value.trim().isEmpty ? '--' : value.trim();
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              const SizedBox(height: 4),
              Text(
                displayValue,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.chevron_right_rounded),
      ],
    );
  }
}
