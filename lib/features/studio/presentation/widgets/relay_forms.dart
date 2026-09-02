import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/domain/models/studio/relay_models.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';

/// 中转站的两个表单弹窗（厂商 / 模型）。
///
/// 抽出来单独一份，是因为 `relay_page.dart` 已经承担三层视图 + 工具栏，再塞两个
/// 9 字段表单会变成谁都不想碰的巨型文件。表单只负责**产出草稿**，不碰网络。
///
/// 字段与 React studio 的两个 Modal 逐项对齐（含哪些字段编辑时禁改）。

/// 厂商表单。返回编辑好的草稿，取消返回 null。
///
/// [isNew] 决定 `model_code`（主键）可否编辑。编辑态改主键等于换一个厂商，
/// 所以锁死 —— 与 React studio 的 `disabled={!isProvNew}` 一致。
Future<RelayProvider?> showProviderForm(
  BuildContext context, {
  required RelayProvider draft,
  required bool isNew,
}) =>
    showDialog<RelayProvider>(
      context: context,
      builder: (_) => _ProviderForm(draft: draft, isNew: isNew),
    );

/// 模型表单。
///
/// `model_code`（所属厂商）永远不可改；`model_name` 仅新增时可填 —— 它是这一行的
/// 业务主键，改名等于删旧建新。
Future<RelayModel?> showModelForm(
  BuildContext context, {
  required RelayModel draft,
  required bool isNew,
}) =>
    showDialog<RelayModel>(
      context: context,
      builder: (_) => _ModelForm(draft: draft, isNew: isNew),
    );

// ---------------------------------------------------------------------------

class _ProviderForm extends StatefulWidget {
  const _ProviderForm({required this.draft, required this.isNew});

  final RelayProvider draft;
  final bool isNew;

  @override
  State<_ProviderForm> createState() => _ProviderFormState();
}

class _ProviderFormState extends State<_ProviderForm> {
  late final _code = TextEditingController(text: widget.draft.code);
  late final _provider = TextEditingController(text: widget.draft.provider);
  late final _name = TextEditingController(text: widget.draft.name);
  late final _baseUrl = TextEditingController(text: widget.draft.baseUrl);
  late final _endpoint = TextEditingController(text: widget.draft.endpoint);
  late final _modelsEndpoint =
      TextEditingController(text: widget.draft.modelsEndpoint);
  late final _uploadBaseUrl =
      TextEditingController(text: widget.draft.uploadBaseUrl);
  late final _priority =
      TextEditingController(text: widget.draft.priority.toString());
  late String _modelType = widget.draft.modelType;

  String? _err;

