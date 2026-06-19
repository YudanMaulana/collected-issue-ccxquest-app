import 'package:collected_issues/models/issue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Issue buildIssue({
    String? evide,
    String tagDetail = 'Display',
    String penyebab = 'Kabel longgar',
    String penanganan = 'Dikencangkan',
  }) {
    return Issue(
      tgl: DateTime(2026, 6, 19),
      area: 'Tunnel',
      kategori: 'SISTEM',
      issue: 'Monitor blank',
      penanganan: penanganan,
      status: 'pending',
      perulanganMasalah: 1,
      penyebab: penyebab,
      evide: evide,
      tagDetail: tagDetail,
    );
  }

  test('No Need Eviden does not count as missing evidence', () {
    final issue = buildIssue(evide: Issue.noNeedEvidenValue);

    expect(issue.isNoNeedEviden, isTrue);
    expect(issue.hasEvidence, isTrue);
    expect(issue.missingFields, isEmpty);
    expect(issue.isIncomplete, isFalse);
  });

  test('Empty evidence is still incomplete when evidence is required', () {
    final issue = buildIssue(evide: null);

    expect(issue.hasEvidence, isFalse);
    expect(issue.missingFields, contains('Eviden'));
    expect(issue.isIncomplete, isTrue);
  });

  test('No Need Eviden is not treated as uploadable local file', () {
    final issue = buildIssue(evide: Issue.noNeedEvidenValue);

    expect(issue.hasUploadableLocalEvidence, isFalse);
  });
}
