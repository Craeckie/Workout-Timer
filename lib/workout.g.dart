// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'utils/workout.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Workout _$WorkoutFromJson(Map<String, dynamic> json) {
  $checkKeys(json, requiredKeys: const ['title', 'sets']);
  return Workout(
    title: json['title'] as String? ?? 'Workout',
    sets: (json['sets'] as List<dynamic>?)
        ?.map((e) => Set.fromJson(e as Map<String, dynamic>))
        .toList(),
    version: (json['version'] as num?)?.toInt() ?? 1,
    position: (json['position'] as num?)?.toInt() ?? -1,
  );
}

Map<String, dynamic> _$WorkoutToJson(Workout instance) => <String, dynamic>{
  'title': instance.title,
  'sets': instance.sets.map((e) => e.toJson()).toList(),
  'version': instance.version,
  'position': instance.position,
};

Set _$SetFromJson(Map<String, dynamic> json) {
  $checkKeys(json, requiredKeys: const ['repetitions', 'exercises']);
  return Set(
    id: json['id'] as String?,
    repetitions: (json['repetitions'] as num?)?.toInt() ?? 1,
    exercises: (json['exercises'] as List<dynamic>?)
        ?.map((e) => Exercise.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

Map<String, dynamic> _$SetToJson(Set instance) => <String, dynamic>{
  'repetitions': instance.repetitions,
  'id': instance.id,
  'exercises': instance.exercises.map((e) => e.toJson()).toList(),
};

Exercise _$ExerciseFromJson(Map<String, dynamic> json) {
  $checkKeys(json, requiredKeys: const ['name', 'duration']);
  return Exercise(
    id: json['id'] as String?,
    name: json['name'] as String? ?? 'Exercise',
    duration: (json['duration'] as num?)?.toInt() ?? 30,
  );
}

Map<String, dynamic> _$ExerciseToJson(Exercise instance) => <String, dynamic>{
  'name': instance.name,
  'id': instance.id,
  'duration': instance.duration,
};

Backup _$BackupFromJson(Map<String, dynamic> json) {
  $checkKeys(json, requiredKeys: const ['workouts']);
  return Backup(
    workouts: (json['workouts'] as List<dynamic>)
        .map((e) => Workout.fromJson(e as Map<String, dynamic>))
        .toList(),
    history: (json['history'] as List<dynamic>?)
        ?.map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

Map<String, dynamic> _$BackupToJson(Backup instance) => <String, dynamic>{
  'workouts': instance.workouts.map((e) => e.toJson()).toList(),
  'history': ?instance.history?.map((e) => e.toJson()).toList(),
};

HistoryEntry _$HistoryEntryFromJson(Map<String, dynamic> json) {
  $checkKeys(json, requiredKeys: const ['title', 'completedAt']);
  return HistoryEntry(
    title: json['title'] as String,
    completedAt: DateTime.parse(json['completedAt'] as String),
  );
}

Map<String, dynamic> _$HistoryEntryToJson(HistoryEntry instance) =>
    <String, dynamic>{
      'title': instance.title,
      'completedAt': instance.completedAt.toIso8601String(),
    };
