import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/features/settings/presentation/widgets/settings_section.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/ui/components/menu/app_menu.dart';

/// 设置弹窗里的「能力」页面：工具访问模式 / 连接器搜索 / 模型切换 /
/// 视觉内容 / 代码执行与文件创建 / 网络出站 / 技能。
///
/// 结构与其它设置页一致（[SettingsSectionHeader] + [SettingsSectionRowWithDesc]），
/// 两处例外：
/// * 「允许网络出站」是**一整块**卡片（底色 + 描边 + 内边距）它是本页唯一带「有风险」语义的开关
/// * 「技能」句中「Customize」是可点链接，由设置弹窗注入 [onOpenSkills]。
class CapabilitiesPage extends StatefulWidget {
  const CapabilitiesPage({super.key, this.onOpenSkills});

  /// 点「技能已移至 Customize」里的 Customize 链接时触发。
  /// 由设置弹窗注入（见 `_SettingsDialogState._onCustomizeItemTap`）：中栏若正
  /// 停在 Customize 页面就直接切那边的标签并关掉弹窗，否则在弹窗内切到「技能」页。
  final VoidCallback? onOpenSkills;

  @override
  State<CapabilitiesPage> createState() => _CapabilitiesPageState();
}

class _CapabilitiesPageState extends State<CapabilitiesPage> {
  /// 工具访问模式是**单选**而非开关 —— 当前档显示为「按需加载工具」。
  ///
  /// 现在只有这一档，菜单里先挂一条；后续加档（如「始终加载」）只往
  /// [_toolAccessModes] 里补一项，行与菜单都不用改。
  static const String _loadWhenNeeded = 'load_when_needed';

  /// 「技能已移至 Customize」里链接的文案。固定英文，见 [_skillsMovedText]。
  static const String _customizeLabel = 'Customize';

  String _toolAccessMode = _loadWhenNeeded;
  bool _connectorSearch = true;
  bool _switchModels = true;

  bool _artifacts = true;
  bool _aiArtifacts = false;
  bool _inlineVisualizations = true;

  bool _codeExecution = true;
  bool _networkEgress = true;

  void _notWired(String what) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.commonNotWired(what)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final skin = AppSkin.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // ============ General ============
        SettingsSectionHeader(l10n.settingsGeneral),
        const SizedBox(height: AppSpacing.sm),

        // 工具访问模式
        SettingsSectionRowWithDesc(
          title: l10n.capabilitiesToolAccessMode,
          description: l10n.capabilitiesToolAccessModeDesc,
          trailing: _DropdownRow<String>(
            value: _toolAccessMode,
            options: const [(_loadWhenNeeded, _loadWhenNeeded)],
            labelOf: (v) => switch (v) {
              _loadWhenNeeded => l10n.capabilitiesToolAccessLoadWhenNeeded,
              _ => v,
            },
            onChanged: (v) => setState(() => _toolAccessMode = v),
          ),
        ),
        const SettingsSectionDivider(),

        // 连接器搜索
        SettingsSectionRowWithDesc(
          title: l10n.capabilitiesConnectorSearch,
          description: l10n.capabilitiesConnectorSearchDesc,
          trailing: Switch(
            value: _connectorSearch,
            onChanged: (v) => setState(() => _connectorSearch = v),
          ),
        ),
        const SettingsSectionDivider(),

