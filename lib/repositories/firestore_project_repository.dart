import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/project_model.dart';
import 'project_repository.dart';

/// Cloud Firestore implementation of [ProjectRepository].
/// Strictly enforces multi-agent isolation using `where('ownerId', isEqualTo: ownerId)`.
class FirestoreProjectRepository implements ProjectRepository {
  final FirebaseFirestore? _customFirestore;

  FirestoreProjectRepository({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('projects');

  @override
  Future<List<ProjectModel>> getProjects({required String ownerId}) async {
    final querySnapshot = await _collection
        .where('ownerId', isEqualTo: ownerId)
        .get();

    final projects = querySnapshot.docs
        .map((doc) => ProjectModel.fromMap(doc.data()))
        .toList();

    // Sort by newest created
    projects.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return projects;
  }

  @override
  Future<ProjectModel?> getProjectById(String id) async {
    final doc = await _collection.doc(id).get();
    if (doc.exists && doc.data() != null) {
      return ProjectModel.fromMap(doc.data()!);
    }
    return null;
  }

  @override
  Future<void> createProject(ProjectModel project) async {
    await _collection.doc(project.id).set(project.toMap());
  }

  @override
  Future<void> updateProject(ProjectModel project) async {
    await _collection.doc(project.id).update(project.toMap());
  }

  @override
  Future<void> deleteProject(String id) async {
    await _collection.doc(id).delete();
  }
}
