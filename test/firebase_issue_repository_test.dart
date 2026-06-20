import 'package:collected_issues/models/issue.dart';
import 'package:collected_issues/repositories/firebase_issue_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('updateIssue can sync selected fields to issues with same code only', () async {
    final repo = FirebaseIssueRepository();

    final firstId = await repo.insertIssue(
      Issue(
        tgl: DateTime(2026, 6, 20),
        area: 'AREA A',
        kategori: 'SISTEM',
        issue: 'Issue awal',
        penanganan: 'Vendor Lama',
        status: 'pending',
        perulanganMasalah: 1,
        penyebab: 'Penyebab Lama',
        evide: null,
        kodeIssue: 'CI001',
        tagDetail: 'Tag Lama',
      ),
    );

    final secondId = await repo.insertIssue(
      Issue(
        tgl: DateTime(2026, 6, 21),
        area: 'AREA A',
        kategori: 'SISTEM',
        issue: 'Issue awal',
        penanganan: 'Vendor Beda',
        status: 'pending',
        perulanganMasalah: 1,
        penyebab: 'Penyebab Beda',
        evide: null,
        kodeIssue: 'CI001',
        tagDetail: 'Tag Beda',
      ),
    );

    await repo.insertIssue(
      Issue(
        tgl: DateTime(2026, 6, 21),
        area: 'AREA A',
        kategori: 'SISTEM',
        issue: 'Issue lain',
        penanganan: 'Vendor Lain',
        status: 'pending',
        perulanganMasalah: 1,
        penyebab: 'Penyebab Lain',
        evide: null,
        kodeIssue: 'CI002',
        tagDetail: 'Tag Lain',
      ),
    );

    await repo.updateIssue(
      Issue(
        id: firstId,
        tgl: DateTime(2026, 6, 25),
        area: 'AREA A',
        kategori: 'SISTEM',
        issue: 'Issue awal',
        penanganan: 'Vendor Baru',
        status: 'solved',
        perulanganMasalah: 1,
        penyebab: 'Penyebab Baru',
        evide: 'NO_NEED_EVIDEN',
        kodeIssue: 'CI001',
        tagDetail: 'Tag Baru',
      ),
      syncFields: {
        Issue.syncFieldPenanganan,
        Issue.syncFieldPenyebab,
        Issue.syncFieldTagDetail,
      },
    );

    final first = await repo.getIssueById(firstId);
    final second = await repo.getIssueById(secondId);
    final otherCode = await repo.getIssueById(3);

    expect(first.tgl, DateTime(2026, 6, 25));
    expect(second.tgl, DateTime(2026, 6, 21));
    expect(second.penanganan, 'Vendor Baru');
    expect(second.penyebab, 'Penyebab Baru');
    expect(second.tagDetail, 'Tag Baru');
    expect(second.status, 'pending');
    expect(otherCode.penanganan, 'Vendor Lain');
  });
}
