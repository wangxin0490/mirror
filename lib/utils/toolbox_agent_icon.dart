import 'package:flutter/material.dart';

/// 工具箱智能体 icon_key → Material Icons。
IconData toolboxAgentIcon(String iconKey) => switch (iconKey) {
      'smart_toy' => Icons.smart_toy_outlined,
      'description' => Icons.description_outlined,
      'auto_fix' => Icons.auto_fix_high_outlined,
      'summarize' => Icons.summarize_outlined,
      'local_gas_station' => Icons.local_gas_station_outlined,
      'mic' => Icons.mic_outlined,
      'auto_awesome' => Icons.auto_awesome_outlined,
      _ => Icons.extension_outlined,
    };
