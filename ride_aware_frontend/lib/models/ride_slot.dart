class RideSlot {
  final DateTime startUtc;
  final DateTime endUtc;
  final String rideId;
  RideSlot({required this.startUtc, required this.endUtc, required this.rideId});
}

class FeedbackWindow {
  final DateTime showAt;
  final DateTime hideAt;
  FeedbackWindow({required this.showAt, required this.hideAt});
}

FeedbackWindow windowFor(RideSlot current, RideSlot? next) {
  final showAt = current.endUtc.toLocal().add(const Duration(hours: 1));
  final hideAt = (next == null
          ? DateTime.fromMillisecondsSinceEpoch(8640000000000000, isUtc: true)
          : next.startUtc)
      .toLocal()
      .subtract(const Duration(minutes: 1));
  return FeedbackWindow(showAt: showAt, hideAt: hideAt);
}

bool shouldShowFeedback({
  required RideSlot current,
  required RideSlot? next,
  required bool feedbackAlreadySubmitted,
  DateTime? nowLocal,
}) {
  if (feedbackAlreadySubmitted) return false;
  final now = nowLocal ?? DateTime.now();
  final win = windowFor(current, next);
  if (now.isAfter(win.hideAt)) return false;
  return !now.isBefore(win.showAt);
}