  @override
  void dispose() {
    for (final c in [
      _code,
      _provider,
      _name,
      _baseUrl,
      _endpoint,
      _modelsEndpoint,
      _uploadBaseUrl,
      _priority,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit(AppLocalizations l10n) {
    final code = _code.text.trim();
    if (code.isEmpty) {
      setState(() => _err = l10n.relayRequiredModelCode);
      return;
    }
    Navigator.of(context).pop(widget.draft.copyWith(
      code: code,
      provider: _provider.text.trim(),
      name: _name.text.trim(),
      baseUrl: _baseUrl.text.trim(),
      endpoint: _endpoint.text.trim(),
      modelsEndpoint: _modelsEndpoint.text.trim(),
      uploadBaseUrl: _uploadBaseUrl.text.trim(),
      modelType: _modelType,
      priority: int.tryParse(_priority.text.trim()) ?? 0,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _shell(
      context: context,
      title: widget.isNew
          ? l10n.relayAddProvider
          : '${l10n.relayEditProvider} · ${widget.draft.code}',
      error: _err,
      onSubmit: () => _submit(l10n),
      fields: [
        _field(
          label: l10n.relayFieldModelCode,
          controller: _code,
          hint: 'model_code（唯一，如 DeepSeek）',
          // 主键：编辑时锁死。
          enabled: widget.isNew,
        ),
        _field(
          label: l10n.relayFieldProvider,
          controller: _provider,
          hint: 'provider（logo/分组，如 openai / deepseek）',
        ),
        _field(label: l10n.relayFieldDisplayName, controller: _name),
        _field(
            label: l10n.relayFieldBaseUrl,
            controller: _baseUrl,
            hint: '上游 API base url'),
        _field(
            label: l10n.relayFieldEndpoint,
            controller: _endpoint,
            hint: '/v1/chat/completions'),
        _field(
            label: l10n.relayFieldModelsEndpoint,
            controller: _modelsEndpoint,
            hint: '/v1/models（同步模型用）'),
        _field(
            label: l10n.relayFieldUploadBaseUrl,
            controller: _uploadBaseUrl,
            hint: '（可选）'),
        Row(
          children: [
            Expanded(
              child: _segmented(
                label: l10n.relayFieldModelType,
                value: _modelType,
                options: const ['external', 'internal'],
                onChanged: (v) => setState(() => _modelType = v),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 120,
              child: _field(
                label: l10n.relayFieldPriority,
                controller: _priority,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _ModelForm extends StatefulWidget {
  const _ModelForm({required this.draft, required this.isNew});

  final RelayModel draft;
  final bool isNew;

  @override
  State<_ModelForm> createState() => _ModelFormState();
}

class _ModelFormState extends State<_ModelForm> {
  late final _name = TextEditingController(text: widget.draft.name);
  late final _display = TextEditingController(text: widget.draft.displayName);
  late final _ctx = TextEditingController(
      text: widget.draft.contextWindow?.toString() ?? '');
  late final _maxOut = TextEditingController(
      text: widget.draft.maxOutputTokens?.toString() ?? '');
  late bool _available = widget.draft.available;

  String? _err;

  @override
  void dispose() {
    for (final c in [_name, _display, _ctx, _maxOut]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit(AppLocalizations l10n) {
    final name = _name.text.trim();
    if (name.isEmpty || widget.draft.providerCode.isEmpty) {
      setState(() => _err = l10n.relayRequiredModelName);
      return;
    }
    Navigator.of(context).pop(RelayModel(
      name: name,
      displayName: _display.text.trim(),
      providerCode: widget.draft.providerCode,
      available: _available,
      contextWindow: int.tryParse(_ctx.text.trim()),
      maxOutputTokens: int.tryParse(_maxOut.text.trim()),
      tag: widget.draft.tag,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final code = widget.draft.providerCode;
    return _shell(
      context: context,
      title:
          '${widget.isNew ? l10n.relayAddModel : l10n.relayEditModel} · $code',
      error: _err,
      onSubmit: () => _submit(l10n),
      fields: [
        // 所属厂商：只读展示，永远不可改。
        _readonly(context, l10n.relayFieldModelCode, code),
        _field(
          label: l10n.relayFieldModelName,
          controller: _name,
          hint: 'model_name（唯一，如 deepseek-chat）',
          // 业务主键：编辑时锁死。
          enabled: widget.isNew,
        ),
        _field(label: l10n.relayFieldDisplayName, controller: _display),
        Row(
          children: [
            Expanded(
              child: _field(
                label: l10n.relayFieldContextWindow,
                controller: _ctx,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _field(
                label: l10n.relayFieldMaxOutput,
                controller: _maxOut,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(l10n.relayFieldAvailable,
              style: const TextStyle(fontSize: 13)),
          value: _available,
          onChanged: (v) => setState(() => _available = v),
        ),
      ],
    );
  }
}

// ---- 共用外壳与字段 ----

/// 两个表单共用的弹窗外壳。表单一多，外壳就该只有一份。
Widget _shell({
  required BuildContext context,
  required String title,
  required String? error,
  required VoidCallback onSubmit,
  required List<Widget> fields,
}) {
  final l10n = AppLocalizations.of(context);
  final scheme = Theme.of(context).colorScheme;
  return AlertDialog(
    title: Text(title, style: const TextStyle(fontSize: 15)),
    // 字段多，给个上限并允许滚动 —— 窄屏下不给滚就直接溢出。
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(error,
                    style: TextStyle(fontSize: 12, color: scheme.error)),
              ),
            for (final f in fields)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: f,
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(l10n.commonCancel),
      ),
      FilledButton(onPressed: onSubmit, child: Text(l10n.commonSave)),
    ],
  );
}

Widget _field({
  required String label,
  required TextEditingController controller,
  String? hint,
  bool enabled = true,
  TextInputType? keyboardType,
}) =>
    TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12),
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );

/// 只读字段。用 disabled 的 TextField 而不是 Text，是为了和上下字段等高对齐。
Widget _readonly(BuildContext context, String label, String value) => TextField(
      enabled: false,
      controller: TextEditingController(text: value),
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );

Widget _segmented({
  required String label,
  required String value,
  required List<String> options,
  required ValueChanged<String> onChanged,
}) =>
    InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      child: SegmentedButton<String>(
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
        showSelectedIcon: false,
        segments: [
          for (final o in options)
            ButtonSegment(
                value: o, label: Text(o, style: const TextStyle(fontSize: 12))),
        ],
        selected: {value},
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
