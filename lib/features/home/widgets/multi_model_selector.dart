import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/chat_input_data.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_checkbox.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../theme/app_font_weights.dart';

Future<List<ChatTargetModel>?> showMultiModelSelector(
  BuildContext context, {
  required List<ChatTargetModel> initialSelected,
  String? currentProviderKey,
  String? currentModelId,
}) {
  final initial = initialSelected.isNotEmpty
      ? initialSelected
      : (currentProviderKey != null && currentModelId != null
            ? [
                ChatTargetModel(
                  providerKey: currentProviderKey,
                  modelId: currentModelId,
                ),
              ]
            : const <ChatTargetModel>[]);

  final platform = defaultTargetPlatform;
  final isDesktop =
      platform == TargetPlatform.macOS ||
      platform == TargetPlatform.windows ||
      platform == TargetPlatform.linux;

  if (isDesktop) {
    return showGeneralDialog<List<ChatTargetModel>>(
      context: context,
      barrierDismissible: true,
      barrierLabel: AppLocalizations.of(context)!.chatInputBarMultiModelTooltip,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      pageBuilder: (ctx, _, __) =>
          _MultiModelSelectorDialog(initialSelected: initial),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  return showModalBottomSheet<List<ChatTargetModel>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _MultiModelSelectorSheet(initialSelected: initial),
  );
}

class _ModelTargetItem {
  const _ModelTargetItem({
    required this.providerKey,
    required this.providerName,
    required this.modelId,
  });

  final String providerKey;
  final String providerName;
  final String modelId;

  String get key => '$providerKey::$modelId';

  ChatTargetModel toTarget() =>
      ChatTargetModel(providerKey: providerKey, modelId: modelId);
}

class _MultiModelSelectorDialog extends StatelessWidget {
  const _MultiModelSelectorDialog({required this.initialSelected});

  final List<ChatTargetModel> initialSelected;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
        child: Material(
          color: Colors.transparent,
          child: _MultiModelSelectorBody(
            initialSelected: initialSelected,
            desktop: true,
          ),
        ),
      ),
    );
  }
}

class _MultiModelSelectorSheet extends StatelessWidget {
  const _MultiModelSelectorSheet({required this.initialSelected});

  final List<ChatTargetModel> initialSelected;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.82;
    return SizedBox(
      height: height,
      child: _MultiModelSelectorBody(
        initialSelected: initialSelected,
        desktop: false,
      ),
    );
  }
}

class _MultiModelSelectorBody extends StatefulWidget {
  const _MultiModelSelectorBody({
    required this.initialSelected,
    required this.desktop,
  });

  final List<ChatTargetModel> initialSelected;
  final bool desktop;

  @override
  State<_MultiModelSelectorBody> createState() =>
      _MultiModelSelectorBodyState();
}

class _MultiModelSelectorBodyState extends State<_MultiModelSelectorBody> {
  final TextEditingController _search = TextEditingController();
  late final Set<String> _selectedKeys;

  @override
  void initState() {
    super.initState();
    _selectedKeys = {for (final model in widget.initialSelected) model.key};
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final items = _modelItems(context);
    final query = _search.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? items
        : items
              .where(
                (item) =>
                    item.modelId.toLowerCase().contains(query) ||
                    item.providerName.toLowerCase().contains(query),
              )
              .toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.desktop ? 18 : 20),
      child: Container(
        color: cs.surface,
        child: Column(
          children: [
            _buildHeader(context, l10n, items),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: l10n.multiModelSelectorSearchHint,
                  prefixIcon: const Icon(Lucide.Search, size: 18),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: cs.outline.withValues(alpha: 0.18),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        l10n.multiModelSelectorNoModels,
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                      children: _buildRows(context, filtered),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AppLocalizations l10n,
    List<_ModelTargetItem> allItems,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
      child: Row(
        children: [
          Icon(Lucide.AtSign, size: 20, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.multiModelSelectorTitle,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: AppFontWeights.semibold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.multiModelSelectorSelectedCount(_selectedKeys.length),
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _selectedKeys.isEmpty
                ? null
                : () => setState(_selectedKeys.clear),
            child: Text(l10n.multiModelSelectorClear),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(l10n.homePageCancel),
          ),
          FilledButton(
            onPressed: () {
              final selected = allItems
                  .where((item) => _selectedKeys.contains(item.key))
                  .map((item) => item.toTarget())
                  .toList(growable: false);
              Navigator.of(context).pop(selected);
            },
            child: Text(l10n.homePageDone),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRows(BuildContext context, List<_ModelTargetItem> items) {
    final rows = <Widget>[];
    String? currentProviderKey;
    for (final item in items) {
      if (currentProviderKey != item.providerKey) {
        currentProviderKey = item.providerKey;
        rows.add(_ProviderHeader(name: item.providerName));
      }
      rows.add(
        _ModelTargetRow(
          item: item,
          selected: _selectedKeys.contains(item.key),
          onChanged: (selected) {
            setState(() {
              if (selected) {
                _selectedKeys.add(item.key);
              } else {
                _selectedKeys.remove(item.key);
              }
            });
          },
        ),
      );
    }
    return rows;
  }

  List<_ModelTargetItem> _modelItems(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final orderedKeys = <String>[
      ...settings.providersOrder.where(settings.providerConfigs.containsKey),
      ...settings.providerConfigs.keys.where(
        (key) => !settings.providersOrder.contains(key),
      ),
    ];

    return [
      for (final key in orderedKeys)
        if (settings.providerConfigs[key] case final cfg?)
          if (cfg.enabled && cfg.models.isNotEmpty)
            for (final modelId in cfg.models)
              _ModelTargetItem(
                providerKey: key,
                providerName: cfg.name.trim().isEmpty ? key : cfg.name,
                modelId: modelId,
              ),
    ];
  }
}

class _ProviderHeader extends StatelessWidget {
  const _ProviderHeader({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
      child: Text(
        name,
        style: TextStyle(
          fontSize: 12,
          fontWeight: AppFontWeights.semibold,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _ModelTargetRow extends StatelessWidget {
  const _ModelTargetRow({
    required this.item,
    required this.selected,
    required this.onChanged,
  });

  final _ModelTargetItem item;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IosCardPress(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onChanged(!selected),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? cs.primary.withValues(alpha: 0.08)
              : cs.onSurface.withValues(alpha: 0.035),
          border: Border.all(
            color: selected
                ? cs.primary.withValues(alpha: 0.28)
                : cs.outline.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            IosCheckbox(
              value: selected,
              size: 20,
              hitTestSize: 28,
              onChanged: onChanged,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.modelId,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: AppFontWeights.medium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
