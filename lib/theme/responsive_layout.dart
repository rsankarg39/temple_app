import 'package:flutter/material.dart';

/// Width-based layout helpers (phones, large phones, tablets).
class Responsive {
  static const double compactMax = 599;
  static const double mediumMax = 899;

  static double widthOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static bool isCompact(BuildContext context) =>
      widthOf(context) <= compactMax;

  static bool isMedium(BuildContext context) {
    final w = widthOf(context);
    return w > compactMax && w <= mediumMax;
  }

  static bool isExpanded(BuildContext context) => widthOf(context) > mediumMax;

  /// Pick a value by breakpoint: phone / large phone / tablet.
  static double sp(
    BuildContext context, {
    required double compact,
    double? medium,
    double? expanded,
  }) {
    if (isExpanded(context)) return expanded ?? medium ?? compact;
    if (isMedium(context)) return medium ?? compact;
    return compact;
  }

  /// Width-aware text scale (slightly smaller on narrow phones, larger on tablet).
  static TextScaler textScalerFor(BuildContext context, TextScaler base) {
    final w = widthOf(context);
    var factor = 1.0;
    if (w < 360) {
      factor = 0.94;
    } else if (w < 400) {
      factor = 0.97;
    } else if (w > 900) {
      factor = 1.06;
    } else if (w > 600) {
      factor = 1.02;
    }
    final clamped = base.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.12);
    final baseFactor = clamped.scale(12) / 12;
    return TextScaler.linear(baseFactor * factor);
  }

  static TextStyle tabLabelStyle(BuildContext context, {bool selected = true}) {
    return TextStyle(
      fontSize: sp(context, compact: 12, medium: 13, expanded: 14),
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
    );
  }
}

/// App bar title for temple + role row.
class TempleDashboardTitle extends StatelessWidget {
  const TempleDashboardTitle({
    required this.templeName,
    required this.roleLabel,
    super.key,
  });

  final String templeName;
  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          templeName,
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: Responsive.sp(
              context,
              compact: 15,
              medium: 17,
              expanded: 20,
            ),
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          roleLabel,
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: Responsive.sp(
              context,
              compact: 10,
              medium: 11,
              expanded: 12,
            ),
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.6,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

Tab responsiveDashboardTab(
  BuildContext context, {
  required String title,
  String? shortTitle,
}) {
  final label =
      Responsive.isCompact(context) ? (shortTitle ?? title) : title;
  return Tab(
    child: Text(
      label,
      style: Responsive.tabLabelStyle(context),
    ),
  );
}

PreferredSizeWidget responsiveDashboardTabBar(
  BuildContext context,
  List<Tab> tabs,
) {
  final tabFontSize = Responsive.sp(
    context,
    compact: 12,
    medium: 13,
    expanded: 14,
  );
  final hPad = Responsive.sp(
    context,
    compact: 10,
    medium: 12,
    expanded: 16,
  );

  return TabBar(
    isScrollable: true,
    tabAlignment: TabAlignment.start,
    labelPadding: EdgeInsets.symmetric(horizontal: hPad),
    labelStyle: TextStyle(
      fontSize: tabFontSize,
      fontWeight: FontWeight.w600,
    ),
    unselectedLabelStyle: TextStyle(
      fontSize: tabFontSize,
      fontWeight: FontWeight.w500,
    ),
    tabs: tabs,
  );
}

IconData dashboardTabIcon(String title) {
  switch (title) {
    case 'User Roles':
      return Icons.manage_accounts_outlined;
    case 'Profiles':
      return Icons.person_outline;
    case 'Family Heads':
      return Icons.groups_2_outlined;
    case 'Committee':
    case 'Committee Details':
      return Icons.badge_outlined;
    case 'Payments':
      return Icons.payments_outlined;
    case 'Pooja':
      return Icons.temple_hindu_outlined;
    case 'Events':
      return Icons.event_outlined;
    case 'Birthdays':
      return Icons.cake_outlined;
    case 'Employees':
      return Icons.work_outline;
    case 'Temple Ops':
      return Icons.build_circle_outlined;
    case 'Admin Details':
      return Icons.admin_panel_settings_outlined;
    default:
      return Icons.circle_outlined;
  }
}
