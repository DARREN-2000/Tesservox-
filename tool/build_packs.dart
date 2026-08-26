// This is a build tool, so printing is the entire point.
// ignore_for_file: avoid_print

import 'dart:io';

import 'pack_compiler.dart';

/// Compiles `packs/*.yaml` into the JSON assets the app ships.
///
///     dart run tool/build_packs.dart            write assets/packs/
///     dart run tool/build_packs.dart --check    fail if they are stale
///
/// `--check` is the CI drift gate. Because the output is deterministic (sorted
/// keys, no build timestamp), "the committed assets match their sources" is
/// something the build enforces rather than something a README promises.
void main(List<String> args) {
  final List<String> unknown =
      args.where((String a) => a != '--check').toList();
  if (unknown.isNotEmpty) {
    stderr.writeln('unknown argument(s): ${unknown.join(", ")}');
    stderr.writeln('usage: dart run tool/build_packs.dart [--check]');
    exitCode = 64;
    return;
  }

  final bool check = args.contains('--check');
  final PackCompiler compiler = PackCompiler(packsDir: Directory('packs'));
  const String outDir = 'assets/packs';

  try {
    final List<CompiledPack> packs = compiler.compileAll();

    final Map<String, String> files = <String, String>{
      for (final CompiledPack pack in packs)
        '$outDir/${pack.locale}.json': pack.json,
      '$outDir/manifest.json': compiler.manifestJson(packs),
    };

    if (check) {
      final List<String> drift = <String>[];
      for (final MapEntry<String, String> entry in files.entries) {
        final File file = File(entry.key);
        if (!file.existsSync()) {
          drift.add('${entry.key} has not been generated');
        } else if (file.readAsStringSync() != entry.value) {
          drift.add('${entry.key} does not match packs/');
        }
      }

      if (drift.isNotEmpty) {
        stderr.writeln('Compiled vocabulary is out of date:\n');
        for (final String line in drift) {
          stderr.writeln('  - $line');
        }
        stderr.writeln('\nRun: dart run tool/build_packs.dart');
        exitCode = 1;
        return;
      }

      print('Vocabulary assets are up to date (${packs.length} locales).');
      return;
    }

    Directory(outDir).createSync(recursive: true);
    for (final MapEntry<String, String> entry in files.entries) {
      File(entry.key).writeAsStringSync(entry.value);
    }

    for (final CompiledPack pack in packs) {
      print(
        '${pack.locale.padRight(4)} ${pack.tileCount} tiles  ${pack.name}',
      );
    }
    print('Wrote ${files.length} files to $outDir/');
  } on PackError catch (error) {
    // Authoring mistakes get a readable report, not a Dart stack trace. The
    // person who hits this is usually a translator, not a Dart developer.
    stderr.writeln('\nPack error\n----------\n$error\n');
    exitCode = 1;
  }
}
