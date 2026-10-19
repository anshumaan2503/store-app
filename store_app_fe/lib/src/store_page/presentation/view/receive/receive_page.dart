// import 'dart:async';

// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

// import '../../../../auth/controllers/users_controller.dart';
// import '../../../../auth/shared/repositories/shared_preference_repository.dart';
// import '../../../../components/socket_manager.dart';
// import '../../../../components/utils.dart';

// import '../../../controllers/store_items_controller.dart';
// import '../../../domains/models/store_item_name_model.dart';
// import '../../../domains/models/store_rack_model.dart';

// import '../../../controllers/store_receive_controller.dart';
// import 'qr_code_receive.dart/qr_scanner_receive_page.dart';

// /* ---------------- Palette (your theme) ---------------- */
// const _ink900 = Color(0xFF282321);
// const _ink700 = Color(0xFF4D4542);
// const _ink600 = Color(0xFF867471);

// const _surface = Color(0xFFFFFFFF);
// const _surfaceAlt = Color(0xFFFFF4E2);
// const _stroke = Color(0xFFDFE1D6);

// const _accentMint = Color(0xFFB6D3CC);
// const _bgTop = Color(0xFFFFFFF3);
// const _bgBottom = _surfaceAlt;

// /* ---------------- Queries & DTO models for websocket ---------------- */

// @immutable
// class ReceiveRackQuery {
//   final int page;
//   final int limit;
//   final String search;
//   final String sort;
//   const ReceiveRackQuery({
//     this.page = 1,
//     this.limit = 200,
//     this.search = '',
//     this.sort = 'name',
//   });

//   Map<String, dynamic> toJson() => {
//     "page": page,
//     "limit": limit,
//     "search": search,
//     "sort": sort,
//   };

//   @override
//   bool operator ==(Object other) =>
//       identical(this, other) ||
//       other is ReceiveRackQuery &&
//           other.page == page &&
//           other.limit == limit &&
//           other.search == search &&
//           other.sort == sort;

//   @override
//   int get hashCode => Object.hash(page, limit, search, sort);
// }

// class ReceiveRackPagedResult {
//   final List<StoreRack> rows;
//   final int total;
//   const ReceiveRackPagedResult({required this.rows, required this.total});
// }

// @immutable
// class ReceiveItemNameQuery {
//   final int page;
//   final int limit;
//   final String search;
//   final String sort;
//   const ReceiveItemNameQuery({
//     this.page = 1,
//     this.limit = 250,
//     this.search = '',
//     this.sort = 'name',
//   });

//   Map<String, dynamic> toJson() => {
//     "page": page,
//     "limit": limit,
//     "search": search,
//     "sort": sort,
//   };

//   @override
//   bool operator ==(Object other) =>
//       identical(this, other) ||
//       other is ReceiveItemNameQuery &&
//           other.page == page &&
//           other.limit == limit &&
//           other.search == search &&
//           other.sort == sort;

//   @override
//   int get hashCode => Object.hash(page, limit, search, sort);
// }

// class ReceiveItemNamePagedResult {
//   final List<StoreItemName> rows;
//   final int total;
//   const ReceiveItemNamePagedResult({required this.rows, required this.total});
// }

// /* A rack option returned from backend for a selected itemNameId.
//    IMPORTANT: includes itemId for that rack, so we can receive correctly. */
// class ItemRackOption {
//   final String itemId;
//   final String rackId;
//   final String rackName;
//   final String rackCode;
//   final int available;
//   final int total;

//   ItemRackOption({
//     required this.itemId,
//     required this.rackId,
//     required this.rackName,
//     required this.rackCode,
//     required this.available,
//     required this.total,
//   });

//   factory ItemRackOption.fromMap(Map<String, dynamic> m) {
//     int asInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
//     return ItemRackOption(
//       itemId: (m['itemId'] ?? '').toString(),
//       rackId: (m['rackId'] ?? '').toString(),
//       rackName: (m['rackName'] ?? '').toString(),
//       rackCode: (m['rackCode'] ?? '').toString(),
//       available: asInt(m['available']),
//       total: asInt(m['total']),
//     );
//   }
// }

