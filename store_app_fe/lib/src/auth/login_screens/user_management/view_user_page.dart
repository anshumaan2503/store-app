// users_list_page.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/socket_manager.dart';
import '../../../components/utils.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/users_controller.dart';
import '../../domains/models/auth_model.dart';
import '../../shared/repositories/shared_preference_repository.dart';
import 'add_user_page.dart';
import 'edit_user_page.dart';

/* =================== Palette (shared with Edit page) =================== */
const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);

const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);

const _accentMint = Color(0xFFB6D3CC);
const _accentPeach = Color(0xFFF3D7C0);

const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;

/* ------------ Query & Paged DTO (unchanged) ------------ */

enum UserSearchField { all, name, email, phone }

class UserQuery {
  final int page;
  final int limit;
  final String sort; // "-createdAt", "createdAt", "name", "-name"
  final String q; // search text
  final UserSearchField field;

  const UserQuery({
    required this.page,
    required this.limit,
    required this.sort,
    required this.q,
    required this.field,
  });

  UserQuery copyWith({
    int? page,
    int? limit,
    String? sort,
    String? q,
    UserSearchField? field,
  }) {
    return UserQuery(
      page: page ?? this.page,
      limit: limit ?? this.limit,
      sort: sort ?? this.sort,
      q: q ?? this.q,
      field: field ?? this.field,
    );
  }

  Map<String, dynamic> toJson() => {
    "page": page,
    "limit": limit,
    "sort": sort,
    "q": q.trim(),
    "field": switch (field) {
      UserSearchField.name => "name",
      UserSearchField.email => "email",
      UserSearchField.phone => "phone",
      _ => "all",
    },
  };
}

class PagedUsers {
  final List<AuthModel> rows;
  final int total;
  final int page;
  final int limit;
  const PagedUsers({
    required this.rows,
    required this.total,
    required this.page,
    required this.limit,
  });
}

/* ------------ Stream provider using socket (unchanged) ------------ */

final usersPagedProvider = StreamProvider.autoDispose
    .family<PagedUsers, UserQuery>((ref, q) async* {
      final socketManager = ref.watch(socketProvider);
      socketManager.initAuthConnection(ref);
      final socket = socketManager.getSocket();
      final ctrl = StreamController<PagedUsers>(sync: true);

      void handler(dynamic data) {
        try {
          final rawRows =
              (data is Map && data['rows'] is List)
                  ? data['rows'] as List
                  : const <dynamic>[];

          final list =
              rawRows.map<AuthModel>((row) {
                final m = Map<String, dynamic>.from(row as Map);

                // normalize
                m['uid'] ??= (m['_id'] ?? '').toString();
                m['id'] ??= m['uid'];
                m['name'] = (m['name'] ?? '').toString();
                m['email'] = (m['email'] ?? '').toString();
                m['phoneNumber'] = (m['phoneNumber'] ?? '').toString();
                if (m['createdAt'] != null) {
                  m['createdAt'] = m['createdAt'].toString();
                }

                return AuthModel.fromMap(m);
              }).toList();

          final total = (data['total'] ?? 0) as int;
          final page = (data['page'] ?? q.page) as int;
          final limit = (data['limit'] ?? q.limit) as int;

          ctrl.add(
            PagedUsers(rows: list, total: total, page: page, limit: limit),
          );
        } catch (e, st) {
          debugPrint('usersPagedProvider map error: $e\n$st');
          ctrl.add(
            PagedUsers(rows: const [], total: 0, page: q.page, limit: q.limit),
          );
        }
      }

      socket.on("auth:listUsersPaged", handler);
      if (!socket.connected) socket.connect();
      socket.emit("auth:listUsersPaged", q.toJson());

      ref.onDispose(() {
        socket.off("auth:listUsersPaged", handler);
        ctrl.close();
      });

      // skeleton
      yield PagedUsers(rows: const [], total: 0, page: q.page, limit: q.limit);
      await for (final v in ctrl.stream) {
        yield v;
      }
    });

/* ------------ Page (new clean card UI) ------------ */

class UsersListPage extends ConsumerStatefulWidget {
  const UsersListPage({super.key});

  @override
  ConsumerState<UsersListPage> createState() => _UsersListPageState();
}

class _UsersListPageState extends ConsumerState<UsersListPage> {
  UserQuery _q = const UserQuery(
    page: 1,
    limit: 12,
    sort: '-createdAt',
    q: '',
    field: UserSearchField.all,
  );

  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  static const double _pagerHeight = 64;

