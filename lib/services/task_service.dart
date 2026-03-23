import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';

class TaskService {
  final _db = FirebaseFirestore.instance;

  Stream<List<TaskModel>> getTasks() {
    return _db.collection('tasks').snapshots().map((snapshot) => snapshot.docs
        .map((doc) => TaskModel.fromMap(doc.id, doc.data()))
        .toList());
  }

  Future<void> addTask(TaskModel task) async {
    await _db.collection('tasks').add(task.toMap());
  }

  Future<void> toggleTask(String id, bool value) async {
    await _db.collection('tasks').doc(id).update({'isDone': value});
  }
}