// /* ---------------- Websocket Stream Providers ----------------
//    Event names used here (backend must emit same):
//    - 'store:findAllRackPaged'
//    - 'store:findAllItemNamePaged'
//    - 'store:rackItem'            { rackId } -> item or null
//    - 'store:itemNameRacks'       { itemNameId } -> List<ItemRackOption-like maps>
// */

// final receiveRackPagedStreamProvider = StreamProvider.autoDispose
//     .family<ReceiveRackPagedResult, ReceiveRackQuery>((ref, q) {
//       final socket = ref.watch(socketProvider).getSocket();
//       final ctrl = StreamController<ReceiveRackPagedResult>();

//       void handler(dynamic data) {
//         try {
//           if (data is! Map) return;
//           final rowsRaw = (data['rows'] as List?) ?? const [];
//           final list =
//               rowsRaw
//                   .map(
//                     (e) =>
//                         StoreRack.fromMap(Map<String, dynamic>.from(e as Map)),
//                   )
//                   .toList();
//           final total =
//               (data['total'] is int)
//                   ? data['total'] as int
//                   : int.tryParse('${data['total']}') ?? list.length;

//           ctrl.add(ReceiveRackPagedResult(rows: list, total: total));
//         } catch (e) {
//           debugPrint('store:findAllRackPaged handler error: $e');
//         }
//       }

//       socket.on('store:findAllRackPaged', handler);
//       socket.emit('store:findAllRackPaged', q.toJson());

//       // prevent infinite loading
//       ctrl.add(const ReceiveRackPagedResult(rows: [], total: 0));

//       ref.onDispose(() {
//         socket.off('store:findAllRackPaged', handler);
//         ctrl.close();
//       });

//       return ctrl.stream;
//     });

// // final receiveItemNamePagedStreamProvider = StreamProvider.autoDispose
// //     .family<ReceiveItemNamePagedResult, ReceiveItemNameQuery>((ref, q) {
// //       final socket = ref.watch(socketProvider).getSocket();
// //       final ctrl = StreamController<ReceiveItemNamePagedResult>();

// //       void handler(dynamic data) {
// //         try {
// //           if (data is! Map) return;
// //           final rowsRaw = (data['rows'] as List?) ?? const [];
// //           final list =
// //               rowsRaw
// //                   .map(
// //                     (e) => StoreItemName.fromMap(
// //                       Map<String, dynamic>.from(e as Map),
// //                     ),
// //                   )
// //                   .toList();
// //           final total =
// //               (data['total'] is int)
// //                   ? data['total'] as int
// //                   : int.tryParse('${data['total']}') ?? list.length;

// //           ctrl.add(ReceiveItemNamePagedResult(rows: list, total: total));
// //         } catch (e) {
// //           debugPrint('store:findAllItemNamePaged handler error: $e');
// //         }
// //       }

// //       socket.on('store:findAllItemNamePaged', handler);
// //       socket.emit('store:findAllItemNamePaged', q.toJson());

// //       ctrl.add(const ReceiveItemNamePagedResult(rows: [], total: 0));

// //       ref.onDispose(() {
// //         socket.off('store:findAllItemNamePaged', handler);
// //         ctrl.close();
// //       });

// //       return ctrl.stream;
// //     });

// final itemNameRacksStreamProvider = StreamProvider.autoDispose
//     .family<List<ItemRackOption>, String>((ref, itemNameId) {
//       final socket = ref.watch(socketProvider).getSocket();
//       final ctrl = StreamController<List<ItemRackOption>>();

//       void handler(dynamic data) {
//         try {
//           if (data is List) {
//             final list =
//                 data
//                     .map(
//                       (e) => ItemRackOption.fromMap(
//                         Map<String, dynamic>.from(e as Map),
//                       ),
//                     )
//                     .toList();
//             ctrl.add(list);
//           }
//         } catch (e) {
//           debugPrint('store:itemNameRacks handler error: $e');
//         }
//       }

