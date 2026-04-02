class DetectionResult {
  final String label;
  final String labelKey;
  final double confidence;
  final List<LabelScore> allScores;

  const DetectionResult({
    required this.label,
    required this.labelKey,
    required this.confidence,
    required this.allScores,
  });
}

class LabelScore {
  final String label;
  final double score;
  const LabelScore(this.label, this.score);
}

// ── DIY Solution ─────────────────────────────────────────────────────────────

class DiySolution {
  final String issue;
  final String severity;       // low / medium / high
  final bool diyPossible;
  final List<String> steps;
  final List<String> tools;
  final String estimatedTime;
  final String warning;

  const DiySolution({
    required this.issue,
    required this.severity,
    required this.diyPossible,
    required this.steps,
    required this.tools,
    required this.estimatedTime,
    required this.warning,
  });
}