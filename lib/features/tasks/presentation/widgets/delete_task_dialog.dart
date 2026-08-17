import 'package:flutter/material.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/l10n/app_localizations.dart';

/// 显示删除任务确认对话框，带"同时删除文件"选项
///
/// 返回值：
/// - `null` — 用户取消
/// - `false` — 确认删除，不删除文件
/// - `true` — 确认删除，同时删除文件
Future<bool?> showDeleteTaskDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  bool deleteFiles = false;

  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => Dialog(
        // 透明背景让 NeoCard 的外凸阴影成为唯一容器语言。
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: NeoCard(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.delete,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(l10n.confirmDeleteTask),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: deleteFiles,
                onChanged: (v) =>
                    setDialogState(() => deleteFiles = v ?? false),
                title: Text(l10n.deleteWithFiles),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(l10n.cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                    ),
                    onPressed: () => Navigator.pop(dialogContext, deleteFiles),
                    child: Text(l10n.delete),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
