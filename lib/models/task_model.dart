class TaskModel {
  final String id;
  final String title;
  final String assignedTo;
  final DateTime dueDate;
  final bool isDone;

  TaskModel({
    required this.id,
    required this.title,
    required this.assignedTo,
    required this.dueDate,
    required this.isDone,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'assignedTo': assignedTo,
      'dueDate': dueDate,
      'isDone': isDone,
    };
  }

  factory TaskModel.fromMap(String id, Map<String, dynamic> map) {
    return TaskModel(
      id: id,
      title: map['title'],
      assignedTo: map['assignedTo'],
      dueDate: (map['dueDate']).toDate(),
      isDone: map['isDone'],
    );
  }
}
