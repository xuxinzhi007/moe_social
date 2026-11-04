/// 回复参谋 API 模型。
class ReplyAssistJudgeSummary {
  const ReplyAssistJudgeSummary({
    required this.intent,
    required this.emotion,
    required this.urgency,
    required this.replyStance,
    required this.shouldReply,
    this.uncertaintyNote = '',
    this.riskHint = '',
  });

  final String intent;
  final String emotion;
  final String urgency;
  final String replyStance;
  final String shouldReply;
  final String uncertaintyNote;
  final String riskHint;

  factory ReplyAssistJudgeSummary.fromJson(Map<String, dynamic> json) {
    return ReplyAssistJudgeSummary(
      intent: json['intent']?.toString() ?? '',
      emotion: json['emotion']?.toString() ?? '',
      urgency: json['urgency']?.toString() ?? '',
      replyStance: json['reply_stance']?.toString() ?? '',
      shouldReply: json['should_reply']?.toString() ?? '',
      uncertaintyNote: json['uncertainty_note']?.toString() ?? '',
      riskHint: json['risk_hint']?.toString() ?? '',
    );
  }
}

class ReplyAssistOption {
  const ReplyAssistOption({required this.label, required this.text});

  final String label;
  final String text;

  factory ReplyAssistOption.fromJson(Map<String, dynamic> json) {
    return ReplyAssistOption(
      label: json['label']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
    );
  }
}

class ReplyAssistSuggestResult {
  const ReplyAssistSuggestResult({
    required this.judge,
    required this.options,
    this.sessionId = '',
    this.needsScreenshotFallback = false,
  });

  final ReplyAssistJudgeSummary judge;
  final List<ReplyAssistOption> options;
  final String sessionId;
  final bool needsScreenshotFallback;

  factory ReplyAssistSuggestResult.fromJson(Map<String, dynamic> json) {
    final judgeRaw = json['judge'];
    final optionsRaw = json['options'];
    return ReplyAssistSuggestResult(
      judge: judgeRaw is Map<String, dynamic>
          ? ReplyAssistJudgeSummary.fromJson(judgeRaw)
          : const ReplyAssistJudgeSummary(
              intent: '',
              emotion: '',
              urgency: '',
              replyStance: '',
              shouldReply: '',
            ),
      options: optionsRaw is List
          ? optionsRaw
              .whereType<Map>()
              .map((e) =>
                  ReplyAssistOption.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      sessionId: json['session_id']?.toString() ?? '',
      needsScreenshotFallback: json['needs_screenshot_fallback'] == true,
    );
  }
}

class ReplyAssistChatMessage {
  const ReplyAssistChatMessage({required this.role, required this.text});

  final String role;
  final String text;

  Map<String, dynamic> toJson() => {'role': role, 'text': text};
}
