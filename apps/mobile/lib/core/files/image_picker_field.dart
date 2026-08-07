import 'dart:async';

import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/ui/dimens.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

/// Picks one image and hands its local path to [onPicked], which uploads it and
/// returns an error message or null. Deliberately dumb: the owning cubit holds
/// `FileUploadRepository`, so this widget never reaches into DI.
///
/// ponytail: no cropping and no client-side resize. The picker's
/// `maxWidth`/`imageQuality` keep a phone photo well under the 5 MB limit
/// (§36); add a cropper when a business complains about framing.
class ImagePickerField extends StatefulWidget {
  const ImagePickerField({
    required this.imageUrl,
    required this.onPicked,
    this.onCleared,
    this.label,
    this.circular = false,
    this.size = 96,
    super.key,
  });

  /// Current image, or null when nothing is attached yet.
  final String? imageUrl;

  /// Uploads the picked file path; returns an error message, or null. Null for
  /// a member who may see the image but not change it — the button then renders
  /// disabled rather than offering a pick that goes nowhere.
  final Future<String?> Function(String path)? onPicked;

  /// Detaches the current image. Null hides the remove action.
  final VoidCallback? onCleared;

  final String? label;
  final bool circular;
  final double size;

  @override
  State<ImagePickerField> createState() => _ImagePickerFieldState();
}

class _ImagePickerFieldState extends State<ImagePickerField> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final radius = widget.circular ? widget.size / 2 : Dimens.radiusMd;

    return Row(
      children: [
        SizedBox(
          width: widget.size.r,
          height: widget.size.r,
          child: _busy
              ? const Center(child: CircularProgressIndicator())
              : _Preview(imageUrl: widget.imageUrl, radius: radius),
        ),
        const Gap.horizontal(Dimens.space16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.label case final label?)
                Text(label, style: context.textTheme.labelLarge),
              TextButton.icon(
                onPressed: _busy || widget.onPicked == null
                    ? null
                    : () => unawaited(_pick(context)),
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(
                  widget.imageUrl == null ? l10n.imagePick : l10n.imageReplace,
                ),
              ),
              if (widget.onCleared case final onCleared?
                  when widget.imageUrl != null)
                TextButton(
                  onPressed: _busy ? null : onCleared,
                  child: Text(l10n.imageRemove),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pick(BuildContext context) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.imageSourceGallery),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.imageSourceCamera),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    // 1600 px at 85% quality is a few hundred KB — comfortably inside the
    // 5 MB cap, and the backend rejects anything larger anyway.
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _busy = true);
    final error = await widget.onPicked!(picked.path);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
    }
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.radius, this.imageUrl});

  final double radius;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl case final url? when url.isNotEmpty) {
      return AppNetworkImage(url: url, borderRadius: radius);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius.r),
      ),
      child: Icon(
        Icons.image_outlined,
        color: context.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