        // 消息被标记时切换模型
        SettingsSectionRowWithDesc(
          title: l10n.capabilitiesSwitchModels,
          description: l10n.capabilitiesSwitchModelsDesc,
          trailing: Switch(
            value: _switchModels,
            onChanged: (v) => setState(() => _switchModels = v),
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // ============ Visuals ============
        SettingsSectionHeader(l10n.capabilitiesVisuals),
        const SizedBox(height: AppSpacing.sm),

        SettingsSectionRowWithDesc(
          title: l10n.capabilitiesArtifacts,
          description: l10n.capabilitiesArtifactsDesc,
          trailing: Switch(
            value: _artifacts,
            onChanged: (v) => setState(() => _artifacts = v),
          ),
        ),
        const SettingsSectionDivider(),

        SettingsSectionRowWithDesc(
          title: l10n.capabilitiesAiArtifacts,
          description: l10n.capabilitiesAiArtifactsDesc,
          trailing: Switch(
            value: _aiArtifacts,
            onChanged: (v) => setState(() => _aiArtifacts = v),
          ),
        ),
        const SettingsSectionDivider(),

        SettingsSectionRowWithDesc(
          title: l10n.capabilitiesInlineVisualizations,
          description: l10n.capabilitiesInlineVisualizationsDesc,
          trailing: Switch(
            value: _inlineVisualizations,
            onChanged: (v) => setState(() => _inlineVisualizations = v),
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // ============ Code execution and file creation ============
        SettingsSectionHeader(l10n.capabilitiesCodeExecution),
        const SizedBox(height: AppSpacing.sm),

        SettingsSectionRowWithDesc(
          title: l10n.capabilitiesCodeExecution,
          description: l10n.capabilitiesCodeExecutionDesc,
          trailing: Switch(
            value: _codeExecution,
            onChanged: (v) => setState(() => _codeExecution = v),
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // 网络出站 —— 整块卡片，见类注释。
        _NetworkEgressCard(
          enabled: _networkEgress,
          onChanged: (v) => setState(() => _networkEgress = v),
          description: _networkEgressDescription(context, l10n, skin),
        ),

        const SizedBox(height: AppSpacing.md),

        // ============ Skills ============
        SettingsSectionHeader(l10n.capabilitiesSkills),
        const SizedBox(height: AppSpacing.xs),
        _skillsMovedText(context, l10n, skin),
      ],
    );
  }

  /// 「技能已移至 Customize」这句：句中嵌一个可点的 Customize 链接。
  ///
  /// 与 [_networkEgressDescription] 同一套做法 —— 本地化串带占位符，按占位符
  /// 切段后用 [WidgetSpan] 包 [InkWell]，链接的悬停光标与主题色都跟着走。
  /// 这里只有一个占位符，切段比那边（两个、且顺序因语言而异）简单得多。
  Widget _skillsMovedText(
    BuildContext context,
    AppLocalizations l10n,
    AppSkin skin,
  ) {
    final bodyStyle = TextStyle(fontSize: 14, color: skin.textSecondary);
    // 链接文案固定用英文 "Customize" —— 它是功能名，与 Customize 页顶部的标题
    // 一致，不随界面语言翻译（所以不能取 l10n.settingsCustomize，中文下那是「自定义」）。
    const label = _customizeLabel;
    final text = l10n.capabilitiesSkillsMoved(label);
    final index = text.indexOf(label);

    // 占位符没被翻译替换掉时（如译文漏写 {customize}）退化成纯文本，不摆一个点不动的链接。
    if (index < 0) return Text(text, style: bodyStyle);

    final linkStyle = bodyStyle.copyWith(
      color: Theme.of(context).colorScheme.primary,
      decoration: TextDecoration.underline,
    );

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text.substring(0, index), style: bodyStyle),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: InkWell(
              onTap: widget.onOpenSkills,
              child: Text(label, style: linkStyle),
            ),
          ),
          TextSpan(text: text.substring(index + label.length), style: bodyStyle),
        ],
      ),
    );
  }

  /// 「允许网络出站」的说明句：句中嵌两个可点链接（查看包管理器域名 / 安全风险）。
  ///
  /// 用 [WidgetSpan] 而不是 `TextSpan.recognizer`：链接在句中的位置随语言而变，
  /// 而本仓库既有的做法（`privacy_page.dart` 的隐私开场白）就是
  /// 「本地化串带占位符 + 按占位符切段 + `WidgetSpan` 包 `InkWell`」。
  /// 保持一致，也让悬停光标与主题色都跟着 [InkWell] 走。
  Widget _networkEgressDescription(
    BuildContext context,
    AppLocalizations l10n,
    AppSkin skin,
  ) {
    final theme = Theme.of(context);
    final bodyStyle = TextStyle(fontSize: 12, height: 1.5, color: skin.textSecondary);
    final linkStyle = bodyStyle.copyWith(
      color: theme.colorScheme.primary,
      decoration: TextDecoration.underline,
    );

    final domains = l10n.capabilitiesNetworkEgressViewDomains;
    final risks = l10n.capabilitiesNetworkEgressSecurityRisks;
    final text = l10n.capabilitiesNetworkEgressDesc(domains, risks);

    /// 把一个链接文案换成可点的 [WidgetSpan]。
    InlineSpan link(String label) => WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: InkWell(
            onTap: () => _notWired(label),
            child: Text(label, style: linkStyle),
          ),
        );

    final spans = <InlineSpan>[];
    for (final part in _splitOnFirst(text, domains, risks)) {
      spans.add(
        switch (part.$1) {
          _DescPart.text => TextSpan(text: part.$2, style: bodyStyle),
          _DescPart.domains => link(part.$2),
          _DescPart.risks => link(part.$2),
        },
      );
    }
    return RichText(text: TextSpan(children: spans));
  }

  /// 按两个链接文案把整句切成「文字 / 域名链接 / 风险链接」的片段序列。
  /// 先出现的那个先切，剩下的继续扫 —— 两个占位符谁在前因语言而异。
  static List<(_DescPart, String)> _splitOnFirst(
    String text,
    String domains,
    String risks,
  ) {
    final parts = <(_DescPart, String)>[];
    var rest = text;
    while (rest.isNotEmpty) {
      final iDomains = rest.indexOf(domains);
      final iRisks = rest.indexOf(risks);
      final (index, kind, label) = switch ((iDomains, iRisks)) {
        (-1, -1) => (-1, _DescPart.text, ''),
        (-1, _) => (iRisks, _DescPart.risks, risks),
        (_, -1) => (iDomains, _DescPart.domains, domains),
        _ when iDomains < iRisks => (iDomains, _DescPart.domains, domains),
        _ => (iRisks, _DescPart.risks, risks),
      };
      if (index < 0) {
        parts.add((_DescPart.text, rest));
        break;
      }
      if (index > 0) parts.add((_DescPart.text, rest.substring(0, index)));
      parts.add((kind, label));
      rest = rest.substring(index + label.length);
    }
    return parts;
  }
}

