import 'package:flutter/material.dart';
import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';

import '../../data/customize_models.dart';

/// Connectors + Yours 页面的表格样式
class YoursConnectorTable extends StatelessWidget {
  const YoursConnectorTable({
    super.key,
    required this.skin,
    required this.connectors,
    required this.onConnect,
  });

  final AppSkin skin;
  final List<YoursConnectorRow> connectors;

  /// Status 列按钮点击回调，交互暂未接通。
  final void Function(YoursConnectorRow connector) onConnect;

  @override
  Widget build(BuildContext context) {
    return  Column(
        children: [
          _buildHeader(),
          ...connectors.map((connector) => _buildRow(connector)),
        ],
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: skin.border.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              'Connector',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: skin.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Type',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: skin.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Status',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: skin.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(YoursConnectorRow connector) {
    return _YoursConnectorRowWidget(
      connector: connector,
      skin: skin,
      onConnect: () => onConnect(connector),
    );
  }
}

class _YoursConnectorRowWidget extends StatefulWidget {
  const _YoursConnectorRowWidget({
    required this.connector,
    required this.skin,
    required this.onConnect,
  });

  final YoursConnectorRow connector;
  final AppSkin skin;
  final VoidCallback onConnect;

  @override
  State<_YoursConnectorRowWidget> createState() => _YoursConnectorRowWidgetState();
}

class _YoursConnectorRowWidgetState extends State<_YoursConnectorRowWidget> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: _hovering
              ? widget.skin.textSecondary.withValues(alpha: 0.05)
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: widget.skin.border.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: widget.skin.textSecondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      widget.connector.icon,
                      size: 14,
                      color: widget.skin.text,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    widget.connector.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: widget.skin.text,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                widget.connector.type,
                style: TextStyle(
                  fontSize: 14,
                  color: widget.skin.textSecondary,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: widget.onConnect,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: widget.skin.text,
                    side: BorderSide(color: widget.skin.border, width: 1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    minimumSize: const Size(0, 32),
                  ),
                  child: Text(
                    widget.connector.status,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
