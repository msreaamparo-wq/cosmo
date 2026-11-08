// NOT YET RUN (no Flutter SDK was available when written). Run: flutter test
import 'package:cosmos/models/media_model.dart';
import 'package:cosmos/repositories/album_repository.dart';
import 'package:cosmos/repositories/media_repository.dart';
import 'package:cosmos/repositories/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' show Sqflite;

import 'helpers.dart';

MediaModel _media(String id,
    {String? name, int? size, DateTime? captured, bool video = false}) {
  final now = DateTime.now();
  return MediaModel(
    id: id,
    localUri: '/tmp/$id.jpg',
    mediaType: video ? MediaType.video : MediaType.image,
    fileName: name ?? '$id.jpg',
    fileSize: size ?? 100,
    capturedAt: captured,
    importedAt: now,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late dynamic local;
  late AlbumRepository albums;
  late MediaRepository media;
  late SettingsRepository settings;

  setUp(() async {
    local = await openTestDatabase();
    albums = AlbumRepository(local);
    media = MediaRepository(local);
    settings = SettingsRepository(local);
  });

  tearDown(() => local.close());

  group('albums', () {
    test('create, rename, list', () async {
      final a = await albums.create(
          name: 'Family', planetTheme: 'rings', planetColor: '#8065E8');
      expect((await albums.all()).single.name, 'Family');
      await albums
          .update((await albums.byId(a.id))!.copyWithName('Family Planet'));
      expect((await albums.byId(a.id))!.name, 'Family Planet');
    });

    test('deleting a planet never deletes media', () async {
      final a = await albums.create(
          name: 'Trip', planetTheme: 'plain', planetColor: '#F49BCB');
      await media.insert(_media('m1'));
      await albums.addMedia(a.id, ['m1']);
      expect((await albums.byId(a.id))!.mediaCount, 1);

      await albums.softDelete(a.id);

      expect(await albums.all(), isEmpty);
      expect((await media.byId('m1')), isNotNull);
      expect((await media.stats()).photos, 1);
    });

    test(
        'many-to-many: one photo can live on two planets; removing from one keeps the other',
        () async {
      final a = await albums.create(
          name: 'A', planetTheme: 'plain', planetColor: '#8065E8');
      final b = await albums.create(
          name: 'B', planetTheme: 'plain', planetColor: '#8065E8');
      await media.insert(_media('m1'));
      await albums.addMedia(a.id, ['m1']);
      await albums.addMedia(b.id, ['m1']);
      await albums.removeMedia(a.id, ['m1']);
      expect((await albums.byId(a.id))!.mediaCount, 0);
      expect((await albums.byId(b.id))!.mediaCount, 1);
      expect(
          await media.byId('m1'), isNotNull); // original media record untouched
    });

    test('re-adding a removed photo revives the link', () async {
      final a = await albums.create(
          name: 'A', planetTheme: 'plain', planetColor: '#8065E8');
      await media.insert(_media('m1'));
      await albums.addMedia(a.id, ['m1']);
      await albums.removeMedia(a.id, ['m1']);
      await albums.addMedia(a.id, ['m1']);
      expect((await albums.byId(a.id))!.mediaCount, 1);
    });
  });

  group('media', () {
    test('favorites persist and filter', () async {
      await media.insert(_media('m1'));
      await media.insert(_media('m2', name: 'b.jpg'));
      await media.setFavorite(['m1'], true);
      final favs = await media.page(
          const MediaQueryOptions(filter: MediaFilter.favorites),
          offset: 0,
          limit: 50);
      expect(favs.map((m) => m.id), ['m1']);
      expect((await media.stats()).favorites, 1);
    });

    test('duplicate file (same name + size) is not imported twice', () async {
      expect(await media.insert(_media('m1', name: 'x.jpg', size: 5)), isTrue);
      expect(await media.insert(_media('m2', name: 'x.jpg', size: 5)), isFalse);
    });

    test('missing files are flagged and leave counts and lists', () async {
      await media.insert(_media('m1'));
      await media.markUnavailable('m1');
      expect((await media.stats()).photos, 0);
      expect((await media.stats()).missing, 1);
      expect(await media.page(const MediaQueryOptions(), offset: 0, limit: 10),
          isEmpty);
    });

    test('soft delete hides the item', () async {
      await media.insert(_media('m1'));
      await media.softDelete(['m1']);
      expect(await media.byId('m1'), isNull);
    });

    test('timeline groups only media with real dates; undated stay separate',
        () async {
      await media
          .insert(_media('d1', name: 'a.jpg', captured: DateTime(2024, 3, 10)));
      await media
          .insert(_media('d2', name: 'b.jpg', captured: DateTime(2024, 3, 20)));
      await media.insert(_media('u1', name: 'c.jpg'));
      final groups = await media.timelineGroups();
      expect(groups.single.year, 2024);
      expect(groups.single.month, 3);
      expect(groups.single.count, 2);
      expect(await media.undatedCount(), 1);
    });

    test('paging respects limit/offset', () async {
      for (var i = 0; i < 5; i++) {
        await media.insert(_media('m$i', name: 'f$i.jpg', size: 10 + i));
      }
      expect(
          (await media.page(const MediaQueryOptions(), offset: 0, limit: 2))
              .length,
          2);
      expect(
          (await media.page(const MediaQueryOptions(), offset: 4, limit: 2))
              .length,
          1);
    });

    test('search by file name', () async {
      await media.insert(_media('m1', name: 'birthday.jpg'));
      await media.insert(_media('m2', name: 'beach.jpg', size: 7));
      final r = await media.page(const MediaQueryOptions(search: 'birth'),
          offset: 0, limit: 10);
      expect(r.single.id, 'm1');
    });
  });

  group('settings', () {
    test('values persist and overwrite', () async {
      expect(await settings.get('theme'), isNull);
      await settings.set('theme', 'nebula');
      await settings.set('theme', 'aurora');
      expect(await settings.get('theme'), 'aurora');
    });
  });

  group('sync queue', () {
    Future<int> pending() async =>
        Sqflite.firstIntValue(await (await local.database)
            .rawQuery('SELECT COUNT(*) FROM pending_sync')) ??
        0;

    test('every change is queued once per record (no duplicates)', () async {
      final a = await albums.create(
          name: 'A', planetTheme: 'plain', planetColor: '#8065E8');
      expect(await pending(), 1);
      await albums.update((await albums.byId(a.id))!.copyWithName('A2'));
      expect(await pending(), 1); // same record: one pending row
      await media.insert(_media('m1'));
      expect(await pending(), 2);
    });

    test('deleting records a tombstone, not a hard delete', () async {
      final a = await albums.create(
          name: 'A', planetTheme: 'plain', planetColor: '#8065E8');
      await albums.softDelete(a.id);
      final rows = await (await local.database)
          .query('albums', where: 'id = ?', whereArgs: [a.id]);
      expect(rows.single['deleted_at'], isNotNull);
    });
  });
}
