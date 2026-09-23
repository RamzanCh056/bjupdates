import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/musician_career_models.dart';
import '../../services/musician_career_service.dart';
import '../../utils/color.dart';

/// Self-serve musician registration. Also offers to "claim" a profile that the
/// BeatJerky team pre-registered for this email (admin-created, no linked user).
class MusicianRegisterScreen extends StatefulWidget {
  const MusicianRegisterScreen({super.key});

  @override
  State<MusicianRegisterScreen> createState() => _MusicianRegisterScreenState();
}

class _MusicianRegisterScreenState extends State<MusicianRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _location = TextEditingController();
  final _bio = TextEditingController();
  final _availability = TextEditingController();
  final _genreInput = TextEditingController();

  MusicianRole _primaryRole = MusicianRole.vocalist;
  final Set<MusicianRole> _secondaryRoles = <MusicianRole>{};
  ExperienceLevel? _experience;
  final List<String> _genres = <String>[];

  bool _saving = false;
  bool _checkingClaim = true;
  Musician? _claimable;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _email.text = user?.email ?? '';
    _fullName.text = user?.displayName ?? '';
    _checkClaimable();
  }

  Future<void> _checkClaimable() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _checkingClaim = false);
      return;
    }
    final match = await MusicianCareerService.findClaimableByEmail(email);
    if (!mounted) return;
    setState(() {
      _claimable = match;
      _checkingClaim = false;
    });
  }

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _location.dispose();
    _bio.dispose();
    _availability.dispose();
    _genreInput.dispose();
    super.dispose();
  }

  Future<void> _claim() async {
    final m = _claimable;
    if (m == null) return;
    setState(() => _saving = true);
    try {
      await MusicianCareerService.claimMusician(m.id);
      if (!mounted) return;
      _toast('Profile claimed. Welcome aboard!');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _toast('Could not claim the profile. Please try again.');
      setState(() => _saving = false);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final draft = Musician(
      id: '',
      userId: '',
      fullName: _fullName.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      location: _location.text.trim().isEmpty ? null : _location.text.trim(),
      primaryRole: _primaryRole,
      secondaryRoles: _secondaryRoles.toList(),
      experience: _experience,
      genres: _genres,
      bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
      availability: _availability.text.trim().isEmpty
          ? null
          : _availability.text.trim(),
    );
    try {
      await MusicianCareerService.registerMusician(draft);
      if (!mounted) return;
      _toast('You\'re registered as a musician.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _toast('Registration failed. Please try again.');
      setState(() => _saving = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: darkBackgroundTertiary),
    );
  }

  void _addGenre() {
    final g = _genreInput.text.trim();
    if (g.isEmpty) return;
    if (!_genres.contains(g)) setState(() => _genres.add(g));
    _genreInput.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBackgroundPrimary,
      appBar: AppBar(
        backgroundColor: darkAppBarBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Become a musician',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: _checkingClaim
          ? const Center(child: CircularProgressIndicator(color: purpleAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_claimable != null) _claimBanner(),
                    _label('Full name'),
                    _textField(
                      _fullName,
                      hint: 'Your stage or legal name',
                      validator: _required,
                    ),
                    _label('Email'),
                    _textField(
                      _email,
                      hint: 'you@example.com',
                      keyboardType: TextInputType.emailAddress,
                      validator: _required,
                    ),
                    _label('Phone (optional)'),
                    _textField(
                      _phone,
                      hint: '+1 555 123 4567',
                      keyboardType: TextInputType.phone,
                    ),
                    _label('Location (optional)'),
                    _textField(_location, hint: 'City, Country'),
                    _label('Primary role'),
                    _roleDropdown(),
                    _label('Also plays (optional)'),
                    _secondaryRoleChips(),
                    _label('Experience (optional)'),
                    _experienceDropdown(),
                    _label('Genres (optional)'),
                    _genreEditor(),
                    _label('Short bio (optional)'),
                    _textField(
                      _bio,
                      hint: 'Tell us about yourself',
                      maxLines: 4,
                    ),
                    _label('Availability (optional)'),
                    _textField(
                      _availability,
                      hint: 'e.g. Weekends, touring in spring',
                    ),
                    const SizedBox(height: 24),
                    _primaryButton(
                      label: _saving ? 'Saving…' : 'Register',
                      onTap: _saving ? null : _submit,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _claimBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: appGradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'We found your profile',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'The BeatJerky team pre-registered "${_claimable!.fullName}" for this email. Claim it to keep the details already on file.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _claim,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: indigoColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                _saving ? 'Claiming…' : 'Claim this profile',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '…or fill in the form below to start fresh.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // --- field builders -------------------------------------------------------

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 14, 0, 6),
    child: Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.8),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _textField(
    TextEditingController c, {
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: c,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(hint),
    );
  }

  InputDecoration _inputDecoration(String? hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.06),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: purpleAccent),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: redColor),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: redColor),
    ),
  );

  Widget _roleDropdown() {
    return _dropdownShell(
      child: DropdownButton<MusicianRole>(
        value: _primaryRole,
        isExpanded: true,
        dropdownColor: darkBackgroundTertiary,
        underline: const SizedBox.shrink(),
        iconEnabledColor: Colors.white,
        style: const TextStyle(color: Colors.white),
        items: MusicianRole.values
            .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
            .toList(),
        onChanged: (v) => setState(() => _primaryRole = v ?? _primaryRole),
      ),
    );
  }

  Widget _experienceDropdown() {
    return _dropdownShell(
      child: DropdownButton<ExperienceLevel?>(
        value: _experience,
        isExpanded: true,
        hint: Text(
          'Select',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
        ),
        dropdownColor: darkBackgroundTertiary,
        underline: const SizedBox.shrink(),
        iconEnabledColor: Colors.white,
        style: const TextStyle(color: Colors.white),
        items: ExperienceLevel.values
            .map(
              (e) => DropdownMenuItem<ExperienceLevel?>(
                value: e,
                child: Text(e.label),
              ),
            )
            .toList(),
        onChanged: (v) => setState(() => _experience = v),
      ),
    );
  }

  Widget _dropdownShell({required Widget child}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
    ),
    child: child,
  );

  Widget _secondaryRoleChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: MusicianRole.values.where((r) => r != _primaryRole).map((r) {
        final selected = _secondaryRoles.contains(r);
        return _toggleChip(
          label: r.label,
          selected: selected,
          onTap: () => setState(() {
            if (selected) {
              _secondaryRoles.remove(r);
            } else {
              _secondaryRoles.add(r);
            }
          }),
        );
      }).toList(),
    );
  }

  /// A theme-proof toggle chip: transparent-ish when unselected, indigo when
  /// selected. Built from primitives so no Material 3 chip surface leaks through.
  Widget _toggleChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? indigoColor
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(Icons.check, size: 16, color: Colors.white),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _genreEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _genreInput,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Add a genre'),
                onSubmitted: (_) => _addGenre(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _addGenre,
              icon: const Icon(Icons.add_circle, color: purpleAccent, size: 32),
            ),
          ],
        ),
        if (_genres.isNotEmpty) const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _genres.map((g) => _genreChip(g)).toList(),
        ),
      ],
    );
  }

  Widget _genreChip(String g) {
    return Container(
      padding: const EdgeInsets.only(left: 14, right: 6, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            g,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: () => setState(() => _genres.remove(g)),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                Icons.close,
                size: 16,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton({required String label, VoidCallback? onTap}) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onTap == null ? null : buttonGradient,
          color: onTap == null ? Colors.white.withValues(alpha: 0.1) : null,
          borderRadius: BorderRadius.circular(14),
        ),
        child: TextButton(
          onPressed: onTap,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}