//       socket.on('store:itemNameRacks', handler);
//       socket.emit('store:itemNameRacks', {"itemNameId": itemNameId});

//       ctrl.add(const []);

//       ref.onDispose(() {
//         socket.off('store:itemNameRacks', handler);
//         ctrl.close();
//       });

//       return ctrl.stream;
//     });

// /* ---------------- Receive Page ---------------- */

// class ReceivePage extends ConsumerStatefulWidget {
//   const ReceivePage({super.key});

//   @override
//   ConsumerState<ReceivePage> createState() => _ReceivePageState();
// }

// class _ReceivePageState extends ConsumerState<ReceivePage>
//     with TickerProviderStateMixin {
//   late final TabController _tabs = TabController(length: 2, vsync: this);

//   // Rack-first state
//   String _rackSearch = '';
//   StoreRack? _selectedRack;
//   final _rackQtyCtrl = TextEditingController();

//   // Item-first state
//   String _itemSearch = '';
//   // StoreItemName? _selectedItemName;
//   ItemRackOption? _selectedItemRack;
//   final _itemQtyCtrl = TextEditingController();

//   bool _busy = false;

//   @override
//   void dispose() {
//     _tabs.dispose();
//     _rackQtyCtrl.dispose();
//     _itemQtyCtrl.dispose();
//     super.dispose();
//   }

//   int? _tryInt(TextEditingController c) {
//     final s = c.text.trim();
//     if (s.isEmpty) return null;
//     return int.tryParse(s);
//   }

//   Future<String> _uid() async =>
//       await ref.read(spRepositoryProvider).getStringValue("uid") ?? "";

//   @override
//   Widget build(BuildContext context) {
//     final pagedUser = ref.watch(userFindOneDataStreamProvider);
//     return pagedUser.when(
//       loading: () => const LinearProgressIndicator(minHeight: 2),
//       error: (e, _) => Text('Room load error: $e'),
//       data: (user) {
//         return Scaffold(
//           floatingActionButton:
//               (user!.appWorks.contains("storreceiveadd"))
//                   ? FloatingActionButton.extended(
//                     onPressed: () {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (_) => const QRCodeScannerRackPage(),
//                         ),
//                       );
//                     },
//                     elevation: 6,
//                     backgroundColor: _ink900,
//                     foregroundColor: _surface,
//                     icon: const Icon(Icons.qr_code_scanner),
//                     label: const Text(
//                       'QR Item',
//                       style: TextStyle(fontWeight: FontWeight.w900),
//                     ),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(16),
//                       side: const BorderSide(color: _stroke),
//                     ),
//                   )
//                   : null,

//           body: Container(
//             decoration: const BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [_bgTop, _bgBottom],
//                 begin: Alignment.topCenter,
//                 end: Alignment.bottomCenter,
//               ),
//             ),
//             child: Center(
//               child: ConstrainedBox(
//                 constraints: const BoxConstraints(maxWidth: 980),
//                 child: Padding(
//                   padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.stretch,
//                     children: [
//                       _Card(
//                         padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.stretch,
//                           children: [
//                             const Text(
//                               'Receive',
//                               style: TextStyle(
//                                 color: _ink900,
//                                 fontWeight: FontWeight.w900,
//                                 fontSize: 18,
//                               ),
//                             ),
//                             const SizedBox(height: 6),
//                             const Text(
//                               'Receive items via Rack-first or Item-first flow.',
//                               style: TextStyle(
//                                 color: _ink600,
//                                 fontWeight: FontWeight.w700,
//                               ),
//                             ),
//                             const SizedBox(height: 12),
//                             Container(
//                               padding: const EdgeInsets.all(6),
//                               decoration: BoxDecoration(
//                                 color: _surface,
//                                 borderRadius: BorderRadius.circular(14),
//                                 border: Border.all(color: _stroke),
//                               ),
//                               child: TabBar(
//                                 controller: _tabs,
//                                 dividerColor: Colors.transparent,
//                                 indicator: BoxDecoration(
//                                   color: _ink900,
//                                   borderRadius: BorderRadius.circular(12),
//                                 ),
//                                 labelColor: _surface,
//                                 unselectedLabelColor: _ink600,
//                                 labelStyle: const TextStyle(
//                                   fontWeight: FontWeight.w900,
//                                 ),
//                                 tabs: const [
//                                   Tab(text: 'Rack first'),
//                                   Tab(text: 'Item first'),
//                                 ],
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                       const SizedBox(height: 12),
//                       Expanded(
//                         child: TabBarView(
//                           controller: _tabs,
//                           children: [_rackFirst(), _itemFirst()],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }

