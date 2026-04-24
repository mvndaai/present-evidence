import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mime/mime.dart';
import '../../../core/models/evidence.dart';
import '../providers/evidence_provider.dart';
import '../../auth/providers/auth_provider.dart';

class EvidenceUploadScreen extends ConsumerStatefulWidget {
  const EvidenceUploadScreen({super.key, required this.caseId});

  final String caseId;

  @override
  ConsumerState<EvidenceUploadScreen> createState() =>
      _EvidenceUploadScreenState();
}

class _EvidenceUploadScreenState extends ConsumerState<EvidenceUploadScreen> {
  final _nameController = TextEditingController();
  File? _selectedFile;
  String? _mimeType;
  EvidenceType? _detectedType;
  bool _isShared = false;
  bool _isUploading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'mp4',
        'mov',
        'avi',
        'jpg',
        'jpeg',
        'png',
        'webp',
      ],
    );

    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    final name = result.files.single.name;
    final mime = lookupMimeType(name) ?? 'application/octet-stream';
    final type = _detectType(mime, name);

    setState(() {
      _selectedFile = file;
      _mimeType = mime;
      _detectedType = type;
      if (_nameController.text.isEmpty) {
        _nameController.text =
            name.replaceAll(RegExp(r'\.[^.]+$'), '');
      }
    });
  }

  EvidenceType _detectType(String mime, String fileName) {
    if (mime.contains('pdf')) return EvidenceType.pdf;
    if (mime.startsWith('video/')) return EvidenceType.video;
    return EvidenceType.image;
  }

  Future<void> _upload() async {
    if (_selectedFile == null || _detectedType == null) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter a name');
      return;
    }

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    final user = await ref.read(currentUserProvider.future);
    if (user == null) return;

    final ev = await ref.read(evidenceNotifierProvider.notifier).upload(
          caseId: widget.caseId,
          uploadedBy: user.id,
          file: _selectedFile!,
          name: name,
          type: _detectedType!,
          mimeType: _mimeType!,
          isShared: _isShared,
        );

    if (!mounted) return;
    setState(() => _isUploading = false);

    if (ev != null) {
      ref.invalidate(evidenceProvider(widget.caseId));
      context.go('/cases/${widget.caseId}');
    } else {
      setState(() => _errorMessage = 'Upload failed. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Evidence')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _FilePickerCard(
            file: _selectedFile,
            mimeType: _mimeType,
            onPickFile: _pickFile,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Evidence Name',
              hintText: 'e.g. Police Report 2024-01-15',
              prefixIcon: Icon(Icons.label_outline),
            ),
          ),
          const SizedBox(height: 16),
          if (_detectedType != null)
            Chip(
              label: Text('Type: ${_detectedType!.name.toUpperCase()}'),
              avatar: Icon(_iconForType(_detectedType!)),
            ),
          const SizedBox(height: 16),
          SwitchListTile(
            value: _isShared,
            onChanged: (v) => setState(() => _isShared = v),
            title: const Text('Share with Team'),
            subtitle: const Text(
                'All team members can see this evidence'),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style:
                  TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed:
                (_isUploading || _selectedFile == null) ? null : _upload,
            icon: _isUploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload),
            label:
                Text(_isUploading ? 'Uploading…' : 'Upload Evidence'),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(EvidenceType type) {
    switch (type) {
      case EvidenceType.pdf:
        return Icons.picture_as_pdf_outlined;
      case EvidenceType.video:
        return Icons.videocam_outlined;
      case EvidenceType.image:
        return Icons.image_outlined;
    }
  }
}

class _FilePickerCard extends StatelessWidget {
  const _FilePickerCard({
    required this.file,
    required this.mimeType,
    required this.onPickFile,
  });

  final File? file;
  final String? mimeType;
  final VoidCallback onPickFile;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPickFile,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
            width: 2,
            style: file == null ? BorderStyle.solid : BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(12),
          color: file != null
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
        ),
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              file == null
                  ? Icons.upload_file_outlined
                  : Icons.check_circle_outline,
              size: 48,
              color: file != null
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              file == null
                  ? 'Tap to select a file'
                  : file!.path.split('/').last,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (mimeType != null) ...[
              const SizedBox(height: 4),
              Text(
                mimeType!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