/// 说明句切出来的片段类型。
enum _DescPart { text, domains, risks }

/// 「允许网络出站」卡片：底色 + 描边 + 内边距，标题加粗，说明里嵌链接。
class _NetworkEgressCard extends StatelessWidget {
  const _NetworkEgressCard({
    required this.enabled,
    required this.onChanged,
    required this.description,
  });

  final bool enabled;
  final ValueChanged<bool> onChanged;
  final Widget description;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: skin.containerBgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: skin.borderSecondary),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).capabilitiesNetworkEgress,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: skin.text,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                description,
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Switch(value: enabled, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// 通用值下拉框：当前值 + 下拉箭头，点开 [AppMenuAnchor] 单选列表。
///
/// [labelOf] 按**值**取文案，不直接把值当显示名 —— 值可能是内部标识
/// （`load_when_needed` 要显示成「按需加载工具」）。
class _DropdownRow<T> extends StatelessWidget {
  const _DropdownRow({
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
  });

  final T value;
  final List<(T, T)> options;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    return AppMenuAnchor(
      entries: [
        AppMenuRadioGroup<T>(
          values: options.map((o) => o.$2).toList(growable: false),
          selected: value,
          labelOf: labelOf,
          onSelect: onChanged,
        ),
      ],
      align: AppMenuAlign.underEnd,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: skin.border),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(labelOf(value), style: TextStyle(fontSize: 14, color: skin.text)),
            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.keyboard_arrow_down, size: 18, color: skin.textSecondary),
          ],
        ),
      ),
    );
  }
}
