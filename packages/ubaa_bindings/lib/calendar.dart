import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart'
    show PlatformInt64Util;
import 'src/rust/api/calendar.dart' as bridge;
export 'src/rust/api/calendar.dart' show BridgeCalendarDraft, bykcCalendarDraft;

// FRB uses int on native targets and BigInt on Web.
bool calendarOverlaps({
  required int start,
  required int end,
  required int otherStart,
  required int otherEnd,
}) => bridge.calendarOverlaps(
  start: PlatformInt64Util.from(start),
  end: PlatformInt64Util.from(end),
  otherStart: PlatformInt64Util.from(otherStart),
  otherEnd: PlatformInt64Util.from(otherEnd),
);
