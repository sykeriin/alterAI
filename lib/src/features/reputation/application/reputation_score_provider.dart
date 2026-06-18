import 'dart:convert';



import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:http/http.dart' as http;



import '../../../core/config/alter_gateway_config.dart';

import '../../auth/application/auth_provider.dart';

import '../../profile/application/profile_provider.dart';

import '../../shared/application/alter_data_providers.dart';



class ReputationScoreSnapshot {

  const ReputationScoreSnapshot({

    required this.score,

    required this.recentDelta,

    required this.topDomain,

    required this.topDomainFit,

    required this.focusArea,

    required this.focusAreaFit,

  });



  static const empty = ReputationScoreSnapshot(

    score: 0,

    recentDelta: 0,

    topDomain: '',

    topDomainFit: 0,

    focusArea: '',

    focusAreaFit: 0,

  );



  final int score;

  final int recentDelta;

  final String topDomain;

  final int topDomainFit;

  final String focusArea;

  final int focusAreaFit;



  bool get hasData =>
      score > 600 || topDomain.isNotEmpty || focusArea.isNotEmpty;

}



final reputationScoreProvider =

    FutureProvider<ReputationScoreSnapshot>((ref) async {

  final user = ref.watch(currentUserProvider);

  if (user == null) return ReputationScoreSnapshot.empty;



  if (AlterGatewayConfig.isConfigured) {

    try {

      final response = await http.get(

        Uri.parse(

          '${AlterGatewayConfig.normalizedBaseUrl}/v1/reputation/users/${user.id}/score',

        ),

      );

      if (response.statusCode == 200) {

        final json = jsonDecode(response.body) as Map<String, dynamic>;

        final strengths = (json['strengths'] as List<dynamic>? ?? const [])

            .cast<String>();

        final risks = (json['risks'] as List<dynamic>? ?? const [])

            .cast<String>();

        final score = json['score'] as int? ?? 0;
        final recentDelta = json['recent_delta'] as int? ?? 0;

        if (score <= 600 &&
            recentDelta == 0 &&
            strengths.isEmpty &&
            risks.isEmpty) {
          return ReputationScoreSnapshot.empty;
        }

        if (score == 0 && strengths.isEmpty && risks.isEmpty) {

          return ReputationScoreSnapshot.empty;

        }

        return ReputationScoreSnapshot(

          score: score,

          recentDelta: json['recent_delta'] as int? ?? 0,

          topDomain: strengths.isNotEmpty ? strengths.first : '',

          topDomainFit: strengths.isNotEmpty ? 85 : 0,

          focusArea: risks.isNotEmpty ? risks.first : '',

          focusAreaFit: risks.isNotEmpty ? 50 : 0,

        );

      }

    } catch (_) {}

  }



  final events = await ref.watch(reputationEventsProvider.future);

  if (events.isEmpty) {

    final profile = ref.watch(userProfileProvider).asData?.value;

    final topSkill = profile?.skills.isNotEmpty == true

        ? profile!.skills.first

        : '';

    final topGoal = profile?.goals.isNotEmpty == true ? profile!.goals.first : '';

    if (topSkill.isEmpty && topGoal.isEmpty) {

      return ReputationScoreSnapshot.empty;

    }

    return ReputationScoreSnapshot(

      score: 0,

      recentDelta: 0,

      topDomain: topSkill,

      topDomainFit: 0,

      focusArea: topGoal,

      focusAreaFit: 0,

    );

  }



  final score = (70 + events.fold<int>(0, (sum, e) => sum + e.delta))

      .clamp(50, 100);

  return ReputationScoreSnapshot(

    score: score,

    recentDelta: events.take(5).fold<int>(0, (sum, e) => sum + e.delta),

    topDomain: events.first.title,

    topDomainFit: 0,

    focusArea: events.length > 1 ? events[1].title : '',

    focusAreaFit: 0,

  );

});

