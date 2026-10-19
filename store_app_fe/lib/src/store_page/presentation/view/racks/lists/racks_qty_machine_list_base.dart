// lib/src/store/presentation/views/racks/lists/racks_qty_list_base.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../auth/controllers/users_controller.dart';
import '../../../../controllers/store_rack_controller.dart';
import '../../../../controllers/store_room_controller.dart';
import '../../../../domains/models/store_rack_model.dart';
import '../../../../domains/models/store_room_model.dart';
import '../edit_rack_page.dart';
import '../widgets/rack_card.dart';
import '../widgets/racks_shared_widgets.dart';
import '../widgets/racks_theme.dart';
import '../qr_code_rack/qr_code_print_rack_page.dart';

class RacksQtyMachineListPage extends ConsumerStatefulWidget {
  const RacksQtyMachineListPage({super.key, required this.isScrap});
  final bool isScrap;

  @override
  ConsumerState<RacksQtyMachineListPage> createState() =>
      _RacksQtyMachineListPageState();
}

class _RacksQtyMachineListPageState
    extends ConsumerState<RacksQtyMachineListPage> {
  StoreRoom? _filterRoom;
  String _q = '';
  int _limit = 12;

  RoomQuery get _roomsQuery =>
      const RoomQuery(page: 1, limit: 300, search: '', sort: 'name');

  RackQuery get _racksQuery => RackQuery(
    page: 1,
    limit: _limit,
    search: _q,
    sort: 'createdAt',
    roomId: _filterRoom?.id,
  );

  void _refresh() {
    if (widget.isScrap) {
      ref.invalidate(storeSrcapMachineRoomPagedStreamProvider(_roomsQuery));
      ref.invalidate(storeScrapMachineRackPagedStreamProvider(_racksQuery));
    } else {
      ref.invalidate(storeGoodMachineRoomPagedStreamProvider(_roomsQuery));
      ref.invalidate(storeGoodMachineRackPagedStreamProvider(_racksQuery));
    }
    setState(() => _limit = 12);
  }

  void _loadMore(PagedRacks paged) {
    final canLoadMore = paged.rows.length < paged.total;
    if (!canLoadMore) return;
    setState(() => _limit += 12);
  }

  Future<void> _openEdit(StoreRack r, bool canEdit) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditRackPage(rack: r, canEdit: canEdit),
      ),
    );
    if (ok == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final pagedUser = ref.watch(userFindOneDataStreamProvider);

    final roomsAv =
        widget.isScrap
            ? ref.watch(storeSrcapMachineRoomPagedStreamProvider(_roomsQuery))
            : ref.watch(storeGoodMachineRoomPagedStreamProvider(_roomsQuery));

    final racksAv =
        widget.isScrap
            ? ref.watch(storeScrapMachineRackPagedStreamProvider(_racksQuery))
            : ref.watch(storeGoodMachineRackPagedStreamProvider(_racksQuery));

    return Scaffold(
      backgroundColor: surface,
      body: pagedUser.when(
        loading: () => const LinearProgressIndicator(minHeight: 2),
        error: (e, _) => Text('User load error: $e'),
        data: (user) {
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [bgTop, bgBottom],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: Column(
                      children: [
                        // Filter row
                        AppCard(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: roomsAv.when(
                                  loading:
                                      () => const LinearProgressIndicator(
                                        minHeight: 2,
                                      ),
                                  error: (e, _) => Text('Room load error: $e'),
                                  data: (paged) {
                                    final rooms = paged.rows;

                                    return DropdownButtonFormField<StoreRoom?>(
                                      isExpanded: true,
                                      isDense: true,
                                      initialValue:
                                          (_filterRoom != null &&
                                                  rooms.any(
                                                    (x) =>
                                                        x.id == _filterRoom!.id,
                                                  ))
                                              ? rooms.firstWhere(
                                                (x) => x.id == _filterRoom!.id,
                                              )
                                              : null,
                                      style: const TextStyle(
                                        color: ink900,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                      dropdownColor: surface,
                                      iconEnabledColor: ink600,
                                      items: [
                                        const DropdownMenuItem<StoreRoom?>(
                                          value: null,
                                          child: Text(
                                            'All rooms',
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: ink900,
                                            ),
                                          ),
                                        ),
                                        for (final r in rooms)
                                          DropdownMenuItem<StoreRoom?>(
                                            value: r,
                                            child: Text(
                                              r.displayName,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                      ],
                                      onChanged: (v) {
                                        setState(() {
                                          _filterRoom = v;
                                          _limit = 12;
                                        });
                                      },
                                      decoration: InputDecoration(
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 10,
                                        ),
                                        hintText: 'Filter by room',
                                        prefixIcon: const Icon(
                                          Icons.meeting_room_rounded,
                                          color: ink600,
                                        ),
                                        filled: true,
                                        fillColor: surfaceAlt.withValues(alpha: .55),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          borderSide: const BorderSide(
                                            color: stroke,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          borderSide: const BorderSide(
                                            color: stroke,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  onChanged: (v) {
                                    setState(() {
                                      _q = v.trim();
                                      _limit = 12;
                                    });
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Search rack...',
                                    hintStyle: const TextStyle(color: ink600),
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                      color: ink600,
                                    ),
                                    filled: true,
                                    fillColor: surfaceAlt.withValues(alpha: .55),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                        color: stroke,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                        color: stroke,
                                      ),
                                    ),
                                  ),
                                  style: const TextStyle(
                                    color: ink900,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        Expanded(
                          child: racksAv.when(
                            loading:
                                () => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                            error: (e, _) => Center(child: Text('Error: $e')),
                            data: (paged) {
                              final rows = paged.rows;
                              if (rows.isEmpty) {
                                return const EmptyStateCard(
                                  title: 'No racks found',
                                  subtitle:
                                      'Create a rack and assign it to a room.',
                                );
                              }

                              final canLoadMore = rows.length < paged.total;

                              return Column(
                                children: [
                                  Expanded(
                                    child: ListView.separated(
                                      itemCount: rows.length,
                                      separatorBuilder:
                                          (_, __) => const SizedBox(height: 10),
                                      itemBuilder: (context, i) {
                                        final r = rows[i];
                                        final canEdit = user != null &&
                                            (user.isSuperAdmin ||
                                                user.appWorks.contains("storeadmin") ||
                                                user.appWorks.contains("storeplaceedit"));

                                        return RackCard(
                                          rack: r,
                                          canEdit: canEdit,
                                          onEdit: () => _openEdit(r, canEdit),
                                          onQr:
                                              () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (_) =>
                                                          QRCodePrintRackPage(
                                                            storeRackList: [r],
                                                          ),
                                                ),
                                              ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  AppCard(
                                    padding: const EdgeInsets.all(10),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Showing ${rows.length} of ${paged.total}',
                                          style: const TextStyle(
                                            color: ink700,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        if (canLoadMore)
                                          FilledButton.icon(
                                            onPressed: () => _loadMore(paged),
                                            icon: const Icon(
                                              Icons.expand_more_rounded,
                                            ),
                                            label: const Text('Load more'),
                                          )
                                        else
                                          const SizedBox.shrink(),
                                        const SizedBox(width: 20),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
