import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide FormField;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/musician_career_models.dart';
import '../../services/musician_career_service.dart';
import '../../utils/color.dart';
import '../../widgets/musician/signature_pad.dart';

/// Renders a form template dynamically for a musician assignment.
/// Supports every [FieldType], conditional visibility, required-field
/// validation, debounced autosave, file/image/document/signature uploads,
/// and submit. Read-only when the assignment is locked or already submitted.
class MusicianFormScreen extends StatefulWidget {
  final FormAssignment assignment;

  const MusicianFormScreen({super.key, required this.assignment});

  @override
  State<MusicianFormScreen> createState() => _MusicianFormScreenState();
}

class _MusicianFormScreenState extends State<MusicianFormScreen> {
  FormTemplate? _template;
  bool _loading = true;
  bool _saving = false;
  bool _submitting = false;
  String? _loadError;

  final Map<String, dynamic> _answers = <String, dynamic>{};
  final Map<String, String> _files = <String, String>{};
  final Map<String, SignaturePadController> _sigControllers = {};
  final Map<String, bool> _uploading = <String, bool>{};

  Timer? _autosaveTimer;
  FormStatus _status = FormStatus.notStarted;

  bool get _editable {
    // Locked assignments and terminal states can't be edited.
    if (widget.assignment.locked) return false;
    return _status.isEditable;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final template = await MusicianCareerService.getTemplate(
        widget.assignment.templateId,
      );
      final submission = await MusicianCareerService.getSubmission(
        widget.assignment.id,
      );
      if (submission != null) {
        _answers.addAll(submission.answers);
        _files.addAll(submission.files);
        _status = submission.status;
      } else {
        _status = widget.assignment.status;
      }
      if (!mounted) return;
      setState(() {
        _template = template;
        _loading = false;
        if (template == null) _loadError = 'This form is no longer available.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Could not load the form. Please try again.';
      });
    }
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    for (final c in _sigControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // --- visibility & validation ---------------------------------------------

  bool _isVisible(FormField field) {
    final cond = field.conditionalOn;
    if (cond == null) return true;
    final current = _answers[cond.fieldId];
    return current == cond.equals ||
        current?.toString() == cond.equals?.toString();
  }

  List<FormField> get _visibleFields =>
      (_template?.fields ?? const []).where(_isVisible).toList();

  bool _hasValue(FormField f) {
    if (f.type.isUpload || f.type == FieldType.signature) {
      return (_files[f.id] ?? '').isNotEmpty;
    }
    final v = _answers[f.id];
    if (v == null) return false;
    if (v is String) return v.trim().isNotEmpty;
    if (v is List) return v.isNotEmpty;
    if (v is bool) return v; // required checkbox must be checked
    return true;
  }

  String? _firstValidationError() {
    for (final f in _visibleFields) {
      if (f.required && !_hasValue(f)) {
        return 'Please complete "${f.label}".';
      }
      if (f.type == FieldType.number) {
        final raw = _answers[f.id];
        if (raw != null && raw.toString().isNotEmpty) {
          final n = num.tryParse(raw.toString());
          if (n == null) return '"${f.label}" must be a number.';
          if (f.min != null && n < f.min!) {
            return '"${f.label}" must be at least ${f.min}.';
          }
          if (f.max != null && n > f.max!) {
            return '"${f.label}" must be at most ${f.max}.';
          }
        }
      }
    }
    return null;
  }

  // --- persistence ----------------------------------------------------------

  void _onChanged() {
    if (!_editable) return;
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 1500), _autosave);
  }

  Future<void> _autosave() async {
    if (!_editable || _submitting) return;
    setState(() => _saving = true);
    try {
      await MusicianCareerService.saveDraft(
        assignment: widget.assignment,
        answers: _answers,
        files: _files,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submit() async {
    // Capture any drawn-but-unsaved signatures first.
    await _captureSignatures();

    final err = _firstValidationError();
    if (err != null) {
      _toast(err);
      return;
    }
    setState(() => _submitting = true);
    try {
      await MusicianCareerService.submit(
        assignment: widget.assignment,
        answers: _answers,
        files: _files,
      );
      if (!mounted) return;
      _toast('Submitted for review. Thank you!');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _toast('Submit failed. Please try again.');
      setState(() => _submitting = false);
    }
  }

  Future<void> _captureSignatures() async {
    for (final entry in _sigControllers.entries) {
      final controller = entry.value;
      if (controller.isEmpty) continue;
      // Re-export if the pad changed since last upload (simple: always export).
      final bytes = await controller.exportPng();
      if (bytes == null) continue;
      try {
        final url = await MusicianCareerService.uploadFieldBytes(
          assignmentId: widget.assignment.id,
          fieldId: entry.key,
          bytes: bytes,
        );
        _files[entry.key] = url;
      } catch (_) {
        // Leave existing file url (if any) untouched on failure.
      }
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: darkBackgroundTertiary),
    );
  }

  // --- uploads --------------------------------------------------------------

  Future<void> _pickImage(FormField f) async {
    final XFile? x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x == null) return;
    await _uploadFile(f, File(x.path), x.name);
  }

  Future<void> _pickFile(FormField f) async {
    final result = await FilePicker.platform.pickFiles();
    final path = result?.files.single.path;
    if (path == null) return;
    await _uploadFile(f, File(path), result!.files.single.name);
  }

  Future<void> _uploadFile(FormField f, File file, String name) async {
    setState(() => _uploading[f.id] = true);
    try {
      final url = await MusicianCareerService.uploadFieldFile(
        assignmentId: widget.assignment.id,
        fieldId: f.id,
        file: file,
        fileName: name,
      );
      setState(() {
        _files[f.id] = url;
        _answers['${f.id}__name'] = name;
      });
      _onChanged();
    } catch (e) {
      _toast('Upload failed for "${f.label}".');
    } finally {
      if (mounted) setState(() => _uploading[f.id] = false);
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // --- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBackgroundPrimary,
      appBar: AppBar(
        backgroundColor: darkAppBarBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _template?.title ?? 'Form',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: purpleAccent))
          : _loadError != null
          ? _errorState()
          : _formBody(),
      bottomNavigationBar: (_loading || _loadError != null || !_editable)
          ? null
          : _submitBar(),
    );
  }

  Widget _errorState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        _loadError!,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
      ),
    ),
  );

  Widget _formBody() {
    final t = _template!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_editable) _statusBanner(),
          if ((t.description ?? '').isNotEmpty) ...[
            Text(
              t.description!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
          ],
          for (final field in _visibleFields) _fieldBlock(field),
        ],
      ),
    );
  }

  Widget _statusBanner() {
    final msg = widget.assignment.locked
        ? 'This form is locked and can no longer be edited.'
        : 'This form is ${_status.label.toLowerCase()} — view only.';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldBlock(FormField field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 16, 0, 6),
          child: RichText(
            text: TextSpan(
              text: field.label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              children: [
                if (field.required)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: redColor),
                  ),
              ],
            ),
          ),
        ),
        if ((field.help ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 2),
            child: Text(
              field.help!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ),
        _fieldInput(field),
      ],
    );
  }

  Widget _fieldInput(FormField f) {
    switch (f.type) {
      case FieldType.text:
        return _text(f);
      case FieldType.longtext:
        return _text(f, maxLines: 4);
      case FieldType.medialink:
        return _text(f, keyboardType: TextInputType.url);
      case FieldType.number:
        return _text(f, keyboardType: TextInputType.number);
      case FieldType.date:
        return _date(f);
      case FieldType.dropdown:
        return _dropdown(f);
      case FieldType.multiselect:
        return _multiselect(f);
      case FieldType.radio:
        return _radio(f);
      case FieldType.checkbox:
        return _checkbox(f);
      case FieldType.file:
      case FieldType.document:
        return _fileField(f, isImage: false);
      case FieldType.image:
        return _fileField(f, isImage: true);
      case FieldType.signature:
        return _signature(f);
    }
  }

  Widget _text(FormField f, {int maxLines = 1, TextInputType? keyboardType}) {
    final initial = _answers[f.id]?.toString() ?? '';
    return TextFormField(
      initialValue: initial,
      enabled: _editable,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: _decoration(
        f.type == FieldType.medialink
            ? 'https://…'
            : (f.type == FieldType.number ? 'Enter a number' : 'Your answer'),
      ),
      onChanged: (v) {
        _answers[f.id] = v;
        _onChanged();
      },
    );
  }

  Widget _date(FormField f) {
    final ms = _answers[f.id];
    DateTime? current;
    if (ms is int) current = DateTime.fromMillisecondsSinceEpoch(ms);
    if (ms is String) current = DateTime.tryParse(ms);
    final text = current == null
        ? 'Select a date'
        : '${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}';
    return InkWell(
      onTap: !_editable
          ? null
          : () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: current ?? DateTime.now(),
                firstDate: DateTime(1950),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setState(() => _answers[f.id] = picked.millisecondsSinceEpoch);
                _onChanged();
              }
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: _boxDecoration(),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Colors.white54, size: 18),
            const SizedBox(width: 10),
            Text(
              text,
              style: TextStyle(
                color: current == null
                    ? Colors.white.withValues(alpha: 0.35)
                    : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdown(FormField f) {
    final value = _answers[f.id]?.toString();
    final valid = f.options.any((o) => o.value == value) ? value : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: _boxDecoration(),
      child: DropdownButton<String>(
        value: valid,
        isExpanded: true,
        dropdownColor: darkBackgroundTertiary,
        underline: const SizedBox.shrink(),
        iconEnabledColor: Colors.white,
        hint: Text(
          'Select',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
        ),
        style: const TextStyle(color: Colors.white),
        items: f.options
            .map((o) => DropdownMenuItem(value: o.value, child: Text(o.label)))
            .toList(),
        onChanged: !_editable
            ? null
            : (v) {
                setState(() => _answers[f.id] = v);
                _onChanged();
              },
      ),
    );
  }

  Widget _multiselect(FormField f) {
    final selected =
        (_answers[f.id] as List?)?.map((e) => e.toString()).toSet() ??
        <String>{};
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: f.options.map((o) {
        final isSel = selected.contains(o.value);
        return _toggleChip(
          label: o.label,
          selected: isSel,
          onTap: !_editable
              ? null
              : () {
                  setState(() {
                    if (isSel) {
                      selected.remove(o.value);
                    } else {
                      selected.add(o.value);
                    }
                    _answers[f.id] = selected.toList();
                  });
                  _onChanged();
                },
        );
      }).toList(),
    );
  }

  /// A theme-proof toggle chip: transparent-ish when unselected, indigo when
  /// selected. Built from primitives so no Material 3 chip surface leaks through.
  /// [onTap] null renders a disabled (read-only) chip.
  Widget _toggleChip({
    required String label,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? indigoColor : Colors.white.withValues(alpha: 0.06),
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

  Widget _radio(FormField f) {
    final value = _answers[f.id]?.toString();
    return Column(
      children: f.options.map((o) {
        return RadioListTile<String>(
          value: o.value,
          groupValue: value,
          onChanged: !_editable
              ? null
              : (v) {
                  setState(() => _answers[f.id] = v);
                  _onChanged();
                },
          title: Text(o.label, style: const TextStyle(color: Colors.white)),
          activeColor: purpleAccent,
          contentPadding: EdgeInsets.zero,
          dense: true,
        );
      }).toList(),
    );
  }

  Widget _checkbox(FormField f) {
    final checked = _answers[f.id] == true;
    return CheckboxListTile(
      value: checked,
      onChanged: !_editable
          ? null
          : (v) {
              setState(() => _answers[f.id] = v ?? false);
              _onChanged();
            },
      title: Text(f.label, style: const TextStyle(color: Colors.white)),
      activeColor: purpleAccent,
      checkColor: Colors.white,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
    );
  }

  Widget _fileField(FormField f, {required bool isImage}) {
    final url = _files[f.id];
    final name = _answers['${f.id}__name']?.toString();
    final busy = _uploading[f.id] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (url != null && url.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: _boxDecoration(),
            child: Row(
              children: [
                Icon(
                  isImage ? Icons.image : Icons.insert_drive_file,
                  color: purpleAccent,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name ?? 'Uploaded',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                TextButton(
                  onPressed: () => _openUrl(url),
                  child: const Text(
                    'View',
                    style: TextStyle(color: purpleAccent),
                  ),
                ),
              ],
            ),
          ),
        if (_editable)
          OutlinedButton.icon(
            onPressed: busy
                ? null
                : () => isImage ? _pickImage(f) : _pickFile(f),
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  )
                : Icon(
                    isImage ? Icons.upload : Icons.attach_file,
                    color: Colors.white,
                  ),
            label: Text(
              busy
                  ? 'Uploading…'
                  : (url == null
                        ? (isImage ? 'Upload image' : 'Attach file')
                        : 'Replace'),
              style: const TextStyle(color: Colors.white),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
      ],
    );
  }

  Widget _signature(FormField f) {
    final controller = _sigControllers.putIfAbsent(
      f.id,
      () => SignaturePadController(),
    );
    final existing = _files[f.id];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (existing != null && existing.isNotEmpty && controller.isEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(8),
            decoration: _boxDecoration(),
            child: Image.network(existing, height: 120, fit: BoxFit.contain),
          ),
        Container(
          decoration: _boxDecoration(),
          clipBehavior: Clip.antiAlias,
          child: AbsorbPointer(
            absorbing: !_editable,
            child: SignaturePad(controller: controller),
          ),
        ),
        if (_editable)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => setState(() => controller.clear()),
              icon: const Icon(Icons.refresh, color: Colors.white54, size: 16),
              label: const Text(
                'Clear',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          ),
      ],
    );
  }

  // --- shared decorations ---------------------------------------------------

  BoxDecoration _boxDecoration() => BoxDecoration(
    color: Colors.white.withValues(alpha: 0.06),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
  );

  InputDecoration _decoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.06),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: purpleAccent),
    ),
  );

  Widget _submitBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: _submitting ? null : buttonGradient,
              color: _submitting ? Colors.white.withValues(alpha: 0.1) : null,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextButton(
              onPressed: _submitting ? null : _submit,
              child: Text(
                _submitting ? 'Submitting…' : 'Submit for review',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
