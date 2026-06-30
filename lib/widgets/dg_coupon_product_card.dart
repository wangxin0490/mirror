import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import '../utils/dg_coupon_parser.dart';
import 'mirror_pressable.dart';

/// 石化优惠券产品卡片（图1样式：标题 + 产品码·面额 + 查库存/复制产品码）。
class DgCouponProductCard extends StatelessWidget {
  const DgCouponProductCard({
    super.key,
    required this.product,
    this.onQueryStock,
    this.onCopyFeedback,
  });

  final DgCouponProduct product;
  final ValueChanged<String>? onQueryStock;
  final VoidCallback? onCopyFeedback;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[
      if (product.productNo.isNotEmpty) product.productNo,
      if (product.faceValue.isNotEmpty) product.faceValue,
    ];
    final metaParts = <String>[
      if (product.validDays != null && product.validDays! > 0)
        '领取后 ${product.validDays} 天有效',
      if (product.description.trim().isNotEmpty &&
          (product.validDays == null || product.validDays! <= 0))
        _formatDescription(product.description),
      if (product.stock != null) '库存 ${product.stock}',
    ];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: MirrorColors.bgApp,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MirrorColors.borderSoft),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 3,
                height: 36,
                margin: const EdgeInsets.only(top: 2, right: 10),
                decoration: BoxDecoration(
                  color: MirrorColors.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name.isNotEmpty ? product.name : product.productNo,
                      style: MirrorTheme.sans(
                        fontSize: 15,
                        height: 1.35,
                        weight: FontWeight.w600,
                        color: MirrorColors.text,
                      ),
                    ),
                    if (subtitleParts.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitleParts.join(' · '),
                        style: MirrorTheme.sans(
                          fontSize: 12,
                          height: 1.4,
                          color: MirrorColors.text3,
                        ),
                      ),
                    ],
                    if (metaParts.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final meta in metaParts)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: MirrorColors.bgSoft,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                meta,
                                style: MirrorTheme.sans(
                                  fontSize: 11,
                                  height: 1.3,
                                  color: MirrorColors.text2,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: '查库存',
                  filled: true,
                  onTap: product.productNo.isEmpty || onQueryStock == null
                      ? null
                      : () => onQueryStock!(product.productNo),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  label: '复制产品码',
                  filled: false,
                  onTap: product.productNo.isEmpty
                      ? null
                      : () async {
                          await Clipboard.setData(
                            ClipboardData(text: product.productNo),
                          );
                          onCopyFeedback?.call();
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatDescription(String raw) {
  final d = raw.trim();
  if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(d)) {
    return '截止 $d';
  }
  return d;
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.filled,
    this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return MirrorPressable(
      onTap: onTap,
      child: Container(
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? MirrorColors.accentSoft : MirrorColors.bgApp,
          borderRadius: BorderRadius.circular(10),
          border: filled
              ? null
              : Border.all(color: MirrorColors.borderSoft),
        ),
        child: Text(
          label,
          style: MirrorTheme.sans(
            fontSize: 13,
            weight: FontWeight.w500,
            color: filled ? MirrorColors.accentDeep : MirrorColors.text2,
          ),
        ),
      ),
    );
  }
}
