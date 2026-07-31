import 'dart:convert';

import 'package:flutter/services.dart';

/// P1 表驱动课程/职业配置（`assets/pet/config/career.json`）。
class PetCareerConfig {
  PetCareerConfig({
    required this.minSchoolAge,
    required this.minWorkAge,
    required this.minMarryAge,
    required this.subjects,
    required this.jobs,
  });

  final int minSchoolAge;
  final int minWorkAge;
  final int minMarryAge;
  final List<PetSubject> subjects;
  final List<PetJob> jobs;

  static PetCareerConfig? _cached;

  static Future<PetCareerConfig> load() async {
    if (_cached != null) return _cached!;
    try {
      final raw = await rootBundle.loadString('assets/pet/config/career.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _cached = PetCareerConfig(
        minSchoolAge: (json['min_school_age'] as num?)?.toInt() ?? 3,
        minWorkAge: (json['min_work_age'] as num?)?.toInt() ?? 3,
        minMarryAge: (json['min_marry_age'] as num?)?.toInt() ?? 22,
        subjects: (json['subjects'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => PetSubject.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        jobs: (json['jobs'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => PetJob.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
    } catch (_) {
      _cached = PetCareerConfig(
        minSchoolAge: 3,
        minWorkAge: 3,
        minMarryAge: 22,
        subjects: const [
          PetSubject(id: 'virtue', name: '德育', stat: 'virtue', gain: 3),
          PetSubject(id: 'intel', name: '智育', stat: 'intel', gain: 3),
          PetSubject(id: 'sport', name: '体育', stat: 'sport', gain: 3),
          PetSubject(id: 'art', name: '美育', stat: 'art', gain: 3),
          PetSubject(id: 'labor', name: '劳育', stat: 'labor', gain: 3),
        ],
        jobs: const [
          PetJob(id: 'clerk', name: '店员', minAvgStat: 15, basePay: 20),
        ],
      );
    }
    return _cached!;
  }
}

class PetSubject {
  const PetSubject({
    required this.id,
    required this.name,
    required this.stat,
    required this.gain,
  });

  final String id;
  final String name;
  final String stat;
  final int gain;

  factory PetSubject.fromJson(Map<String, dynamic> json) => PetSubject(
        id: '${json['id']}',
        name: '${json['name']}',
        stat: '${json['stat']}',
        gain: (json['gain'] as num?)?.toInt() ?? 3,
      );
}

class PetJob {
  const PetJob({
    required this.id,
    required this.name,
    required this.minAvgStat,
    required this.basePay,
  });

  final String id;
  final String name;
  final int minAvgStat;
  final int basePay;

  factory PetJob.fromJson(Map<String, dynamic> json) => PetJob(
        id: '${json['id']}',
        name: '${json['name']}',
        minAvgStat: (json['min_avg_stat'] as num?)?.toInt() ?? 15,
        basePay: (json['base_pay'] as num?)?.toInt() ?? 20,
      );
}
