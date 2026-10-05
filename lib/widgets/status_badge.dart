import 'package:flutter/material.dart';
import '../core/theme.dart';

enum ComponentStatusType {
  available,
  low,
  depleted,
  checkedOut;

  static ComponentStatusType fromString(String? val) {
    if (val == null) return ComponentStatusType.available;
    switch (val.toLowerCase().trim()) {
      case 'low':
      case 'low stock':
        return ComponentStatusType.low;
      case 'depleted':
      case 'out of stock':
        return ComponentStatusType.depleted;
      case 'checked out':
      case 'checkedout':
        return ComponentStatusType.checkedOut;
      case 'available':
      default:
        return ComponentStatusType.available;
    }
  }

  String get label {
    switch (this) {
      case ComponentStatusType.available:
        return 'AVAILABLE';
      case ComponentStatusType.low:
        return 'LOW';
      case ComponentStatusType.depleted:
        return 'DEPLETED';
      case ComponentStatusType.checkedOut:
        return 'CHECKED OUT';
    }
  }

  String get symbol {
    switch (this) {
      case ComponentStatusType.available:
        return '●'; // Filled circle
      case ComponentStatusType.low:
        return '◑'; // Half-filled circle
      case ComponentStatusType.depleted:
        return '○'; // Empty circle
      case ComponentStatusType.checkedOut:
        return '⊗'; // Crossed circle
    }
  }

  Color get color {
    switch (this) {
      case ComponentStatusType.available:
        return AppColors.statusOk;
      case ComponentStatusType.low:
        return AppColors.statusLow;
      case ComponentStatusType.depleted:
        return AppColors.statusDepleted;
      case ComponentStatusType.checkedOut:
        return AppColors.dim;
    }
  }
}

class StatusBadge extends StatelessWidget {
  final ComponentStatusType status;
  final bool showLabel;
  final double fontSize;

  const StatusBadge({
    super.key,
    required this.status,
    this.showLabel = true,
    this.fontSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    if (!showLabel) {
      return Text(
        status.symbol,
        style: TextStyle(
          fontSize: fontSize + 2,
          color: status.color,
          height: 1,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.zero,
        border: Border.all(
          color: status == ComponentStatusType.available
              ? AppColors.border
              : AppColors.borderSubtle,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            status.symbol,
            style: TextStyle(
              fontSize: fontSize + 1,
              color: status.color,
              height: 1,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: AppTypography.mono(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: status.color,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}