  static const _cardColors = <Color>[
    Color(0xFF6C5CE7),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFE11D48),
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFF14B8A6),
    Color(0xFFF97316),
    Color(0xFFEC4899),
    Color(0xFF22C55E),
  ];

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = _q.q;
    _searchCtrl.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), () {
        setState(() => _q = _q.copyWith(page: 1, q: _searchCtrl.text));
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.refresh(usersPagedProvider(_q));
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<_FilterResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (_) => _FilterSheet(
            initial: _FilterResult(
              field: _q.field,
              limit: _q.limit,
              sort: _q.sort,
            ),
          ),
    );
    if (result != null) {
      setState(() {
        _q = _q.copyWith(
          page: 1,
          field: result.field,
          limit: result.limit,
          sort: result.sort,
        );
      });
    }
  }

  void _resetFilters() {
    _searchCtrl.text = '';
    setState(() {
      _q = const UserQuery(
        page: 1,
        limit: 12,
        sort: '-createdAt',
        q: '',
        field: UserSearchField.all,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final pagedAsync = ref.watch(usersPagedProvider(_q));

    return Scaffold(
      backgroundColor: _bgBottom,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _surface,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _ink900),
          onPressed: () => Navigator.maybePop(context),
          tooltip: 'Back',
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.groups_rounded, color: _ink900),
            SizedBox(width: 8),
            Text(
              'Users',
              style: TextStyle(color: _ink900, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'addUserFab',
        onPressed: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const UserAddPage()));
        },
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add User'),
        backgroundColor: _ink900,
        foregroundColor: _surface,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgBottom],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      child: _SearchBar(
                        controller: _searchCtrl,
                        hint: switch (_q.field) {
                          UserSearchField.name => 'Search by name',
                          UserSearchField.email => 'Search by email',
                          UserSearchField.phone => 'Search by phone',
                          _ => 'Search name / email / phone',
                        },
                        onFilterTap: _openFilterSheet,
                        onReset: _resetFilters,
                      ),
                    ),
                  ),
                  pagedAsync.when(
                    loading:
                        () => const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                    error:
                        (e, _) => SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Error: $e',
                              style: const TextStyle(color: _ink900),
                            ),
                          ),
                        ),
                    data: (pg) {
                      if (pg.rows.isEmpty) {
                        return SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            12,
                            8,
                            12,
                            12 + _pagerHeight,
                          ),
                          sliver: const SliverToBoxAdapter(
                            child: _EmptyState(),
                          ),
                        );
                      }
                      return SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          12,
                          8,
                          12,
                          12 + _pagerHeight,
                        ),
                        sliver: SliverList.separated(
                          itemCount: pg.rows.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final u = pg.rows[i];
                            final tint = _cardColors[i % _cardColors.length];
                            return _UserCard(user: u, tint: tint);
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: pagedAsync.maybeWhen(
                    data:
                        (pg) => _PagerBar(
                          height: _pagerHeight,
                          total: pg.total,
                          pageSize: pg.limit,
                          pageIndex: pg.page,
                          onPrev:
                              pg.page > 1
                                  ? () => setState(
                                    () => _q = _q.copyWith(page: pg.page - 1),
                                  )
                                  : null,
                          onNext:
                              (pg.page * pg.limit < pg.total)
                                  ? () => setState(
                                    () => _q = _q.copyWith(page: pg.page + 1),
                                  )
                                  : null,
                          onJump:
                              (p) => setState(() => _q = _q.copyWith(page: p)),
                        ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ------------ Search Bar (card) ------------ */

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.hint,
    required this.onFilterTap,
    required this.onReset,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onFilterTap;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return _Card(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 44,
              child: TextField(
                controller: controller,
                style: const TextStyle(
                  color: _ink900,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: hint,
                  hintStyle: const TextStyle(color: _ink600),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: _ink600,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: _surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _stroke),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _stroke),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _ink900, width: 1.2),
                  ),
                  suffixIcon:
                      controller.text.isNotEmpty
                          ? IconButton(
                            tooltip: 'Clear',
                            icon: const Icon(
                              Icons.close_rounded,
                              color: _ink600,
                              size: 18,
                            ),
                            onPressed: () => controller.clear(),
                          )
                          : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _SmallBtn(
            icon: Icons.tune_rounded,
            label: 'Filter',
            onTap: onFilterTap,
          ),
          const SizedBox(width: 8),
          _SmallBtn(
            icon: Icons.restart_alt_rounded,
            label: 'Reset',
            onTap: onReset,
          ),
        ],
      ),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  const _SmallBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: _stroke),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 16, color: _ink700),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: _ink900,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ------------ Filter sheet (white, rounded) ------------ */

class _FilterResult {
  final UserSearchField field;
  final int limit;
  final String sort;
  const _FilterResult({
    required this.field,
    required this.limit,
    required this.sort,
  });