//   Widget _rackFirst() {
//     final q = ReceiveRackQuery(search: _rackSearch.trim());
//     final racksAv = ref.watch(receiveRackPagedStreamProvider(q));
//     final itemAv =
//         _selectedRack == null
//             ? null
//             : ref.watch(rackItemStreamProvider(_selectedRack!.id));

//     return LayoutBuilder(
//       builder: (context, c) {
//         final wide = c.maxWidth >= 860;

//         final left = _Card(
//           padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               const _SectionTitle(
//                 '1) Select Rack',
//                 'If rack has item → Add Item',
//               ),
//               const SizedBox(height: 10),
//               TextField(
//                 onChanged: (v) => setState(() => _rackSearch = v.trim()),
//                 decoration: const InputDecoration(
//                   prefixIcon: Icon(Icons.search_rounded),
//                   hintText: 'Search rack by name/code...',
//                 ),
//               ),
//               const SizedBox(height: 10),
//               Expanded(
//                 child: racksAv.when(
//                   loading:
//                       () => const Center(child: CircularProgressIndicator()),
//                   error: (e, _) => Center(child: Text('Rack load error: $e')),
//                   data: (paged) {
//                     final list = paged.rows;
//                     if (list.isEmpty) {
//                       return const Center(child: Text('No racks found'));
//                     }
//                     return ListView.separated(
//                       itemCount: list.length,
//                       separatorBuilder: (_, __) => const Divider(height: 1),
//                       itemBuilder: (_, i) {
//                         final r = list[i];
//                         final sel = _selectedRack?.id == r.id;
//                         return ListTile(
//                           onTap: () {
//                             setState(() {
//                               _selectedRack = r;
//                               _rackQtyCtrl.clear();
//                             });
//                           },
//                           leading: Icon(
//                             sel
//                                 ? Icons.radio_button_checked
//                                 : Icons.radio_button_off,
//                             color: sel ? _ink900 : _ink600,
//                           ),
//                           title: Text(
//                             r.code,
//                             style: const TextStyle(fontWeight: FontWeight.w900),
//                           ),
//                           subtitle: Text(r.code),
//                         );
//                       },
//                     );
//                   },
//                 ),
//               ),
//             ],
//           ),
//         );

//         final right = _Card(
//           padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               const _SectionTitle(
//                 '2) Add Item',
//                 'Receive quantity into item on this rack',
//               ),
//               const SizedBox(height: 10),
//               if (_selectedRack == null)
//                 const Expanded(
//                   child: Center(
//                     child: Text(
//                       'Select a rack to continue.',
//                       style: TextStyle(
//                         color: _ink700,
//                         fontWeight: FontWeight.w700,
//                       ),
//                     ),
//                   ),
//                 )
//               else
//                 Expanded(
//                   child: itemAv!.when(
//                     loading:
//                         () => const Center(child: CircularProgressIndicator()),
//                     error:
//                         (e, _) => Center(child: Text('Item fetch error: $e')),
//                     data: (item) {
//                       if (item == null) {
//                         return Column(
//                           crossAxisAlignment: CrossAxisAlignment.stretch,
//                           children: [
//                             _HintBar(
//                               text:
//                                   'This rack does not have any mapped item. Create an Item mapping for this rack first.',
//                             ),
//                             const SizedBox(height: 12),
//                             _InfoRow(
//                               label: 'Rack',
//                               value:
//                                   '${_selectedRack!.code} (${_selectedRack!.code})',
//                             ),
//                             const Spacer(),
//                           ],
//                         );
//                       }

