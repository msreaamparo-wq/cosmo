import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/cosmos_colors.dart';
import '../../core/routing/routes.dart';
import '../../core/utilities/motion.dart';
import '../../models/album_model.dart';
import '../../models/media_model.dart';
import '../../providers/core_providers.dart';
import '../../widgets/cosmic_button.dart';
import '../../widgets/cosmic_loading.dart';
import '../../widgets/cosmic_scaffold.dart';
import '../../widgets/error_message.dart';
import '../../widgets/floating_planet.dart';
import '../../widgets/media_image.dart';
import '../../widgets/media_picker_sheet.dart';

const _stickers = [
  '🌟',
  '🌙',
  '☀️',
  '🚀',
  '🦄',
  '🐶',
  '🐱',
  '🌈',
  '🎂',
  '🏖️',
  '🏫',
  '❤️',
  '🎈',
  '🌸'
];
const _themes = ['rings', 'stripes', 'craters', 'plain'];

/// Create (no id) or edit (with id) a planet, with a live preview.
class CreatePlanetScreen extends ConsumerStatefulWidget {
  const CreatePlanetScreen({super.key, this.editAlbumId});
  final String? editAlbumId;

  @override
  ConsumerState<CreatePlanetScreen> createState() => _CreatePlanetScreenState();
}

