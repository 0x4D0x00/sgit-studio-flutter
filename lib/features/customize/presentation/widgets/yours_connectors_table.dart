import 'package:flutter/material.dart';
import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';

import 'customize_models.dart';

/// "Yours" view for Connectors - table layout with Connector/Type/Status columns
class YoursConnectorsTable extends StatelessWidget {
  const YoursConnectorsTable({
    super.key,
    required this.items,
    required this.skin,
    required this.onConnect,
  });

  final List<YourConnectorItem> items;
  final AppSkin skin;
  final Function(YourConnectorItem) onConnect;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Container(
          decoration: BoxDecoration(
            color: skin.containerBg,
            border: Border.all(color: skin.border, width: 1),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            children: [
              _buildTableHeader(skin),
              Divider(height: 1, thickness: 1, color: skin.border),
              for (int i = 0; i < items.length; i++) ...[
                _YourConnectorItemRow(
                  item: items[i],
                  skin: skin,
                  onConnect: () => onConnect(items[i]),
                ),
                if (i < items.length - 1)
                  Divider(height: 1, thickness: 1, color: skin.border),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader(AppSkin skin) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
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
          SizedBox(
            width: 100,
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
}

class _YourConnectorItemRow extends StatefulWidget {
  const _YourConnectorItemRow({
    required this.item,
    required this.skin,
    required this.onConnect,
  });

  final YourConnectorItem item;
  final AppSkin skin;
  final VoidCallback onConnect;

  @override
  State<_YourConnectorItemRow> createState() => _YourConnectorItemRowState();
}

class _YourConnectorItemRowState extends State<_YourConnectorItemRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(AppSpacing.md),
        color: _hovering
            ? widget.skin.textSecondary.withValues(alpha: 0.03)
            : Colors.transparent,
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: widget.skin.textSecondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                      widget.item.icon,
                      size: 18,
                      color: widget.item.color,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      widget.item.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: widget.skin.text,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                widget.item.type,
                style: TextStyle(
                  fontSize: 14,
                  color: widget.skin.textSecondary,
                ),
              ),
            ),
            SizedBox(
              width: 100,
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
                  widget.item.status,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
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
