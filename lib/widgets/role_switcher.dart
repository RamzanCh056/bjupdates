import 'package:beatjerky/providers/user_provider.dart';
import 'package:beatjerky/screens/edit_pro_profile_screen.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/color.dart';
import 'package:beatjerky/utils/role_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Shows current role and allows switching to any role.
class RoleSwitcherChip extends StatelessWidget {
  const RoleSwitcherChip({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserStatusProvider>();
    if (provider.roles.isEmpty) return const SizedBox.shrink();
    final effectiveRoles = provider.effectiveRoles;
    final effectiveLabel = effectiveRoles.isNotEmpty
        ? roleDisplayLabel(effectiveRoles.first)
        : 'Role';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showRolePicker(context, provider),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: recntsColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: recntsColor.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(roleIcon(effectiveRoles.isNotEmpty ? effectiveRoles.first : ''),
                  size: 16, color: recntsColor),
              const SizedBox(width: 6),
              Text(
                effectiveLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down, color: recntsColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showRolePicker(BuildContext context, UserStatusProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.75,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF1F1F1F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.only(top: 20, bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Choose your role',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _groupHeader('Individual'),
                    ...individualRoles
                        .map((r) => _roleTile(context, ctx, provider, r)),
                    _groupHeader('Organization'),
                    ...organizationRoles
                        .map((r) => _roleTile(context, ctx, provider, r)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _roleTile(BuildContext pageContext, BuildContext sheetContext,
      UserStatusProvider provider, String role) {
    final isActive = provider.effectiveRoles.isNotEmpty &&
        provider.effectiveRoles.first == role;
    return ListTile(
      dense: true,
      title: Text(
        roleDisplayLabel(role),
        style: TextStyle(
          color: Colors.white,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      leading: Icon(
        roleIcon(role),
        color: isActive ? recntsColor : Colors.white30,
      ),
      trailing: isActive
          ? Icon(Icons.check_circle, color: recntsColor, size: 20)
          : null,
      onTap: () async {
        if (isActive) {
          if (sheetContext.mounted) Navigator.pop(sheetContext);
          return;
        }

        if (provider.hasProProfileForRole(role)) {
          // Already set up for this role before — switch straight away.
          final ok = await provider.switchRoleAndPersist(role);
          if (sheetContext.mounted) Navigator.pop(sheetContext);
          if (!ok) {
            AppToast.show('Unable to switch role. Try again.', isError: true);
          }
          return;
        }

        // New role: build its professional profile first; the switch
        // itself completes only once that profile is saved.
        if (sheetContext.mounted) Navigator.pop(sheetContext);
        if (pageContext.mounted) {
          Navigator.push(
            pageContext,
            MaterialPageRoute(
              builder: (_) => EditProProfileScreen(initialRole: role),
            ),
          );
        }
      },
    );
  }
}

/// Icon for a role (UI only).
IconData roleIcon(String role) {
  switch (role) {
    case RoleKeys.listener:
      return Icons.headphones;
    case RoleKeys.artist:
      return Icons.music_note;
    case RoleKeys.dj:
      return Icons.album;
    case RoleKeys.band:
      return Icons.groups;
    case RoleKeys.technician:
      return Icons.build;
    case RoleKeys.organizer:
      return Icons.event;
    case RoleKeys.venue:
      return Icons.location_city;
    case RoleKeys.agency:
      return Icons.business_center;
    case RoleKeys.studio:
      return Icons.graphic_eq;
    case RoleKeys.label:
      return Icons.library_music;
    case RoleKeys.supplier:
      return Icons.local_shipping;
    default:
      return Icons.person;
  }
}