//                       return Column(
//                         crossAxisAlignment: CrossAxisAlignment.stretch,
//                         children: [
//                           _HintBar(
//                             text:
//                                 'Receiving will increase Total & Available stock for this item.',
//                           ),
//                           const SizedBox(height: 12),
//                           // _InfoRow(label: 'Rack', value: item.rackName),
//                           _InfoRow(
//                             label: 'Item',
//                             value: '${item.itemName} (${item.itemCode})',
//                           ),
//                           _InfoRow(
//                             label: 'Current Available',
//                             value: '${item.stockAvailableQuantity}',
//                           ),
//                           _InfoRow(
//                             label: 'Current Total',
//                             value: '${item.totalStockQuantity}',
//                           ),
//                           const SizedBox(height: 12),
//                           TextField(
//                             controller: _rackQtyCtrl,
//                             keyboardType: TextInputType.number,
//                             decoration: const InputDecoration(
//                               prefixIcon: Icon(Icons.add_rounded),
//                               hintText: 'Enter receive quantity (e.g., 10)',
//                             ),
//                           ),
//                           const Spacer(),
//                           FilledButton.icon(
//                             onPressed:
//                                 _busy
//                                     ? null
//                                     : () => _confirmReceiveItem(
//                                       itemId: item.id,
//                                       qtyCtrl: _rackQtyCtrl,
//                                       rackId: _selectedRack!.roomId,
//                                     ),
//                             icon:
//                                 _busy
//                                     ? const SizedBox(
//                                       width: 16,
//                                       height: 16,
//                                       child: CircularProgressIndicator(
//                                         strokeWidth: 2,
//                                       ),
//                                     )
//                                     : const Icon(Icons.check_rounded),
//                             label: Text(_busy ? 'Adding...' : 'Add Item'),
//                           ),
//                         ],
//                       );
//                     },
//                   ),
//                 ),
//             ],
//           ),
//         );

//         if (!wide) {
//           return Column(
//             children: [
//               Expanded(child: left),
//               const SizedBox(height: 12),
//               Expanded(child: right),
//             ],
//           );
//         }

//         return Row(
//           children: [
//             Expanded(child: left),
//             const SizedBox(width: 12),
//             Expanded(child: right),
//           ],
//         );
//       },
//     );
//   }

//   Widget _itemFirst() {
//     final iq = ReceiveItemNameQuery(search: _itemSearch.trim());
//     final itemsAv = ref.watch(receiveItemNamePagedStreamProvider(iq));
//     final racksAv =
//         _selectedItemName == null
//             ? null
//             : ref.watch(itemNameRacksStreamProvider(_selectedItemName!.id));

//     return LayoutBuilder(
//       builder: (context, c) {
//         final wide = c.maxWidth >= 860;

//         final left = _Card(
//           padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               const _SectionTitle(
//                 '1) Select Item',
//                 'If item exists in multiple racks → choose rack next',
//               ),
//               const SizedBox(height: 10),
//               TextField(
//                 onChanged: (v) => setState(() => _itemSearch = v.trim()),
//                 decoration: const InputDecoration(
//                   prefixIcon: Icon(Icons.search_rounded),
//                   hintText: 'Search item by name/code...',
//                 ),
//               ),
//               const SizedBox(height: 10),
//               Expanded(
//                 child: itemsAv.when(
//                   loading:
//                       () => const Center(child: CircularProgressIndicator()),
//                   error:
//                       (e, _) => Center(child: Text('ItemName load error: $e')),
//                   data: (paged) {
//                     final list = paged.rows;
//                     if (list.isEmpty)
//                       return const Center(child: Text('No items found'));
//                     return ListView.separated(
//                       itemCount: list.length,
//                       separatorBuilder: (_, __) => const Divider(height: 1),
//                       itemBuilder: (_, i) {
//                         final it = list[i];
//                         final sel = _selectedItemName?.id == it.id;
//                         return ListTile(
//                           onTap: () {
//                             setState(() {
//                               _selectedItemName = it;
//                               _selectedItemRack = null;
//                               _itemQtyCtrl.clear();
//                             });
//                           },
//                           leading: Icon(
//                             sel
//                                 ? Icons.radio_button_checked
//                                 : Icons.radio_button_off,
//                             color: sel ? _ink900 : _ink600,
//                           ),
//                           title: Text(
//                             it.name,
//                             style: const TextStyle(fontWeight: FontWeight.w900),
//                           ),
//                           subtitle: Text(it.code),
//                         );
//                       },
//                     );
//                   },
//                 ),
//               ),
//             ],
//           ),
//         );

