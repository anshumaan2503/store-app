import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:store_app/src/auth/shared/repositories/shared_preference_repository.dart';

enum ScannerTargetMode {
  itemOnly('item', 'Item only'),
  placeOnly('place', 'Place only'),
  both('both', 'Both');

  final String key;
  final String label;
  const ScannerTargetMode(this.key, this.label);

  static ScannerTargetMode fromKey(String? key) {
    if (key == 'item') return ScannerTargetMode.itemOnly;
    if (key == 'place') return ScannerTargetMode.placeOnly;
    return ScannerTargetMode.both;
  }
}

enum ScannerWorkflow {
  receive('Receive Scanner', 'receive'),
  putaway('Put Away Scanner', 'putaway'),
  issue('Issue Scanner', 'issue');

  final String title;
  final String key;
  const ScannerWorkflow(this.title, this.key);
}

class ScannerSettingsState {
  final ScannerTargetMode receiveMode;
  final ScannerTargetMode putawayMode;
  final ScannerTargetMode issueMode;

  const ScannerSettingsState({
    this.receiveMode = ScannerTargetMode.both,
    this.putawayMode = ScannerTargetMode.both,
    this.issueMode = ScannerTargetMode.both,
  });

  ScannerTargetMode getMode(ScannerWorkflow workflow) {
    switch (workflow) {
      case ScannerWorkflow.receive:
        return receiveMode;
      case ScannerWorkflow.putaway:
        return putawayMode;
      case ScannerWorkflow.issue:
        return issueMode;
    }
  }

  ScannerSettingsState copyWith({
    ScannerTargetMode? receiveMode,
    ScannerTargetMode? putawayMode,
    ScannerTargetMode? issueMode,
  }) {
    return ScannerSettingsState(
      receiveMode: receiveMode ?? this.receiveMode,
      putawayMode: putawayMode ?? this.putawayMode,
      issueMode: issueMode ?? this.issueMode,
    );
  }
}

class ScannerSettingsNotifier extends StateNotifier<ScannerSettingsState> {
  final SharedPreferenceRepository _spRepo;

  ScannerSettingsNotifier(this._spRepo) : super(const ScannerSettingsState()) {
    _loadSettings();
  }

  static const _keyReceive = 'scanner_mode_receive';
  static const _keyPutaway = 'scanner_mode_putaway';
  static const _keyIssue = 'scanner_mode_issue';

  Future<void> _loadSettings() async {
    try {
      final rec = await _spRepo.getStringValue(_keyReceive);
      final put = await _spRepo.getStringValue(_keyPutaway);
      final iss = await _spRepo.getStringValue(_keyIssue);

      state = ScannerSettingsState(
        receiveMode: ScannerTargetMode.fromKey(rec),
        putawayMode: ScannerTargetMode.fromKey(put),
        issueMode: ScannerTargetMode.fromKey(iss),
      );
    } catch (_) {}
  }

  Future<void> setMode(ScannerWorkflow workflow, ScannerTargetMode mode) async {
    switch (workflow) {
      case ScannerWorkflow.receive:
        state = state.copyWith(receiveMode: mode);
        await _spRepo.setStringValue(_keyReceive, mode.key);
        break;
      case ScannerWorkflow.putaway:
        state = state.copyWith(putawayMode: mode);
        await _spRepo.setStringValue(_keyPutaway, mode.key);
        break;
      case ScannerWorkflow.issue:
        state = state.copyWith(issueMode: mode);
        await _spRepo.setStringValue(_keyIssue, mode.key);
        break;
    }
  }
}

final scannerSettingsProvider =
    StateNotifierProvider<ScannerSettingsNotifier, ScannerSettingsState>((ref) {
  final spRepo = ref.watch(spRepositoryProvider);
  return ScannerSettingsNotifier(spRepo);
});

