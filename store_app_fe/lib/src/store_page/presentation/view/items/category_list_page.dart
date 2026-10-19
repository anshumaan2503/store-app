import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../controllers/store_category_controller.dart';
import '../../../domains/models/store_category_model.dart';

const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);
const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;
const _accent = Color(0xFFF3D7C0);

class CategoryListPage extends ConsumerStatefulWidget {
  const CategoryListPage({super.key});

  @override
  ConsumerState<CategoryListPage> createState() => _CategoryListPageState();
}

class _CategoryListPageState extends ConsumerState<CategoryListPage> {
  String _q = '';
  int _limit = 50;

  CategoryPagedQuery get _query =>
      CategoryPagedQuery(page: 1, limit: _limit, search: _q, sort: 'name');

  void _refresh() {
    ref.invalidate(categoryPagedStreamProvider);
    setState(() => _limit = 50);
  }

  void _loadMore(CategoryPagedResult paged) {
    if (paged.rows.length >= paged.total) return;
    setState(() => _limit += 50);
  }

  Future<void> _openForm({StoreCategory? initial}) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CategoryFormPage(initial: initial)),
    );
    if (ok == true) _refresh();
  }

  String _label(StoreCategory c, Map<String, StoreCategory> byId) {
    if (c.parentId == null || c.parentId!.isEmpty) return c.name;
    final p = byId[c.parentId!];
    return p == null ? c.name : '${p.name} > ${c.name}';
  }

  @override
  Widget build(BuildContext context) {
    final av = ref.watch(categoryPagedStreamProvider(_query));

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: _ink900),
        title: const Text(
          'Categories',
          style: TextStyle(color: _ink900, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_bgTop, _bgBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              children: [
                _Card(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  child: TextField(
                    onChanged:
                        (v) => setState(() {
                          _q = v.trim();
                          _limit = 50;
                        }),
                    decoration: const InputDecoration(
                      hintText: 'Search category...',
                      prefixIcon: Icon(Icons.search_rounded, color: _ink600),
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(
                      color: _ink900,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: av.when(
                    loading:
                        () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (paged) {
                      final rows = paged.rows;
                      final byId = {for (final c in rows) c.id: c};

                      if (rows.isEmpty) {
                        return const Center(child: Text('No categories found'));
                      }

                      final canLoadMore = rows.length < paged.total;

                      return Column(
                        children: [
                          Expanded(
                            child: ListView.separated(
                              itemCount: rows.length,
                              separatorBuilder:
                                  (_, __) => const SizedBox(height: 10),
                              itemBuilder: (_, i) {
                                final c = rows[i];
                                final isChild =
                                    c.parentId != null &&
                                    c.parentId!.isNotEmpty;

                                return _Card(
                                  child: ListTile(
                                    leading: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: _accent.withValues(alpha: .55),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: _stroke),
                                      ),
                                      child: Icon(
                                        isChild
                                            ? Icons
                                                .subdirectory_arrow_right_rounded
                                            : Icons.category_rounded,
                                        color: _ink900,
                                      ),
                                    ),
                                    title: Text(
                                      _label(c, byId),
                                      style: const TextStyle(
                                        color: _ink900,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${c.code}${c.remark.isNotEmpty ? " • ${c.remark}" : ""}',
                                      style: const TextStyle(
                                        color: _ink700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    trailing: Wrap(
                                      spacing: 6,
                                      children: [
                                        IconButton(
                                          tooltip: 'Edit',
                                          onPressed:
                                              () => _openForm(initial: c),
                                          icon: const Icon(
                                            Icons.edit_rounded,
                                            color: _ink700,
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Delete',
                                          onPressed: () async {
                                            final yes = await showDialog<bool>(
                                              context: context,
                                              builder:
                                                  (_) => AlertDialog(
                                                    title: const Text(
                                                      'Delete?',
                                                    ),
                                                    content: Text(
                                                      'Delete "${_label(c, byId)}"?',
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed:
                                                            () => Navigator.pop(
                                                              context,
                                                              false,
                                                            ),
                                                        child: const Text(
                                                          'Cancel',
                                                        ),
                                                      ),
                                                      FilledButton(
                                                        onPressed:
                                                            () => Navigator.pop(
                                                              context,
                                                              true,
                                                            ),
                                                        child: const Text(
                                                          'Delete',
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                            );

                                            if (yes != true) return;

                                            final ok = await ref
                                                .read(
                                                  storeCategoryControllerProvider,
                                                )
                                                .deleteCategory(c.id);

                                            if (!mounted) return;

                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  ok
                                                      ? 'Deleted'
                                                      : 'Delete failed',
                                                ),
                                              ),
                                            );

                                            if (ok) _refresh();
                                          },
                                          icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 10),
                          _Card(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Showing ${rows.length} of ${paged.total}',
                                    style: const TextStyle(
                                      color: _ink700,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (canLoadMore)
                                  FilledButton.icon(
                                    onPressed: () => _loadMore(paged),
                                    icon: const Icon(Icons.expand_more_rounded),
                                    label: const Text('Load more'),
                                  ),
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
    );
  }
}

class CategoryFormPage extends ConsumerStatefulWidget {
  const CategoryFormPage({super.key, this.initial});
  final StoreCategory? initial;

  @override
  ConsumerState<CategoryFormPage> createState() => _CategoryFormPageState();
}

class _CategoryFormPageState extends ConsumerState<CategoryFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.initial?.name ?? '',
  );
  late final TextEditingController _remark = TextEditingController(
    text: widget.initial?.remark ?? '',
  );

  StoreCategory? _parent;
  bool _busy = false;

  CategoryPagedQuery get _catQuery =>
      const CategoryPagedQuery(page: 1, limit: 800, search: '', sort: 'name');

  @override
  void dispose() {
    _name.dispose();
    _remark.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final isEdit = widget.initial != null;

    final dto = <String, dynamic>{
      "name": _name.text.trim(),
      "remark": _remark.text.trim(),
      "parentId": _parent?.id, // null => parent category
    };

    setState(() => _busy = true);
    try {
      final ok =
          isEdit
              ? await ref
                  .read(storeCategoryControllerProvider)
                  .updateCategory(id: widget.initial!.id, dto: dto)
              : (await ref
                      .read(storeCategoryControllerProvider)
                      .createCategory(dto: dto)) !=
                  null;

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? (isEdit ? 'Updated' : 'Created') : 'Failed'),
        ),
      );

      if (ok) {
        ref.invalidate(categoryPagedStreamProvider);
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    final catsAv = ref.watch(categoryPagedStreamProvider(_catQuery));

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: _ink900),
        title: Text(
          isEdit ? 'Edit Category' : 'Create Category',
          style: const TextStyle(color: _ink900, fontWeight: FontWeight.w900),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_bgTop, _bgBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: _Card(
                  padding: const EdgeInsets.all(18),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        catsAv.when(
                          loading:
                              () => const LinearProgressIndicator(minHeight: 2),
                          error: (e, _) => Text('Load error: $e'),
                          data: (paged) {
                            final parents =
                                paged.rows
                                    .where(
                                      (c) =>
                                          c.parentId == null ||
                                          c.parentId!.isEmpty,
                                    )
                                    .toList()
                                  ..sort((a, b) => a.name.compareTo(b.name));

                            if (isEdit &&
                                widget.initial!.parentId != null &&
                                _parent == null) {
                              final hit =
                                  parents
                                      .where(
                                        (x) => x.id == widget.initial!.parentId,
                                      )
                                      .toList();
                              if (hit.isNotEmpty) _parent = hit.first;
                            }

                            return DropdownButtonFormField<StoreCategory?>(
                              initialValue: _parent,
                              isExpanded: true,
                              items: [
                                const DropdownMenuItem<StoreCategory?>(
                                  value: null,
                                  child: Text('None (Category)'),
                                ),
                                for (final p in parents)
                                  DropdownMenuItem(
                                    value: p,
                                    child: Text(p.name),
                                  ),
                              ],
                              onChanged: (v) => setState(() => _parent = v),
                              decoration: InputDecoration(
                                labelText: 'Parent (optional)',
                                prefixIcon: const Icon(
                                  Icons.account_tree_rounded,
                                ),
                                filled: true,
                                fillColor: _surfaceAlt.withValues(alpha: .55),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _Field(
                          controller: _name,
                          label: 'Name *',
                          hint: 'e.g., Electrical',
                          icon: Icons.category_rounded,
                          validator:
                              (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Required'
                                      : null,
                        ),
                        const SizedBox(height: 12),
                        _Field(
                          controller: _remark,
                          label: 'Remark',
                          hint: 'Optional',
                          icon: Icons.notes_rounded,
                          maxLines: 2,
                          validator: (v) => null,
                        ),
                        const SizedBox(height: 18),
                        _PrimaryBtn(
                          label:
                              _busy
                                  ? 'Saving...'
                                  : (isEdit
                                      ? 'Save Changes'
                                      : 'Create Category'),
                          busy: _busy,
                          onTap: _busy ? null : _save,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ---- shared widgets (same style) ---- */

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _stroke),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.validator,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? Function(String?) validator;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: _ink900, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _ink600),
            prefixIcon: Icon(icon, color: _ink600),
            filled: true,
            fillColor: _surfaceAlt.withValues(alpha: 0.55),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _stroke),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _stroke),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _ink900, width: 1.2),
            ),
          ),
          style: const TextStyle(color: _ink900, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  const _PrimaryBtn({
    required this.label,
    required this.onTap,
    required this.busy,
  });
  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _ink900,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _surface,
                  ),
                )
              else
                const Icon(Icons.save_rounded, size: 18, color: _surface),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: _surface,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
