import 'package:flutter/material.dart';

import '../baby_photo.dart';
import '../common.dart';
import '../growth_page.dart';
import '../nestling_mark.dart';
import '../routines_page.dart';
import '../settings_page.dart';
import '../theme.dart';

/// A sidebar destination.
typedef NavDestination = ({String label, IconData icon, IconData selectedIcon});

/// Left sidebar of the desktop layout: app name, baby switcher, search,
/// navigation, and sync status and settings at the bottom. With [expanded]
/// false it is a slim icon rail with tooltips.
class DesktopSidebar extends StatelessWidget {
  const DesktopSidebar({
    super.key,
    required this.destinations,
    required this.selected,
    required this.onSelect,
    required this.onSearch,
    required this.expanded,
    this.profile = '',
  });

  final List<NavDestination> destinations;
  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onSearch;
  final bool expanded;
  final String profile;

  @override
  Widget build(BuildContext context) {
    final width = expanded
        ? DesktopTokens.sidebarWidth
        : DesktopTokens.railWidth;
    return Container(
      key: const ValueKey('desktop-sidebar'),
      width: width,
      decoration: BoxDecoration(
        color: Baby.sidebar,
        border: Border(right: BorderSide(color: Baby.border)),
      ),
      // Fills the height; scrolls when the window is too short.
      child: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: expanded ? 12 : 10,
                vertical: 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Brand(expanded: expanded, profile: profile),
                  const SizedBox(height: 14),
                  _BabySwitcher(expanded: expanded),
                  const SizedBox(height: 10),
                  if (expanded)
                    SearchTrigger(onTap: onSearch)
                  else
                    SidebarItem(
                      icon: Icons.search_rounded,
                      label: 'Search',
                      expanded: false,
                      onTap: onSearch,
                    ),
                  const SizedBox(height: 14),
                  if (expanded) const _GroupLabel('Navigate'),
                  for (var i = 0; i < destinations.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: SidebarItem(
                        key: ValueKey('nav-${destinations[i].label}'),
                        icon: i == selected
                            ? destinations[i].selectedIcon
                            : destinations[i].icon,
                        label: destinations[i].label,
                        selected: i == selected,
                        expanded: expanded,
                        shortcut: Desktop.shortcut('${i + 1}'),
                        onTap: () => onSelect(i),
                      ),
                    ),
                  const Spacer(),
                  const SizedBox(height: 16),
                  Align(
                    alignment: expanded
                        ? Alignment.centerLeft
                        : Alignment.center,
                    child: SyncChip(compact: !expanded),
                  ),
                  const SizedBox(height: 6),
                  SidebarItem(
                    key: const ValueKey('nav-Settings'),
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    expanded: expanded,
                    shortcut: Desktop.shortcut(','),
                    onTap: () => openSettings(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
    child: LText(
      text,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
        color: Baby.muted,
      ),
    ),
  );
}

class _Brand extends StatelessWidget {
  const _Brand({required this.expanded, required this.profile});
  final bool expanded;
  final String profile;

  @override
  Widget build(BuildContext context) {
    final logo = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: Baby.hero),
        borderRadius: BorderRadius.circular(DesktopTokens.radius),
      ),
      child: const CustomPaint(
        painter: NestlingMark(layer: MarkLayer.bare, sparkle: Colors.white),
      ),
    );
    if (!expanded) return Center(child: logo);
    return Row(
      children: [
        const SizedBox(width: 4),
        logo,
        const SizedBox(width: 10),
        Expanded(
          child: LText.raw(
            profile.isEmpty ? 'Nestling' : 'Nestling [$profile]',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: Baby.ink,
            ),
          ),
        ),
      ],
    );
  }
}

