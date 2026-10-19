import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../store_page/controllers/store_category_controller.dart';
import 'machine_form_view.dart';
// must expose: storeCategoryByItemissueProvider

/* ---------------- Theme Tokens ---------------- */
const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);
const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;

class MachineAddSotringJob extends ConsumerStatefulWidget {
  const MachineAddSotringJob({super.key});

  @override
  ConsumerState<MachineAddSotringJob> createState() =>
      _MachineAddSotringJobState();
}

class _MachineAddSotringJobState extends ConsumerState<MachineAddSotringJob> {
  @override
  Widget build(BuildContext context) {
    final categoryAsync = ref.watch(storeCategoryByItemissueProvider);

    return Scaffold(
      backgroundColor: _surface,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_bgTop, _bgBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: categoryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (e, st) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Error: $e',
                    style: const TextStyle(color: _ink900),
                  ),
                ),
              ),
          data: (categories) {
            // ✅ categories should be List (from API)
            final list = (categories as List?) ?? [];

            if (list.isEmpty) {
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(storeCategoryByItemissueProvider);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: const [
                    SizedBox(height: 160),
                    Center(
                      child: Text(
                        'No machine categories found.',
                        style: TextStyle(color: _ink700),
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(storeCategoryByItemissueProvider);
              },
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  // ✅ Category is Map (JSON)
                  final c = Map<String, dynamic>.from(list[index] as Map);

                  final name = (c['name'] ?? '').toString();
                  final code = (c['code'] ?? '').toString();

                  // ✅ items is List<dynamic>
                  final itemsRaw = (c['items'] as List?) ?? [];

                  return Container(
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _stroke),
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 14,
                          offset: Offset(0, 6),
                          color: Color(0x14000000),
                        ),
                      ],
                    ),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      iconColor: _ink900,
                      collapsedIconColor: _ink600,
                      title: Row(
                        children: [
                          const Icon(
                            Icons.precision_manufacturing_outlined,
                            color: _ink900,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              name.isEmpty ? '-' : name,
                              style: const TextStyle(
                                color: _ink900,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        code.isEmpty ? '-' : code,
                        style: const TextStyle(
                          color: _ink600,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      children: [
                        if (itemsRaw.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'No issued items in this category.',
                              style: TextStyle(color: _ink700),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: itemsRaw.length,
                            separatorBuilder:
                                (_, __) =>
                                    const Divider(height: 14, color: _stroke),
                            itemBuilder: (context, i) {
                              // ✅ Item is also Map (JSON) -> use ['key']
                              final it = Map<String, dynamic>.from(
                                itemsRaw[i] as Map,
                              );

                              final itemName =
                                  (it['itemName'] ?? '').toString();
                              final itemCode =
                                  (it['itemCode'] ?? '').toString();
                              final netIssued = it['netIssued'] ?? 0;

                              // optional
                              final issueNos =
                                  (it['issueNos'] as List? ?? [])
                                      .map((e) => e.toString())
                                      .toList();

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: _surfaceAlt,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: _stroke),
                                    ),
                                    child: const Icon(
                                      Icons.inventory_2_outlined,
                                      size: 18,
                                      color: _ink900,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          itemName.isEmpty ? '-' : itemName,
                                          style: const TextStyle(
                                            color: _ink900,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          itemCode.isEmpty
                                              ? 'Code: -'
                                              : 'Code: $itemCode',
                                          style: const TextStyle(
                                            color: _ink600,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        if (issueNos.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            'ISS: ${issueNos.join(", ")}',
                                            style: const TextStyle(
                                              color: _ink700,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _surfaceAlt,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: _stroke),
                                    ),
                                    child: Text(
                                      'Issued: $netIssued',
                                      style: const TextStyle(
                                        color: _ink900,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _ink900,
                              side: const BorderSide(color: _stroke),
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              backgroundColor: _surfaceAlt,
                            ),
                            onPressed: () async {
                              final cid =
                                  (c["categoryId"] ?? c["_id"] ?? "")
                                      .toString();
                              final cname = (c["name"] ?? "").toString();

                              // items is a List<Map> from backend (JsonMap), so access using ["key"]
                              final items = (c["items"] ?? []) as List;
                              final String? defaultItemId =
                                  items.isNotEmpty
                                      ? (items.first["id"] ??
                                              items.first["_id"])
                                          ?.toString()
                                      : null;

                              final created = await Navigator.of(
                                context,
                              ).push<bool>(
                                MaterialPageRoute(
                                  builder:
                                      (_) => MachineFormView(
                                        categoryId: cid,
                                        categoryName: cname,
                                        defaultItemId: defaultItemId,
                                      ),
                                ),
                              );

                              // ✅ refresh after create
                              if (created == true) {
                                ref.invalidate(
                                  storeCategoryByItemissueProvider,
                                );
                              }
                            },
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text(
                              'Create Machine For Sorting Job',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
