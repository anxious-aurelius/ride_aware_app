class RideSlot {
  final DateTime start;
  final DateTime end;
  final String rideId;
  RideSlot({required this.start, required this.end, required this.rideId});
}

class FeedbackWindow {
  final DateTime showAt;
  final DateTime hideAt;
  FeedbackWindow({required this.showAt, required this.hideAt});
}

FeedbackWindow windowFor(RideSlot current, RideSlot? next) {
  // Show feedback immediately after the current ride ends
  final showAt = current.end;
  // Hide feedback one minute before the next ride starts (if any)
  final hideAt = (next == null
          ? DateTime.fromMillisecondsSinceEpoch(8640000000000000)
          : next.start)
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
