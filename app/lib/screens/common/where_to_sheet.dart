import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n.dart';
import '../../core/places.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

/// "Where to?" search. Returns the chosen [Place] or null.
Future<Place?> showWhereTo(BuildContext context, {String? titleKey}) {
  return showModalBottomSheet<Place>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => WhereToSheet(titleKey: titleKey ?? 'where_to'),
  );
}

class WhereToSheet extends StatefulWidget {
  const WhereToSheet({super.key, required this.titleKey});

  final String titleKey;

  @override
  State<WhereToSheet> createState() => _WhereToSheetState();
}

class _WhereToSheetState extends State<WhereToSheet> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<Place>? _results;
  bool _searching = false;
  int _searchId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _results = null);
      return;
    }
    setState(() => _results = AlbanianPlaces.search(q));
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final id = ++_searchId;
      setState(() => _searching = true);
      final res = await context.read<AppState>().geocoding.search(q);
      if (!mounted || id != _searchId) return;
      setState(() {
        _results = res;
        _searching = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final results = _results;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: EdgeInsets.fromLTRB(
          20,
          10,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            context.tr(widget.titleKey),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _query,
            autofocus: true,
            onChanged: _onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: context.tr('search_place'),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 14),
          if (results == null) ...[
            CardBox(
              color: AppColors.primarySoft,
              onTap: () => Navigator.pop(
                context,
                app.herePlace ??
                    Place(context.tr('current_location'), '', app.here),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.my_location_rounded, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('use_current_location'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          app.herePlace?.name ?? context.tr('locating'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (app.homePlace != null || app.workPlace != null) ...[
              SectionLabel(context.tr('saved_places')),
              if (app.homePlace != null)
                _PlaceTile(
                  place: app.homePlace!,
                  icon: Icons.home_rounded,
                  title: context.tr('home_place'),
                ),
              if (app.workPlace != null)
                _PlaceTile(
                  place: app.workPlace!,
                  icon: Icons.work_rounded,
                  title: context.tr('work_place'),
                ),
            ],
            if (app.recents.isNotEmpty) ...[
              SectionLabel(context.tr('recent')),
              for (final p in app.recents)
                _PlaceTile(place: p, icon: Icons.history_rounded),
            ],
            SectionLabel(context.tr('suggested')),
            for (final p in AlbanianPlaces.suggested)
              _PlaceTile(place: p, icon: Icons.place_outlined),
          ] else if (results.isEmpty && !_searching)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  context.tr('no_results'),
                  style: const TextStyle(color: AppColors.inkSoft),
                ),
              ),
            )
          else
            for (final p in results)
              _PlaceTile(place: p, icon: Icons.place_outlined),
        ],
      ),
    );
  }
}

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({required this.place, required this.icon, this.title});

  final Place place;
  final IconData icon;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CardBox(
        onTap: () => Navigator.pop(context, place),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.surfaceHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: AppColors.inkSoft),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title ?? place.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    title != null ? place.name : place.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
          ],
        ),
      ),
    );
  }
}
