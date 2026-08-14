import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows installers keep binaries in 64-bit Program Files', () {
    final inno = File('installer/windows/sendreq.iss').readAsStringSync();
    expect(inno, contains(r'DefaultDirName={autopf}\sendreq'));
    expect(inno, contains('PrivilegesRequired=admin'));
    expect(inno, isNot(contains('PrivilegesRequired=lowest')));

    final wix = File('installer/windows/sendreq.wxs').readAsStringSync();
    expect(wix, contains('InstallScope="perMachine"'));
    expect(wix, contains('<Directory Id="ProgramFiles64Folder">'));
  });

  test('Isar workspace data uses the operating system user directory', () {
    final source = File(
      'lib/data/database/isar_workspace.dart',
    ).readAsStringSync();
    expect(source, contains('getApplicationSupportDirectory()'));
    expect(source, contains('directory: root.path'));
    expect(source, isNot(contains('Platform.resolvedExecutable')));
  });
}
