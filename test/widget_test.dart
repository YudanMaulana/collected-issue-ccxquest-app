import 'package:collected_issues/main.dart';
import 'package:collected_issues/models/issue.dart';
import 'package:collected_issues/repositories/issue_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeIssueRepository implements IssueRepository {
  @override
  Future<void> clearAllIssues() async {}

  @override
  Future<void> deleteIssue(int id) async {}

  @override
  Future<String> generateNextIssueCode() async => 'CI001';

  @override
  Future<List<Issue>> getAllIssues({String? search, String? area, String? kategori, String? status, bool? incompleteOnly}) async => [];

  @override
  Future<Map<String, dynamic>> getDashboardMetrics() async => {
        'total': 0,
        'solved': 0,
        'pending': 0,
        'incomplete': 0,
        'byArea': <String, int>{},
        'byKategori': <String, int>{},
        'longestPending': <Issue>[],
      };

  @override
  Future<Issue> getIssueById(int id) async => throw UnimplementedError();

  @override
  Future<List<Map<String, String>>> getUniqueIssues() async => [];

  @override
  Future<void> importIssues(List<Issue> issues) async {}

  @override
  Future<int> insertIssue(Issue issue) async => 1;

  @override
  Future<void> updateIssue(Issue issue) async {}
}

void main() {
  testWidgets('App shows PIN gate and unlocks with correct PIN', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp(repository: _FakeIssueRepository()));

    expect(find.text('COLLECTED ISSUE'), findsOneWidget);
    expect(find.text('Enter PIN to Access Database'), findsOneWidget);

    for (final digit in ['1', '9', '9', '9']) {
      await tester.tap(find.text(digit));
      await tester.pump();
    }

    await tester.pumpAndSettle();

    expect(find.text('DASHBOARD'), findsOneWidget);
  });
}