//         final right = _Card(
//           padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               const _SectionTitle(
//                 '2) Select Rack & Add',
//                 'Choose destination rack, then receive quantity',
//               ),
//               const SizedBox(height: 10),
//               if (_selectedItemName == null)
//                 const Expanded(
//                   child: Center(
//                     child: Text(
//                       'Select an item to continue.',
//                       style: TextStyle(
//                         color: _ink700,
//                         fontWeight: FontWeight.w700,
//                       ),
//                     ),
//                   ),
//                 )
//               else
//                 Expanded(
//                   child: racksAv!.when(
//                     loading:
//                         () => const Center(child: CircularProgressIndicator()),
//                     error:
//                         (e, _) => Center(child: Text('Racks load error: $e')),
//                     data: (list) {
//                       if (list.isEmpty) {
//                         return const Center(
//                           child: Text(
//                             'No racks found for this item (no mappings).',
//                           ),
//                         );
//                       }

//                       return Column(
//                         crossAxisAlignment: CrossAxisAlignment.stretch,
//                         children: [
//                           _HintBar(
//                             text:
//                                 'Select the rack where you want to receive this item. Backend returns itemId per rack mapping.',
//                           ),
//                           const SizedBox(height: 10),
//                           Expanded(
//                             child: ListView.separated(
//                               itemCount: list.length,
//                               separatorBuilder:
//                                   (_, __) => const Divider(height: 1),
//                               itemBuilder: (_, i) {
//                                 final r = list[i];
//                                 final sel =
//                                     _selectedItemRack?.rackId == r.rackId;
//                                 return ListTile(
//                                   onTap:
//                                       () =>
//                                           setState(() => _selectedItemRack = r),
//                                   leading: Icon(
//                                     sel
//                                         ? Icons.radio_button_checked
//                                         : Icons.radio_button_off,
//                                     color: sel ? _ink900 : _ink600,
//                                   ),
//                                   title: Text(
//                                     r.rackName,
//                                     style: const TextStyle(
//                                       fontWeight: FontWeight.w900,
//                                     ),
//                                   ),
//                                   subtitle: Text(
//                                     '${r.rackCode}  •  Avail: ${r.available}  •  Total: ${r.total}',
//                                   ),
//                                 );
//                               },
//                             ),
//                           ),
//                           const SizedBox(height: 10),
//                           TextField(
//                             controller: _itemQtyCtrl,
//                             keyboardType: TextInputType.number,
//                             decoration: const InputDecoration(
//                               prefixIcon: Icon(Icons.add_rounded),
//                               hintText: 'Enter receive quantity (e.g., 10)',
//                             ),
//                           ),
//                           const SizedBox(height: 10),
//                           FilledButton.icon(
//                             onPressed:
//                                 _busy
//                                     ? null
//                                     : () {
//                                       if (_selectedItemRack == null) {
//                                         ScaffoldMessenger.of(
//                                           context,
//                                         ).showSnackBar(
//                                           const SnackBar(
//                                             content: Text('Select rack'),
//                                           ),
//                                         );
//                                         return;
//                                       }
//                                       _confirmReceiveItem(
//                                         itemId: _selectedItemRack!.itemId,
//                                         qtyCtrl: _itemQtyCtrl,
//                                         rackId: _selectedItemRack!.rackId,
//                                       );
//                                     },
//                             icon:
//                                 _busy
//                                     ? const SizedBox(
//                                       width: 16,
//                                       height: 16,
//                                       child: CircularProgressIndicator(
//                                         strokeWidth: 2,
//                                       ),
//                                     )
//                                     : const Icon(Icons.check_rounded),
//                             label: Text(_busy ? 'Adding...' : 'Add Item'),
//                           ),
//                         ],
//                       );
//                     },
//                   ),
//                 ),
//             ],
//           ),
//         );