/// Shows the selected baby; opens a menu to switch, add or edit.
class _BabySwitcher extends StatelessWidget {
  const _BabySwitcher({required this.expanded});
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final baby = app.activeBaby;
    final name = baby.name.isEmpty ? tr('Baby') : baby.name;
    return PopupMenuButton<String>(
      tooltip: tr('Switch baby'),
      position: PopupMenuPosition.under,
      offset: const Offset(0, 4),
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 280),
      onSelected: (value) {
        switch (value) {
          case 'add':
            showAddBaby(context);
          case 'edit':
            editBabyProfile(context);
          default:
            if (!app.selectBaby(value)) {
              showMessage(
                context,
                'Save or stop the feed timer before switching babies.',
              );
            }
        }
      },
      itemBuilder: (_) => [
        for (final b in app.babies)
          PopupMenuItem(
            value: b.id,
            height: 40,
            child: Row(
              children: [
                BabyPhoto(photo: b.photo, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: LText.raw(
                    b.name.isEmpty ? tr('Baby') : b.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (b.id == app.activeBabyId)
                  Icon(Icons.check_rounded, size: 18, color: Baby.primary),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'edit',
          height: 40,
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 18, color: Baby.muted),
              const SizedBox(width: 10),
              const LText('Edit profile'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'add',
          height: 40,
          child: Row(
            children: [
              Icon(Icons.person_add_alt_1_rounded, size: 18, color: Baby.muted),
              const SizedBox(width: 10),
              const LText('Add a baby'),
            ],
          ),
        ),
      ],
      child: Container(
        padding: EdgeInsets.all(expanded ? 8 : 4),
        decoration: BoxDecoration(
          color: Baby.card,
          border: Border.all(color: Baby.border),
          borderRadius: BorderRadius.circular(DesktopTokens.radius + 2),
        ),
        child: expanded
            ? Row(
                children: [
                  BabyPhoto(photo: baby.photo, size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LText.raw(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (app.babies.length > 1)
                          LText(
                            '${app.babies.length} babies',
                            style: TextStyle(
                              fontSize: 12,
                              color: Baby.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.unfold_more_rounded, size: 18, color: Baby.muted),
                ],
              )
            : Center(child: BabyPhoto(photo: baby.photo, size: 34)),
      ),
    );
  }
}

/// A navigation row with hover, selected and keyboard focus states.
class SidebarItem extends StatefulWidget {
  const SidebarItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.expanded,
    this.selected = false,
    this.shortcut,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool expanded;
  final bool selected;
  final String? shortcut;

  @override
  State<SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<SidebarItem> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final color = selected ? Baby.ink : Baby.muted;
    final item = Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: widget.onTap,
        onHover: (v) => setState(() => _hover = v),
        onFocusChange: (v) => setState(() => _focus = v),
        borderRadius: BorderRadius.circular(DesktopTokens.radius),
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 38,
          padding: EdgeInsets.symmetric(horizontal: widget.expanded ? 10 : 0),
          decoration: BoxDecoration(
            color: selected
                ? Baby.card
                : _hover
                ? Baby.hover
                : Colors.transparent,
            borderRadius: BorderRadius.circular(DesktopTokens.radius),
            border: Border.all(
              color: _focus
                  ? Baby.ring
                  : selected
                  ? Baby.border
                  : Colors.transparent,
              width: _focus ? 2 : 1,
            ),
          ),
          child: widget.expanded
              ? Row(
                  children: [
                    Icon(
                      widget.icon,
                      size: 19,
                      color: selected ? Baby.primary : color,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: LText(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                    if (_hover && widget.shortcut != null)
                      LText.raw(
                        widget.shortcut!,
                        style: TextStyle(fontSize: 11.5, color: Baby.muted),
                      ),
                  ],
                )
              : Center(
                  child: Icon(
                    widget.icon,
                    size: 20,
                    color: selected ? Baby.primary : color,
                  ),
                ),
        ),
      ),
    );
    if (widget.expanded) return item;
    return Tooltip(
      message: widget.shortcut == null
          ? tr(widget.label)
          : '${tr(widget.label)} (${widget.shortcut})',
      preferBelow: false,
      verticalOffset: 0,
      margin: const EdgeInsets.only(left: DesktopTokens.railWidth),
      child: item,
    );
  }
}

/// Looks like a search box; opens the global search.
class SearchTrigger extends StatefulWidget {
  const SearchTrigger({super.key, required this.onTap, this.width});
  final VoidCallback onTap;
  final double? width;

  @override
  State<SearchTrigger> createState() => _SearchTriggerState();
}

class _SearchTriggerState extends State<SearchTrigger> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: tr('Search'),
    child: InkWell(
      key: const ValueKey('search-trigger'),
      onTap: widget.onTap,
      onHover: (v) => setState(() => _hover = v),
      onFocusChange: (v) => setState(() => _focus = v),
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      highlightColor: Colors.transparent,
      borderRadius: BorderRadius.circular(DesktopTokens.radius),
      child: Container(
        width: widget.width,
        height: 36,
        padding: const EdgeInsets.only(left: 10, right: 6),
        decoration: BoxDecoration(
          color: _hover ? Baby.hover : Baby.card,
          borderRadius: BorderRadius.circular(DesktopTokens.radius),
          border: Border.all(
            color: _focus ? Baby.ring : Baby.border,
            width: _focus ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 18, color: Baby.muted),
            const SizedBox(width: 8),
            Expanded(
              child: LText(
                'Search…',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  color: Baby.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Kbd(Desktop.shortcut('K')),
          ],
        ),
      ),
    ),
  );
}

/// Slim bar at the top of each desktop page: title, subtitle and actions.
class DesktopTopBar extends StatelessWidget {
  const DesktopTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Container(
    height: DesktopTokens.topBarHeight + 8,
    padding: const EdgeInsets.symmetric(horizontal: 24),
    decoration: BoxDecoration(
      color: Baby.surface,
      border: Border(bottom: BorderSide(color: Baby.border)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LText(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: Baby.ink,
                ),
              ),
              if (subtitle != null)
                LText(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Baby.muted,
                  ),
                ),
            ],
          ),
        ),
        for (final a in actions) ...[const SizedBox(width: 8), a],
      ],
    ),
  );
}

/// Page labels for the sidebar, matching [ShellTabs].
List<NavDestination> get shellDestinations => [
  (label: 'Today', icon: Icons.home_outlined, selectedIcon: Icons.home_rounded),
  (
    label: 'History',
    icon: Icons.history_rounded,
    selectedIcon: Icons.history_rounded,
  ),
  (
    label: 'Pills',
    icon: Glyphs.pillOutlinedIcon,
    selectedIcon: Glyphs.pillIcon,
  ),
  (
    label: 'Routines',
    icon: Icons.event_repeat_rounded,
    selectedIcon: Icons.event_repeat_rounded,
  ),
  (
    label: 'Growth',
    icon: Icons.photo_album_outlined,
    selectedIcon: Icons.photo_album_rounded,
  ),
];
