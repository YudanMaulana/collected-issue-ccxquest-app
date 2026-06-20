import '../models/issue.dart';

abstract class IssueRepository {
  Future<List<Issue>> getAllIssues({String? search, String? area, String? kategori, String? status, bool? incompleteOnly});
  Future<Issue> getIssueById(int id);
  Future<int> insertIssue(Issue issue);
  Future<void> updateIssue(Issue issue, {Set<String> syncFields = const {}});
  Future<void> deleteIssue(int id);
  Future<void> importIssues(List<Issue> issues);
  Future<void> clearAllIssues();
  
  // Dashboard Metrics
  Future<Map<String, dynamic>> getDashboardMetrics();

  // Unique Tracking Codes
  Future<String> generateNextIssueCode();
  Future<List<Map<String, String>>> getUniqueIssues();
}
