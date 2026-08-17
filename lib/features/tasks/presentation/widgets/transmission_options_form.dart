import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/transmission_task_options_controller.dart';
import 'package:windwalker/l10n/app_localizations.dart';
import 'package:windwalker/models/transmission_task_options.dart';

/// Transmission 任务选项表单。
///
/// 使用 [NeoSection] 分组展示传输优先级、带宽、做种比率、空闲限制四个区域，
/// 底部 Save 按钮仅在 isDirty 且 !isSaving 时启用。
class TransmissionOptionsForm extends StatelessWidget {
  const TransmissionOptionsForm({
    super.key,
    required this.taskId,
    required this.downloaderId,
  });

  final String taskId;
  final String downloaderId;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TransmissionTaskOptionsController>();
    final draft = controller.draft;

    if (draft == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        _TransferPrioritySection(draft: draft),
        const SizedBox(height: 16),
        _BandwidthSection(draft: draft),
        const SizedBox(height: 16),
        _ShareRatioLimitSection(draft: draft),
        const SizedBox(height: 16),
        _IdleLimitSection(draft: draft),
        const SizedBox(height: 24),
        _SaveButton(
          taskId: taskId,
          downloaderId: downloaderId,
        ),
      ],
    );
  }
}

class _TransferPrioritySection extends StatelessWidget {
  const _TransferPrioritySection({required this.draft});

  final TransmissionTaskOptions draft;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<TransmissionTaskOptionsController>();
    final l10n = AppLocalizations.of(context)!;

    return NeoSection(
      title: l10n.transmissionTransferPriority,
      child: DropdownButton<int>(
        value: draft.bandwidthPriority,
        isExpanded: true,
        items: [
          DropdownMenuItem(value: -1, child: Text(l10n.transmissionPriorityLow)),
          DropdownMenuItem(value: 0, child: Text(l10n.transmissionPriorityNormal)),
          DropdownMenuItem(value: 1, child: Text(l10n.transmissionPriorityHigh)),
        ],
        onChanged: (value) {
          if (value != null) controller.updateBandwidthPriority(value);
        },
      ),
    );
  }
}

class _BandwidthSection extends StatelessWidget {
  const _BandwidthSection({required this.draft});

  final TransmissionTaskOptions draft;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<TransmissionTaskOptionsController>();
    final l10n = AppLocalizations.of(context)!;

    return NeoSection(
      title: l10n.transmissionBandwidth,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l10n.transmissionHonorGlobalLimits),
              ),
              Switch(
                value: draft.honorsSessionLimits,
                onChanged: controller.updateHonorsSessionLimits,
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: '${draft.downloadLimitKBps}',
            onChanged: controller.updateDownloadLimit,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.transmissionDownloadLimit,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: '${draft.uploadLimitKBps}',
            onChanged: controller.updateUploadLimit,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.transmissionUploadLimit,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareRatioLimitSection extends StatelessWidget {
  const _ShareRatioLimitSection({required this.draft});

  final TransmissionTaskOptions draft;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<TransmissionTaskOptionsController>();
    final l10n = AppLocalizations.of(context)!;

    return NeoSection(
      title: l10n.transmissionShareRatioLimit,
      child: Column(
        children: [
          DropdownButton<TransmissionLimitMode>(
            value: draft.seedRatioMode,
            isExpanded: true,
            items: [
              DropdownMenuItem(
                value: TransmissionLimitMode.global,
                child: Text(l10n.transmissionLimitGlobal),
              ),
              DropdownMenuItem(
                value: TransmissionLimitMode.disabled,
                child: Text(l10n.transmissionLimitDisabled),
              ),
              DropdownMenuItem(
                value: TransmissionLimitMode.custom,
                child: Text(l10n.transmissionLimitCustom),
              ),
            ],
            onChanged: (value) {
              if (value != null) controller.updateSeedRatioMode(value);
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: '${draft.seedRatioLimit}',
            onChanged: controller.updateSeedRatioLimit,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.transmissionRatioValue,
            ),
          ),
        ],
      ),
    );
  }
}

class _IdleLimitSection extends StatelessWidget {
  const _IdleLimitSection({required this.draft});

  final TransmissionTaskOptions draft;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<TransmissionTaskOptionsController>();
    final l10n = AppLocalizations.of(context)!;

    return NeoSection(
      title: l10n.transmissionIdleLimit,
      child: Column(
        children: [
          DropdownButton<TransmissionLimitMode>(
            value: draft.idleLimitMode,
            isExpanded: true,
            items: [
              DropdownMenuItem(
                value: TransmissionLimitMode.global,
                child: Text(l10n.transmissionLimitGlobal),
              ),
              DropdownMenuItem(
                value: TransmissionLimitMode.disabled,
                child: Text(l10n.transmissionLimitDisabled),
              ),
              DropdownMenuItem(
                value: TransmissionLimitMode.custom,
                child: Text(l10n.transmissionLimitCustom),
              ),
            ],
            onChanged: (value) {
              if (value != null) controller.updateIdleLimitMode(value);
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: '${draft.idleLimitMinutes}',
            onChanged: controller.updateIdleLimitMinutes,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.transmissionIdleMinutes,
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.taskId,
    required this.downloaderId,
  });

  final String taskId;
  final String downloaderId;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TransmissionTaskOptionsController>();
    final l10n = AppLocalizations.of(context)!;
    final canSave = controller.isDirty && !controller.isSaving;

    return FilledButton(
      onPressed: canSave
          ? () {
              final downloaderController =
                  context.read<DownloaderController>();
              final downloader = downloaderController.getDownloader(downloaderId);
              if (downloader == null) return;
              controller.save(taskId: taskId, downloader: downloader);
            }
          : null,
      child: controller.isSaving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(l10n.saveButton),
    );
  }
}