  _FilterResult copyWith({UserSearchField? field, int? limit, String? sort}) =>
      _FilterResult(
        field: field ?? this.field,
        limit: limit ?? this.limit,
        sort: sort ?? this.sort,
      );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial});
  final _FilterResult initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late _FilterResult _v;

  @override
  void initState() {
    super.initState();
    _v = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.45,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      builder: (ctx, scroll) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(
              color: _surface,
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _stroke,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Filters',
                    style: TextStyle(
                      color: _ink900,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text(
                    'Field',
                    style: TextStyle(
                      color: _ink600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _pill(
                        UserSearchField.all,
                        'All',
                        Icons.all_inclusive_rounded,
                      ),
                      _pill(UserSearchField.name, 'Name', Icons.badge_rounded),
                      _pill(
                        UserSearchField.email,
                        'Email',
                        Icons.alternate_email_rounded,
                      ),
                      _pill(
                        UserSearchField.phone,
                        'Phone',
                        Icons.phone_iphone_rounded,
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),
                  const Text(
                    'Page size',
                    style: TextStyle(
                      color: _ink600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children:
                        [8, 12, 20, 32].map((n) {
                          final selected = _v.limit == n;
                          return ChoiceChip(
                            label: Text('$n'),
                            selected: selected,
                            onSelected:
                                (_) =>
                                    setState(() => _v = _v.copyWith(limit: n)),
                            selectedColor: _accentMint,
                            backgroundColor: _surface,
                            labelStyle: TextStyle(
                              color: _ink900,
                              fontWeight:
                                  selected ? FontWeight.w800 : FontWeight.w600,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                              side: const BorderSide(color: _stroke),
                            ),
                          );
                        }).toList(),
                  ),

                  const SizedBox(height: 14),
                  const Text(
                    'Sort',
                    style: TextStyle(
                      color: _ink600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _SortChip(
                        value: '-createdAt',
                        label: 'Newest',
                        selected: _v.sort == '-createdAt',
                        onTap:
                            () => setState(
                              () => _v = _v.copyWith(sort: '-createdAt'),
                            ),
                      ),
                      _SortChip(
                        value: 'createdAt',
                        label: 'Oldest',
                        selected: _v.sort == 'createdAt',
                        onTap:
                            () => setState(
                              () => _v = _v.copyWith(sort: 'createdAt'),
                            ),
                      ),
                      _SortChip(
                        value: 'name',
                        label: 'Name ↑',
                        selected: _v.sort == 'name',
                        onTap:
                            () =>
                                setState(() => _v = _v.copyWith(sort: 'name')),
                      ),
                      _SortChip(
                        value: '-name',
                        label: 'Name ↓',
                        selected: _v.sort == '-name',
                        onTap:
                            () =>
                                setState(() => _v = _v.copyWith(sort: '-name')),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionBtn(
                          icon: Icons.check_rounded,
                          label: 'Apply',
                          onTap: () => Navigator.pop(context, _v),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionBtn(
                          icon: Icons.close_rounded,
                          label: 'Cancel',
                          onTap: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _pill(UserSearchField f, String label, IconData icon) {
    final selected = _v.field == f;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 16), const SizedBox(width: 6), Text(label)],
      ),
      selected: selected,
      onSelected: (_) => setState(() => _v = _v.copyWith(field: f)),
      selectedColor: _accentPeach,
      backgroundColor: _surface,
      labelStyle: TextStyle(
        color: _ink900,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: const BorderSide(color: _stroke),
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.value,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String value;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: _accentPeach,
      backgroundColor: _surface,
      labelStyle: TextStyle(
        color: _ink900,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: const BorderSide(color: _stroke),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _stroke),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: _ink900),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: _ink900,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ------------ Pager (bottom card) ------------ */

class _PagerBar extends StatelessWidget {
  const _PagerBar({
    required this.height,
    required this.total,
    required this.pageSize,
    required this.pageIndex,
    required this.onPrev,
    required this.onNext,
    required this.onJump,
  });

  final double height;
  final int total;
  final int pageSize;
  final int pageIndex; // 1-based
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final ValueChanged<int> onJump;

  @override
  Widget build(BuildContext context) {
    final pages = total == 0 ? 1 : ((total - 1) / pageSize).floor() + 1;

    return _Card(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            IconButton(
              tooltip: 'Previous',
              onPressed: onPrev,
              icon: const Icon(Icons.chevron_left_rounded, color: _ink900),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(pages, (i) {
                    final idx = i + 1;
                    final selected = idx == pageIndex;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: ChoiceChip(
                        label: Text('$idx'),
                        selected: selected,
                        onSelected: (_) => onJump(idx),
                        selectedColor: _accentMint,
                        backgroundColor: _surface,
                        labelStyle: TextStyle(
                          color: _ink900,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                          side: const BorderSide(color: _stroke),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Next',
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right_rounded, color: _ink900),
            ),
          ],
        ),
      ),
    );
  }
}

/* =================== Card & helpers =================== */

class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 16,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(radius),
        border:
            null, // ignore (workaround: we’ll set border below)
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/* =================== User Card =================== */

class _UserCard extends ConsumerWidget {
  const _UserCard({required this.user, required this.tint});
  final AuthModel user;
  final Color tint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(usersControllerProvider);

    Future<void> delete() async {} // (kept: delete handled inside menu flow)

    return _Card(
      radius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              _TintAvatar(name: user.name, tint: tint),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (user.name.isNotEmpty ? user.name : 'Unnamed'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: _ink900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.mail_outline_rounded,
                          size: 16,
                          color: _ink600,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            user.email,
                            style: const TextStyle(color: _ink700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.phone_android_rounded,
                          size: 16,
                          color: _ink600,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            user.phoneNumber,
                            style: const TextStyle(color: _ink700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _StatusPill(
                            icon:
                                user.isActive
                                    ? Icons.check_circle
                                    : Icons.pause_circle_filled,
                            label: user.isActive ? 'Active' : 'Inactive',
                            fg:
                                user.isActive
                                    ? const Color(0xFF155724)
                                    : const Color(0xFF7E4E00),
                            bg:
                                user.isActive
                                    ? const Color(0xFFD4EDDA)
                                    : const Color(0xFFFFF1CD),
                            border:
                                user.isActive
                                    ? const Color(0xFFB7E4C7)
                                    : const Color(0xFFF1DEB0),
                          ),
                          _StatusPill(
                            icon:
                                user.isSuperAdmin
                                    ? Icons.security_rounded
                                    : Icons.person_outline_rounded,
                            label:
                                user.isSuperAdmin ? 'Super Admin' : 'Standard',
                            fg: user.isSuperAdmin ? _ink900 : _ink700,
                            bg: user.isSuperAdmin ? _accentPeach : _surfaceAlt,
                            border: _stroke,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _UserMenu(
                onEdit: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => UserEditPage(
                            initial: user,
                            currentViewerIsAdmin: true,
                            isEditingSelf: false,
                          ),
                    ),
                  );
                },
                onDelete: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) {
                      bool working = false;
                      return StatefulBuilder(
                        builder:
                            (ctx, setState) => AlertDialog(
                              title: const Text('Delete user?'),
                              content: Text(
                                'Are you sure you want to delete ${user.name}?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed:
                                      working
                                          ? null
                                          : () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton.tonal(
                                  onPressed:
                                      working
                                          ? null
                                          : () async {
                                            var checkId = await ref
                                                .read(spRepositoryProvider)
                                                .getStringValue("uid");
                                            if (user.uid == checkId) {
                                              showSnackBar(
                                                "You Can't Delete Your Own Profile",
                                              );
                                            } else {
                                              setState(() => working = true);
                                              final ok = await ref
                                                  .read(authControllerProvider)
                                                  .deleteUser(
                                                    authModel: {
                                                      "userId": user.uid,
                                                    },
                                                  );

                                              if (ok == true) {
                                                if (ctx.mounted) {
                                                  Navigator.pop(ctx, true);
                                                }
                                              } else {
                                                setState(() => working = false);
                                                if (ctx.mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Delete failed',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              }
                                            }
                                          },
                                  style: FilledButton.styleFrom(
                                    foregroundColor: Colors.red.shade700,
                                  ),
                                  child:
                                      working
                                          ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                          : const Text('Delete'),
                                ),
                              ],
                            ),
                      );
                    },
                  );

                  if (confirmed == true && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Deleted ${user.name}')),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserMenu extends StatelessWidget {
  const _UserMenu({required this.onEdit, required this.onDelete});
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (v) {
        if (v == 'edit') onEdit();
        if (v == 'delete') onDelete();
      },
      itemBuilder:
          (context) => const [
            PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit_rounded),
                title: Text('Edit'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: Colors.red),
                title: Text('Delete'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _stroke),
        ),
        child: const Icon(Icons.more_horiz_rounded, color: _ink900),
      ),
    );
  }
}

/* =================== Small pieces =================== */

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _surfaceAlt,
              ),
              child: const Icon(
                Icons.groups_2_rounded,
                size: 40,
                color: _ink900,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'No users found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _ink900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap “Add User” to create your first user.',
              style: TextStyle(color: _ink700.withValues(alpha: .9)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.fg,
    required this.bg,
    required this.border,
  });
  final IconData icon;
  final String label;
  final Color fg;
  final Color bg;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: .2,
            ),
          ),
        ],
      ),
    );
  }
}

class _TintAvatar extends StatelessWidget {
  const _TintAvatar({required this.name, required this.tint});
  final String name;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final initial =
        (name.trim().isNotEmpty ? name.trim()[0] : '?').toUpperCase();
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [tint.withValues(alpha: .85), tint.withValues(alpha: .55)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: tint.withValues(alpha: .20),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: _stroke),
        color: _surface,
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: _surface,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}
