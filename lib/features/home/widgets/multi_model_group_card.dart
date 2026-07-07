import 'package:flutter/material.dart';
import '../../../core/models/chat_message.dart';
import '../../../l10n/app_localizations.dart';

/// 多模型回答组的布局切换按钮组件
class _LayoutToggleButton extends StatelessWidget {
  const _LayoutToggleButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isSelected
              ? cs.primary.withValues(alpha: isDark ? 0.25 : 0.12)
              : Colors.transparent,
          border: isSelected
              ? Border.all(color: cs.primary.withValues(alpha: 0.4), width: 1)
              : null,
        ),
        child: Tooltip(
          message: label,
          child: Icon(
            icon,
            size: 16,
            color: isSelected
                ? cs.primary
                : cs.onSurface.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}

/// 多模型回答组卡片。
///
/// 在消息列表中检测同组（相同 multiModelGroupId）的 assistant 消息，
/// 首个消息位置构建整个组，其余同组成员隐藏（SizedBox.shrink）。
///
/// 布局支持：
/// - horizontal（默认）：左右并排
/// - vertical：上下堆叠
/// - grid：九宫格形式（最多3列）
class MultiModelGroupCard extends StatelessWidget {
  const MultiModelGroupCard({
    super.key,
    required this.groupMessages,
    required this.groupLayout,
    required this.onLayoutChanged,
    required this.buildMessageCard,
  });

  final List<ChatMessage> groupMessages;
  final String groupLayout;
  final void Function(String layout) onLayoutChanged;
  final Widget Function(ChatMessage message, {bool compact}) buildMessageCard;

  static const String _layoutHorizontal = 'horizontal';
  static const String _layoutVertical = 'vertical';
  static const String _layoutGrid = 'grid';
  static const double _minCompactCardWidth = 320.0;

  @override
  Widget build(BuildContext context) {
    if (groupMessages.isEmpty) return const SizedBox.shrink();

    final helperL10n = _helperL10n(context);
    final currentLayout = ChatMultiModelLayout.normalize(groupLayout);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 布局切换栏
        _buildLayoutBar(context, currentLayout, helperL10n),
        const SizedBox(height: 4),
        // 卡片内容
        _buildLayoutContent(context, currentLayout),
      ],
    );
  }

  Widget _buildLayoutBar(
    BuildContext context,
    String currentLayout,
    AppLocalizations l10n,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LayoutToggleButton(
            icon: Icons.view_column_rounded,
            label: l10n.multiModelLayoutHorizontal,
            isSelected: currentLayout == _layoutHorizontal,
            onTap: () => onLayoutChanged(_layoutHorizontal),
          ),
          const SizedBox(width: 4),
          _LayoutToggleButton(
            icon: Icons.view_agenda_rounded,
            label: l10n.multiModelLayoutVertical,
            isSelected: currentLayout == _layoutVertical,
            onTap: () => onLayoutChanged(_layoutVertical),
          ),
          const SizedBox(width: 4),
          _LayoutToggleButton(
            icon: Icons.grid_view_rounded,
            label: l10n.multiModelLayoutGrid,
            isSelected: currentLayout == _layoutGrid,
            onTap: () => onLayoutChanged(_layoutGrid),
          ),
          const SizedBox(width: 8),
          Text(
            l10n.multiModelResponseCount(groupMessages.length),
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLayoutContent(BuildContext context, String layout) {
    switch (layout) {
      case _layoutVertical:
        return _buildVerticalLayout(context);
      case _layoutGrid:
        return _buildGridLayout(context);
      case _layoutHorizontal:
      default:
        return _buildHorizontalLayout(context);
    }
  }

  Widget _buildHorizontalLayout(BuildContext context) {
    if (groupMessages.length == 1) {
      return buildMessageCard(groupMessages.first, compact: false);
    }

    final count = groupMessages.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 500) {
          // 宽度过窄时回退到纵向布局，避免横向卡片挤压。
          return _buildVerticalLayout(context);
        }

        final itemWidth = (constraints.maxWidth / count).clamp(
          _minCompactCardWidth,
          double.infinity,
        );
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final msg in groupMessages)
                SizedBox(
                  width: itemWidth,
                  child: buildMessageCard(msg, compact: true),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVerticalLayout(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final msg in groupMessages) buildMessageCard(msg, compact: false),
      ],
    );
  }

  Widget _buildGridLayout(BuildContext context) {
    if (groupMessages.length == 1) {
      return buildMessageCard(groupMessages.first, compact: false);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final widthBasedColumns = (constraints.maxWidth / _minCompactCardWidth)
            .floor()
            .clamp(1, 3)
            .toInt();
        final crossAxisCount = groupMessages.length < widthBasedColumns
            ? groupMessages.length
            : widthBasedColumns;
        final childAspectRatio =
            constraints.maxWidth / (crossAxisCount * _minCompactCardWidth);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio.clamp(0.6, 1.2),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: groupMessages.length,
          itemBuilder: (context, index) {
            return buildMessageCard(groupMessages[index], compact: true);
          },
        );
      },
    );
  }

  AppLocalizations _helperL10n(BuildContext context) {
    return AppLocalizations.of(context)!;
  }
}

/// 辅助函数：检测消息是否为同一多模型组的成员，并返回组。
/// 如果消息不属于多模型组或不是第一成员，返回 null。
List<ChatMessage>? findMultiModelGroup(List<ChatMessage> messages, int index) {
  final msg = messages[index];
  final groupId = msg.multiModelGroupId;
  if (groupId == null || msg.role != 'assistant') return null;

  // 只让组内第一条消息负责渲染整个分组。
  for (int i = 0; i < index; i++) {
    if (messages[i].multiModelGroupId == groupId) return null;
  }

  // 收集当前分组的所有消息。
  final group = <ChatMessage>[];
  for (int i = index; i < messages.length; i++) {
    if (messages[i].multiModelGroupId == groupId) {
      group.add(messages[i]);
    }
  }
  return group.length > 1 ? group : null;
}
