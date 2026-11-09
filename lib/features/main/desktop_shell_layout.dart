import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Below this window width the desktop sidebar is a 72-px icon rail and the
/// full sidebar opens as an overlay (F65): 260 px sidebar + 1 px divider +
/// ~540 px readable content ≈ 800.
const double kCompactSidebarBelow = 800.0;

bool useCompactSidebar(double windowWidth,
        {double compactBelow = kCompactSidebarBelow}) =>
    windowWidth < compactBelow;

/// Builds the sidebar. [collapsed]: icon rail look. [onToggle]: the ☰ action.
/// [onItemSelected]: call after an item navigates (closes the overlay).
typedef DesktopSidebarBuilder = Widget Function(
    bool collapsed, VoidCallback onToggle, VoidCallback onItemSelected);

/// Desktop sidebar + content layout (F65).
///
/// Wide (≥ [compactBelow]): today's inline sidebar, 260 px or 72 px via
/// [userCollapsed] / [onToggleCollapsed]. Compact: inline 72-px rail; ☰ opens
/// the full sidebar over the content from the start edge (left in LTR, right
/// in RTL) with a scrim. The content never moves for the overlay; its
/// position in the tree is the same in both layouts. The open state is in
/// memory only.
class DesktopShellLayout extends StatefulWidget {
  final bool sidebarVisible;
  final bool userCollapsed;
  final VoidCallback onToggleCollapsed;
  final DesktopSidebarBuilder sidebarBuilder;
  final Widget content;
  final Color dividerColor;
  final double compactBelow;

  const DesktopShellLayout({
    super.key,
    required this.sidebarVisible,
    required this.userCollapsed,
    required this.onToggleCollapsed,
    required this.sidebarBuilder,
    required this.content,
    required this.dividerColor,
    this.compactBelow = kCompactSidebarBelow,
  });

  @override
  State<DesktopShellLayout> createState() => _DesktopShellLayoutState();
}

class _DesktopShellLayoutState extends State<DesktopShellLayout> {
  static const double _fullWidth = 260.0;
  static const double _railWidth = 72.0;

  bool _overlayOpen = false;

  void _open() => setState(() => _overlayOpen = true);
  void _close() {
    if (_overlayOpen) setState(() => _overlayOpen = false);
  }

  void _noop() {}

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final compact = useCompactSidebar(constraints.maxWidth,
          compactBelow: widget.compactBelow);
      // Leaving the compact layout closes the overlay (not reopened later).
      if (!compact || !widget.sidebarVisible) _overlayOpen = false;

      final Widget? sidebarSlot;
      if (!widget.sidebarVisible) {
        sidebarSlot = null;
      } else if (compact) {
        sidebarSlot = SizedBox(
          width: _railWidth,
          child: widget.sidebarBuilder(true, _open, _noop),
        );
      } else {
        sidebarSlot = AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          width: widget.userCollapsed ? _railWidth : _fullWidth,
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(),
          child: LayoutBuilder(
            builder: (context, c) => widget.sidebarBuilder(
                c.maxWidth < 166, widget.onToggleCollapsed, _noop),
          ),
        );
      }

      final row = Row(children: [
        if (sidebarSlot != null) ...[
          sidebarSlot,
          Container(width: 1, color: widget.dividerColor),
        ],
        Expanded(child: widget.content),
      ]);

      return Stack(children: [
        Positioned.fill(child: row),
        if (_overlayOpen) ...[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
              child: const ColoredBox(color: Colors.black54),
            ),
          ),
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            width: _fullWidth,
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape): _close,
              },
              child: Focus(
                autofocus: true,
                child: Material(
                  elevation: 8,
                  child: widget.sidebarBuilder(false, _close, _close),
                ),
              ),
            ),
          ),
        ],
      ]);
    });
  }
}
