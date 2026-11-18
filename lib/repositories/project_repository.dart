import '../models/project_model.dart';

abstract class ProjectRepository {
  Future<List<ProjectModel>> getProjects({required String ownerId});
  Future<ProjectModel?> getProjectById(String id);
  Future<void> createProject(ProjectModel project);
  Future<void> updateProject(ProjectModel project);
  Future<void> deleteProject(String id);
}

/// In-memory implementation used during prototype phase
class InMemoryProjectRepository implements ProjectRepository {
  final List<ProjectModel> _storage = [];

  InMemoryProjectRepository([List<ProjectModel>? initial]) {
    if (initial != null) {
      _storage.addAll(initial);
    }
  }

  @override
  Future<List<ProjectModel>> getProjects({required String ownerId}) async {
    return _storage.where((p) => p.ownerId == ownerId).toList();
  }

  @override
  Future<ProjectModel?> getProjectById(String id) async {
    final matches = _storage.where((p) => p.id == id);
    return matches.isNotEmpty ? matches.first : null;
  }

  @override
  Future<void> createProject(ProjectModel project) async {
    _storage.insert(0, project);
  }

  @override
  Future<void> updateProject(ProjectModel project) async {
    final index = _storage.indexWhere((p) => p.id == project.id);
    if (index != -1) {
      _storage[index] = project;
    }
  }

  @override
  Future<void> deleteProject(String id) async {
    _storage.removeWhere((p) => p.id == id);
  }
}
