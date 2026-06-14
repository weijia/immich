import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/album/local_album.model.dart';
import 'package:immich_mobile/domain/services/local_album.service.dart';
import 'package:immich_mobile/infrastructure/repositories/local_album.repository.dart';
import 'package:immich_mobile/providers/infrastructure/album.provider.dart';
import 'package:logging/logging.dart';

final backupAlbumProvider = StateNotifierProvider<BackupAlbumNotifier, List<LocalAlbum>>(
  (ref) => BackupAlbumNotifier(ref.watch(localAlbumServiceProvider)),
);

class BackupAlbumNotifier extends StateNotifier<List<LocalAlbum>> {
  BackupAlbumNotifier(this._localAlbumService) : super([]) {
    getAll();
  }

  final LocalAlbumService _localAlbumService;
  final _log = Logger('BackupAlbumNotifier');

  Future<void> getAll() async {
    _log.info('[BackupAlbumNotifier] getAll() called');
    state = await _localAlbumService.getAll(sortBy: {SortLocalAlbumsBy.assetCount});
    _log.info('[BackupAlbumNotifier] getAll() returned ${state.length} albums');
    for (final album in state) {
      _log.debug('[BackupAlbumNotifier] Album: ${album.name}, backupSelection=${album.backupSelection}');
    }
  }

  Future<void> selectAlbum(LocalAlbum album) async {
    _log.info('[BackupAlbumNotifier] selectAlbum() called: ${album.name}, current selection=${album.backupSelection}');
    album = album.copyWith(backupSelection: BackupSelection.selected);
    await _localAlbumService.update(album);
    _log.info('[BackupAlbumNotifier] selectAlbum() database updated');

    state = state
        .map(
          (currentAlbum) => currentAlbum.id == album.id
              ? currentAlbum.copyWith(backupSelection: BackupSelection.selected)
              : currentAlbum,
        )
        .toList();
    _log.info('[BackupAlbumNotifier] selectAlbum() state updated, new selection=${state.firstWhere((a) => a.id == album.id).backupSelection}');
  }

  Future<void> deselectAlbum(LocalAlbum album) async {
    _log.info('[BackupAlbumNotifier] deselectAlbum() called: ${album.name}, current selection=${album.backupSelection}');
    album = album.copyWith(backupSelection: BackupSelection.none);
    await _localAlbumService.update(album);
    _log.info('[BackupAlbumNotifier] deselectAlbum() database updated');

    state = state
        .map(
          (currentAlbum) =>
              currentAlbum.id == album.id ? currentAlbum.copyWith(backupSelection: BackupSelection.none) : currentAlbum,
        )
        .toList();
    _log.info('[BackupAlbumNotifier] deselectAlbum() state updated');
  }

  Future<void> excludeAlbum(LocalAlbum album) async {
    _log.info('[BackupAlbumNotifier] excludeAlbum() called: ${album.name}, current selection=${album.backupSelection}');
    album = album.copyWith(backupSelection: BackupSelection.excluded);
    await _localAlbumService.update(album);
    _log.info('[BackupAlbumNotifier] excludeAlbum() database updated');

    state = state
        .map(
          (currentAlbum) => currentAlbum.id == album.id
              ? currentAlbum.copyWith(backupSelection: BackupSelection.excluded)
              : currentAlbum,
        )
        .toList();
    _log.info('[BackupAlbumNotifier] excludeAlbum() state updated');
  }
}
