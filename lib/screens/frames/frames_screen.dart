import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/cosmos_colors.dart';
import '../../models/media_model.dart';
import '../../providers/core_providers.dart';
import '../../widgets/animated_star.dart';
import '../../widgets/cosmic_button.dart';
import '../../widgets/cosmic_scaffold.dart';
import '../../widgets/media_actions.dart';
import '../../widgets/media_image.dart';
import '../../widgets/media_picker_sheet.dart';

enum FrameStyle { star, moon, rainbow, planet, galaxy, classic }

const _frameNames = {
  FrameStyle.star: 'Star',
  FrameStyle.moon: 'Moon',
  FrameStyle.rainbow: 'Rainbow',
  FrameStyle.planet: 'Planet',
  FrameStyle.galaxy: 'Galaxy',
  FrameStyle.classic: 'Classic',
};

/// Decorate a photo and save a COPY. The original is never modified.
class FramesScreen extends ConsumerStatefulWidget {
  const FramesScreen({super.key, this.initialMediaId});
  final String? initialMediaId;
  @override
  ConsumerState<FramesScreen> createState() => _FramesScreenState();
}

class _FramesScreenState extends ConsumerState<FramesScreen> {
  MediaModel? _media;
  FrameStyle _style = FrameStyle.star;
  Color _color = CosmosColors.starYellow;
  final _key = GlobalKey();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialMediaId != null) {
      ref.read(mediaRepositoryProvider).byId(widget.initialMediaId!).then((m) {
        if (mounted && m != null && !m.isVideo) setState(() => _media = m);
      });
    }
  }

  Future<void> _choose() async {
    final ids = await showMediaPickerSheet(context,
        single: true, photosOnly: true, title: 'Choose a photo');
    if (ids == null || ids.isEmpty) return;
    final m = await ref.read(mediaRepositoryProvider).byId(ids.first);
    if (mounted && m != null) setState(() => _media = m);
  }

  Future<Uint8List?> _render() async {
    final boundary =
        _key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  Future<void> _saveCopy() async {
    final src = _media;
    if (src == null) return;
    setState(() => _busy = true);
    try {
      final bytes = await _render();
      if (bytes == null) throw StateError('render');
      final id = const Uuid().v4();
      final stored =
          await ref.read(mediaFileStoreProvider).saveBytes(id, bytes, '.png');
      final now = DateTime.now();
      final base =
          (src.fileName ?? 'photo').replaceAll(RegExp(r'\.[^.]+$'), '');
      await ref.read(mediaRepositoryProvider).insert(MediaModel(
            id: id,
            localUri: stored.ref,
            mediaType: MediaType.image,
            fileName: '${base}_cosmic_frame.png',
            mimeType: 'image/png',
            capturedAt: src.capturedAt,
            fileSize: stored.size,
            importedAt: now,
            createdAt: now,
            updatedAt: now,
          ));
      refreshUniverse(ref);
      if (mounted)
        toast(context, 'Saved a decorated copy. Your original is untouched ✨');
    } catch (_) {
      if (mounted)
        toast(context, 'Could not save the decorated copy. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final bytes = await _render();
      if (bytes == null) throw StateError('render');
      await Share.shareXFiles([
        XFile.fromData(bytes, name: 'cosmos_frame.png', mimeType: 'image/png')
      ]);
    } catch (_) {
      if (mounted) toast(context, 'Sharing is not available here.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return CosmicScaffold(
      title: 'Cosmic Frames',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_media == null)
                Column(
                  children: [
                    const SizedBox(height: 32),
                    const AnimatedStar(size: 64),
                    const SizedBox(height: 12),
                    Text('Pick a photo to decorate', style: text.titleLarge),
                    const SizedBox(height: 16),
                    CosmicButton(
                        label: 'Choose a photo',
                        icon: Icons.photo,
                        onPressed: _choose),
                  ],
                )
              else ...[
                Center(
                  child: RepaintBoundary(
                    key: _key,
                    child: SizedBox(
                        width: 340,
                        height: 400,
                        child: _FramedPhoto(
                            media: _media!, style: _style, color: _color)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Frame', style: text.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in FrameStyle.values)
                      ChoiceChip(
                          label: Text(_frameNames[s]!),
                          selected: s == _style,
                          onSelected: (_) => setState(() => _style = s)),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Frame color', style: text.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final c in [
                      CosmosColors.starYellow,
                      ...CosmosColors.planetChoices
                          .where((c) => c != CosmosColors.starYellow),
                      CosmosColors.cloudWhite
                    ])
                      InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => setState(() => _color = c),
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: c == _color
                                      ? CosmosColors.cloudWhite
                                      : Colors.transparent,
                                  width: 3)),
                          child: c == _color
                              ? const Icon(Icons.check,
                                  color: CosmosColors.deepSpaceNavy)
                              : null,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    CosmicButton(
                        label: 'Change photo',
                        icon: Icons.photo,
                        color: CosmosColors.midnightPurple,
                        onPressed: _busy ? null : _choose),
                    CosmicButton(
                        label: _busy ? 'Working…' : 'Save a copy',
                        icon: Icons.save_alt,
                        onPressed: _busy ? null : _saveCopy),
                    CosmicButton(
                        label: 'Export',
                        icon: Icons.ios_share,
                        color: CosmosColors.nebulaPink,
                        foreground: CosmosColors.deepSpaceNavy,
                        onPressed: _busy ? null : _export),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FramedPhoto extends StatelessWidget {
  const _FramedPhoto(
      {required this.media, required this.style, required this.color});
  final MediaModel media;
  final FrameStyle style;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final bg = style == FrameStyle.galaxy
        ? const [CosmosColors.deepSpaceNavy, Color(0xFF4A2A7A)]
        : style == FrameStyle.classic
            ? [color, color]
            : [CosmosColors.midnightPurple, CosmosColors.deepSpaceNavy];
    return DecoratedBox(
      decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight, colors: bg),
          borderRadius: BorderRadius.circular(8)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: const EdgeInsets.all(40),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: MediaImage(media, full: true)),
          ),
          Positioned.fill(
              child: CustomPaint(painter: _FramePainter(style, color))),
        ],
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  const _FramePainter(this.style, this.color);
  final FrameStyle style;
  final Color color;

  static const _inset = 40.0;

  @override
  void paint(Canvas canvas, Size size) {
    final photo = Rect.fromLTWH(
        _inset, _inset, size.width - _inset * 2, size.height - _inset * 2);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = color;
    switch (style) {
      case FrameStyle.classic:
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                photo.inflate(2), const Radius.circular(14)),
            stroke..color = CosmosColors.cloudWhite);
      case FrameStyle.rainbow:
        const cols = [
          CosmosColors.coral,
          CosmosColors.starYellow,
          CosmosColors.mint,
          CosmosColors.skyBlue,
          CosmosColors.nebulaPurple
        ];
        for (var i = 0; i < cols.length; i++) {
          canvas.drawRRect(
              RRect.fromRectAndRadius(
                  photo.inflate(3.0 + (cols.length - i) * 5),
                  Radius.circular(14 + (cols.length - i) * 3.0)),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 5
                ..color = cols[i]);
        }
      case FrameStyle.star:
        _perimeter(canvas, size, 22,
            (c, i) => _star(canvas, c, i.isEven ? 11 : 7, color));
      case FrameStyle.moon:
        for (final c in [
          const Offset(20, 20),
          Offset(size.width - 20, 20),
          Offset(20, size.height - 20),
          Offset(size.width - 20, size.height - 20)
        ]) {
          canvas
            ..drawCircle(c, 14, Paint()..color = color)
            ..drawCircle(c + const Offset(6, -3), 12,
                Paint()..color = CosmosColors.deepSpaceNavy);
        }
        _perimeter(
            canvas,
            size,
            14,
            (c, i) => canvas.drawCircle(
                c, 2.2, Paint()..color = color.withValues(alpha: .8)));
      case FrameStyle.planet:
        final cs = [
          CosmosColors.nebulaPink,
          CosmosColors.skyBlue,
          CosmosColors.mint,
          CosmosColors.coral
        ];
        final corners = [
          const Offset(22, 22),
          Offset(size.width - 22, 22),
          Offset(22, size.height - 22),
          Offset(size.width - 22, size.height - 22)
        ];
        for (var i = 0; i < 4; i++) {
          canvas
            ..drawCircle(corners[i], 14, Paint()..color = cs[i])
            ..drawOval(
                Rect.fromCenter(center: corners[i], width: 38, height: 10),
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 2
                  ..color = color);
        }
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                photo.inflate(2), const Radius.circular(14)),
            stroke);
      case FrameStyle.galaxy:
        final rnd = math.Random(7);
        for (var i = 0; i < 70; i++) {
          final p = Offset(
              rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
          if (photo.contains(p)) continue;
          canvas.drawCircle(
              p,
              0.8 + rnd.nextDouble() * 1.6,
              Paint()
                ..color = (i % 5 == 0 ? color : CosmosColors.cloudWhite)
                    .withValues(alpha: .8));
        }
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                photo.inflate(3), const Radius.circular(14)),
            stroke..color = CosmosColors.nebulaPurple);
    }
  }

  void _perimeter(
      Canvas canvas, Size s, int count, void Function(Offset, int) draw) {
    final rect = Rect.fromLTWH(20, 20, s.width - 40, s.height - 40);
    final perimeter = 2 * (rect.width + rect.height);
    for (var i = 0; i < count; i++) {
      var d = perimeter * i / count;
      Offset p;
      if (d < rect.width) {
        p = Offset(rect.left + d, rect.top);
      } else if ((d -= rect.width) < rect.height) {
        p = Offset(rect.right, rect.top + d);
      } else if ((d -= rect.height) < rect.width) {
        p = Offset(rect.right - d, rect.bottom);
      } else {
        d -= rect.width;
        p = Offset(rect.left, rect.bottom - d);
      }
      draw(p, i);
    }
  }

  void _star(Canvas canvas, Offset c, double r, Color col) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r : r * .5;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = Offset(c.dx + rr * math.cos(a), c.dy + rr * math.sin(a));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path..close(), Paint()..color = col);
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.style != style || old.color != color;
}