class _CreatePlanetScreenState extends ConsumerState<CreatePlanetScreen> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  Color _color = CosmosColors.cosmicViolet;
  String _theme = 'rings';
  String? _sticker;
  MediaModel? _cover;
  AlbumModel? _existing;
  bool _loading = false;
  bool _failed = false;
  bool _saving = false;
  String? _nameError;

  bool get _editing => widget.editAlbumId != null;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    if (_editing) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final a =
          await ref.read(albumRepositoryProvider).byId(widget.editAlbumId!);
      if (a == null) {
        setState(() {
          _failed = true;
          _loading = false;
        });
        return;
      }
      MediaModel? cover;
      if (a.coverMediaId != null)
        cover = await ref.read(mediaRepositoryProvider).byId(a.coverMediaId!);
      if (!mounted) return;
      setState(() {
        _existing = a;
        _name.text = a.name;
        _desc.text = a.description ?? '';
        _color = ColorOpacityX.fromHex(a.planetColor);
        _theme = a.planetTheme;
        _sticker = a.sticker;
        _cover = cover;
        _loading = false;
      });
    } catch (_) {
      if (mounted)
        setState(() {
          _failed = true;
          _loading = false;
        });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final ids = await showMediaPickerSheet(context,
        single: true, photosOnly: true, title: 'Choose a cover photo');
    if (ids == null || ids.isEmpty) return;
    final m = await ref.read(mediaRepositoryProvider).byId(ids.first);
    if (mounted) setState(() => _cover = m);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Give your planet a name!');
      return;
    }
    if (name.length > 60) {
      setState(() =>
          _nameError = 'That name is a bit long. Try 60 letters or fewer.');
      return;
    }
    setState(() {
      _saving = true;
      _nameError = null;
    });
    try {
      final repo = ref.read(albumRepositoryProvider);
      if (_editing && _existing != null) {
        await repo.update(AlbumModel(
          id: _existing!.id,
          name: name,
          planetTheme: _theme,
          planetColor: _color.toHex(),
          sticker: _sticker,
          description: _desc.text,
          coverMediaId: _cover?.id,
          createdAt: _existing!.createdAt,
          updatedAt: DateTime.now(),
        ));
        refreshUniverse(ref);
        if (mounted) context.pop();
      } else {
        final a = await repo.create(
            name: name,
            planetTheme: _theme,
            planetColor: _color.toHex(),
            sticker: _sticker,
            description: _desc.text,
            coverMediaId: _cover?.id);
        refreshUniverse(ref);
        if (!mounted) return;
        if (MotionScope.of(context)) await _celebrate(a);
        if (mounted) context.pushReplacement(CosmosRoutes.planet(a.id));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not save your planet. Please try again.')));
      }
    }
  }

  Future<void> _celebrate(AlbumModel a) async {
    final nav = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.2, end: 1),
          duration: const Duration(milliseconds: 900),
          curve: Curves.elasticOut,
          builder: (_, v, child) => Transform.scale(scale: v, child: child),
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingPlanet(color: _color, theme: _theme, size: 180),
                const SizedBox(height: 8),
                Text('${a.name} is born!',
                    style: Theme.of(context).textTheme.headlineSmall),
              ],
            ),
          ),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (nav.canPop()) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (_loading)
      return const CosmicScaffold(title: 'Edit Planet', body: CosmicLoading());
    if (_failed)
      return CosmicScaffold(
          title: 'Edit Planet',
          body: ErrorMessage(
              message: 'We could not find that planet.', onRetry: _load));

    return CosmicScaffold(
      title: _editing ? 'Edit Your Planet' : 'Create Your Own Planet!',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Live preview
              Center(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        FloatingPlanet(
                            color: _color,
                            theme: _theme,
                            size: 180,
                            semanticLabel: 'Planet preview'),
                        if (_sticker != null)
                          Positioned(
                              right: 0,
                              top: 0,
                              child: Text(_sticker!,
                                  style: const TextStyle(fontSize: 36))),
                      ],
                    ),
                    Text(
                        _name.text.trim().isEmpty
                            ? 'My new planet'
                            : _name.text.trim(),
                        style: text.headlineSmall,
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                maxLength: 60,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                    labelText: 'Planet name',
                    errorText: _nameError,
                    prefixIcon: const Icon(Icons.edit)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _desc,
                maxLength: 200,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    prefixIcon: Icon(Icons.notes)),
              ),
              const SizedBox(height: 12),
              Text('Color', style: text.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final c in CosmosColors.planetChoices)
                    Semantics(
                      button: true,
                      selected: c == _color,
                      label: 'Planet color',
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => setState(() => _color = c),
                        child: Container(
                          width: 52,
                          height: 52,
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
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Style', style: text.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final t in _themes)
                    Semantics(
                      button: true,
                      selected: t == _theme,
                      label: '$t planet style',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => setState(() => _theme = t),
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: CosmosColors.midnightPurple,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                                color: t == _theme
                                    ? CosmosColors.starYellow
                                    : Colors.transparent,
                                width: 3),
                          ),
                          child: FloatingPlanet(
                              color: _color,
                              theme: t,
                              size: 70,
                              animate: false,
                              bobDistance: 0),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Sticker', style: text.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                      label: const Text('None'),
                      selected: _sticker == null,
                      onSelected: (_) => setState(() => _sticker = null)),
                  for (final s in _stickers)
                    ChoiceChip(
                      label: Text(s, style: const TextStyle(fontSize: 24)),
                      selected: _sticker == s,
                      onSelected: (_) => setState(() => _sticker = s),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Cover photo', style: text.titleMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (_cover != null)
                    Container(
                      width: 72,
                      height: 72,
                      margin: const EdgeInsets.only(right: 12),
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: MediaImage(_cover!, logicalWidth: 72)),
                    ),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        CosmicButton(
                            label: _cover == null
                                ? 'Choose a cover'
                                : 'Change cover',
                            icon: Icons.photo,
                            color: CosmosColors.midnightPurple,
                            onPressed: _pickCover),
                        if (_cover != null)
                          TextButton(
                              onPressed: () => setState(() => _cover = null),
                              child: const Text('Remove')),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                      child: CosmicButton(
                          label: 'Cancel',
                          color: CosmosColors.midnightPurple,
                          expand: true,
                          onPressed: _saving ? null : () => context.pop())),
                  const SizedBox(width: 12),
                  Expanded(
                      child: CosmicButton(
                          label: _saving
                              ? 'Saving…'
                              : (_editing ? 'Save' : 'Create planet'),
                          icon: Icons.rocket_launch,
                          expand: true,
                          onPressed: _saving ? null : _save)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
