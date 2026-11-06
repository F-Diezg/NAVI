// Pruebas de las reglas de clasificación y del estado de los elementos.
// Ejecutar con: flutter test

import 'package:flutter_test/flutter_test.dart';
import 'package:navi/canvas_api.dart';
import 'package:navi/models.dart';

void main() {
  group('Clasificador', () {
    ItemKind kind(String t, {String g = 'Tareas', bool quiz = false}) =>
        Classifier.assignmentKind(title: t, groupName: g, isQuiz: quiz);

    test('detecta exámenes por el título', () {
      expect(kind('Examen parcial 1'), ItemKind.exam);
      expect(kind('EXÁMEN FINAL'), ItemKind.exam);
      expect(kind('Prueba de evaluación continua'), ItemKind.exam);
      expect(kind('Midterm'), ItemKind.exam);
    });

    test('una entrega parcial es tarea', () {
      expect(kind('Entrega parcial del proyecto'), ItemKind.task);
      expect(kind('Actividad 3: informe'), ItemKind.task);
    });

    test('tests y quizzes solo cuentan si están en el grupo de exámenes', () {
      expect(kind('Test tema 4'), ItemKind.task);
      expect(kind('Test tema 4', g: 'Exámenes y pruebas'), ItemKind.exam);
      expect(kind('Cuestionario', g: 'Pruebas objetivas', quiz: true),
          ItemKind.exam);
    });

    test('asistencia', () {
      expect(Classifier.isAttendance('Roll Call Attendance'), isTrue);
      expect(Classifier.isAttendance('Asistencia'), isTrue);
      expect(Classifier.isAttendance('Práctica 2'), isFalse);
    });
  });

  group('Estado', () {
    final now = DateTime(2026, 11, 4, 12);
    NaviItem item(ItemKind k, DateTime due, {bool done = false}) => NaviItem(
        id: 'x', source: 'canvas', title: 't', kind: k, dueAt: due, done: done);

    test('tarea vencida sin entregar se tacha', () {
      expect(item(ItemKind.task, DateTime(2026, 11, 3)).statusAt(now),
          ItemStatus.overdue);
    });
    test('examen pasado se marca solo', () {
      expect(item(ItemKind.exam, DateTime(2026, 11, 3)).statusAt(now),
          ItemStatus.autoDone);
    });
    test('marcada a mano', () {
      expect(item(ItemKind.task, DateTime(2026, 11, 3), done: true).statusAt(now),
          ItemStatus.done);
    });
    test('futura pendiente', () {
      expect(item(ItemKind.task, DateTime(2026, 11, 5)).statusAt(now),
          ItemStatus.pending);
    });
  });
}
