import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'common.dart';
import 'theme.dart';

/// Decode and resize on import. Persist pixels, without the source's EXIF data.
Future<String?> pickBabyPhoto(BuildContext context) async {
  try {
    final file = await FilePicker.pickFile(
      dialogTitle: tr('Choose a photo'),
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (file == null) return null;
    if ((await file.length() ?? 0) > 20 * 1024 * 1024) {
      throw const FormatException('Choose a photo smaller than 20 MB.');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(
      await file.readAsBytes(),
    );
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      final scale = descriptor.width > descriptor.height
          ? descriptor.width / 720
          : descriptor.height / 720;
      final codec = await descriptor.instantiateCodec(
        targetWidth: scale > 1
            ? (descriptor.width / scale).round()
            : descriptor.width,
        targetHeight: scale > 1
            ? (descriptor.height / scale).round()
            : descriptor.height,
      );
      try {
        final frame = await codec.getNextFrame();
        try {
          final data = await frame.image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (data == null) {
            throw const FormatException('Could not read that photo.');
          }
          return base64Encode(data.buffer.asUint8List());
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } finally {
      descriptor.dispose();
      buffer.dispose();
    }
  } catch (_) {
    if (context.mounted) {
      showMessage(context, 'Choose a JPG, PNG or WebP photo under 20 MB.');
    }
    return null;
  }
}

class BabyPhoto extends StatefulWidget {
  const BabyPhoto({super.key, this.photo, this.size = 72, this.square = false});
  final String? photo;
  final double size;
  final bool square;
  @override
  State<BabyPhoto> createState() => _BabyPhotoState();
}

class _BabyPhotoState extends State<BabyPhoto> {
  Uint8List? bytes;
  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(BabyPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.photo != oldWidget.photo) _decode();
  }

  void _decode() {
    try {
      bytes = widget.photo == null ? null : base64Decode(widget.photo!);
    } catch (_) {
      bytes = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: Baby.primarySoft,
      child: Center(
        child: Icon(
          Icons.child_care_rounded,
          size: widget.size.clamp(24, 100) * .5,
          color: Baby.primary,
        ),
      ),
    );
    return Semantics(
      label: tr('Baby photo'),
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.square ? 22 : widget.size),
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: bytes == null
              ? placeholder
              : Image.memory(
                  bytes!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => placeholder,
                ),
        ),
      ),
    );
  }
}