//         if (!wide) {
//           return Column(
//             children: [
//               Expanded(child: left),
//               const SizedBox(height: 12),
//               Expanded(child: right),
//             ],
//           );
//         }

//         return Row(
//           children: [
//             Expanded(child: left),
//             const SizedBox(width: 12),
//             Expanded(child: right),
//           ],
//         );
//       },
//     );
//   }

//   Future<void> _confirmReceiveItem({
//     required String rackId,
//     required String itemId,
//     required TextEditingController qtyCtrl,
//   }) async {
//     final qty = _tryInt(qtyCtrl);
//     if (qty == null || qty <= 0) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Enter valid quantity (>0)')),
//       );
//       return;
//     }

//     setState(() => _busy = true);
//     try {
//       final receivedBy = await _uid();
//       final ok = await ref
//           .read(storeReceiveControllerProvider)
//           .receiveItem(
//             itemId: itemId,
//             qty: qty,
//             receivedBy: receivedBy,
//             rackId: rackId,
//           );

//       if (!mounted) return;
//       if (ok) {
//         qtyCtrl.clear();
//         showSnackBar('Received successfully');
//       }
//     } finally {
//       if (mounted) setState(() => _busy = false);
//     }
//   }
// }

// /* ---------------- Small UI helpers ---------------- */

// class _Card extends StatelessWidget {
//   const _Card({required this.child, this.padding = const EdgeInsets.all(16)});
//   final Widget child;
//   final EdgeInsets padding;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: BoxDecoration(
//         color: _surface,
//         borderRadius: BorderRadius.circular(18),
//         border: Border.all(color: _stroke),
//         boxShadow: const [
//           BoxShadow(
//             color: Color(0x14000000),
//             blurRadius: 14,
//             offset: Offset(0, 6),
//           ),
//         ],
//       ),
//       child: Padding(padding: padding, child: child),
//     );
//   }
// }

// class _SectionTitle extends StatelessWidget {
//   const _SectionTitle(this.title, this.subtitle);
//   final String title;
//   final String subtitle;

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           title,
//           style: const TextStyle(
//             color: _ink900,
//             fontWeight: FontWeight.w900,
//             fontSize: 14,
//           ),
//         ),
//         const SizedBox(height: 2),
//         Text(
//           subtitle,
//           style: const TextStyle(
//             color: _ink600,
//             fontWeight: FontWeight.w700,
//             fontSize: 12,
//           ),
//         ),
//       ],
//     );
//   }
// }

// class _HintBar extends StatelessWidget {
//   const _HintBar({required this.text});
//   final String text;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
//       decoration: BoxDecoration(
//         color: _surfaceAlt.withOpacity(.7),
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: _stroke),
//       ),
//       child: Row(
//         children: [
//           Icon(Icons.info_outline_rounded, color: _ink600),
//           const SizedBox(width: 8),
//           Expanded(
//             child: Text(
//               text,
//               style: const TextStyle(
//                 color: _ink700,
//                 fontWeight: FontWeight.w700,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _InfoRow extends StatelessWidget {
//   const _InfoRow({required this.label, required this.value});
//   final String label;
//   final String value;

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 6),
//       child: Row(
//         children: [
//           Expanded(
//             child: Text(
//               label,
//               style: const TextStyle(
//                 color: _ink600,
//                 fontWeight: FontWeight.w800,
//               ),
//             ),
//           ),
//           Text(
//             value,
//             style: const TextStyle(color: _ink900, fontWeight: FontWeight.w900),
//           ),
//         ],
//       ),
//     );
//   }
// }
