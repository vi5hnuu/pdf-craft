import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_craft/tools/tool_registry.dart';

/// Every tool in the registry must have a route the router can actually build.
///
/// The registry is the single source of truth for the catalogue, but the router is a separate
/// file: adding a `ToolDef` without its `GoRoute` compiles fine and fails only when a user taps
/// the tile, with GoRouter's "no routes for location" error. That is exactly the failure the
/// six new inspector tools could have shipped with.
///
/// The router is parsed as text rather than driven, because building it needs a full widget
/// tree, a bloc and platform channels — this catches the omission at the speed of a unit test.
void main() {
  final router = File('lib/routes/app_router.dart').readAsStringSync();
  final routes = File('lib/routes.dart').readAsStringSync();

  test('every registry tool points at a route that exists in AppRoutes', () {
    final declared = RegExp(r'static AppRoute (\w+)\s*=')
        .allMatches(routes)
        .map((m) => m.group(1)!)
        .toSet();

    final missing = <String>[];
    for (final tool in ToolRegistry.tools) {
      // ToolDef.route is the AppRoute instance; compare by its unique name/path pair.
      final named = declared.where((d) => routes.contains("$d=AppRoute(name: '${tool.route.name}'"));
      if (named.isEmpty) missing.add('${tool.id} -> ${tool.route.name}');
    }
    expect(missing, isEmpty, reason: 'tools whose AppRoute is not declared: $missing');
  });

  test('every registry tool has a GoRoute registered in the router', () {
    final missing = <String>[];
    for (final tool in ToolRegistry.tools) {
      // Each GoRoute names itself via `AppRoutes.<x>.name`; the path line proves the route was
      // registered rather than merely declared.
      if (!router.contains('AppRoutes.${_fieldFor(routes, tool.route.name)}.name')) {
        missing.add('${tool.id} -> ${tool.route.name}');
      }
    }
    expect(missing, isEmpty, reason: 'tools with no GoRoute: $missing');
  });

  test('a retired tool id still resolves to the tool that replaced it', () {
    // Favourites and recents are persisted as bare id strings, so retiring a tool by deleting
    // its ToolDef silently drops whatever the user had pinned against it. 'reorder' merged into
    // 'organize' — both posted the same request to the same endpoint.
    expect(ToolRegistry.byId('reorder')?.id, 'organize');
    expect(ToolRegistry.resolveId('reorder'), 'organize');
    // An id that was never retired passes through untouched.
    expect(ToolRegistry.resolveId('merge'), 'merge');
    expect(ToolRegistry.byId('not-a-tool'), isNull);
  });

  test('a retired id resolves to exactly one live tool, so it cannot be listed twice', () {
    // Favourites and recents are stored as bare ids. If both the retired id and its replacement
    // are stored — easy, since using the replacement records it — a list that resolves ids has
    // to de-duplicate or the tool appears twice.
    final resolved = ['reorder', 'organize'].map(ToolRegistry.resolveId).toSet();
    expect(resolved, {'organize'});
  });

  test('no two tools share an id', () {
    final ids = ToolRegistry.tools.map((t) => t.id).toList();
    expect(ids.length, ids.toSet().length,
        reason: 'ids are persisted for favourites and recents, so a duplicate silently merges two tools');
  });
}

/// The `AppRoutes` field name for a route with the given route name.
String _fieldFor(String routes, String routeName) {
  final m = RegExp("static AppRoute (\\w+)\\s*=\\s*AppRoute\\(name: '$routeName'").firstMatch(routes);
  return m?.group(1) ?? '<unknown:$routeName>';
}
