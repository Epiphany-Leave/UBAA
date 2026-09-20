use ubaa_core::facade::{bykc_calendar_draft, calendar_overlaps};

#[test]
fn calendar_uses_beijing_time_and_strict_overlap() {
    let draft = bykc_calendar_draft(
        "测试课程",
        Some("教室"),
        Some("2026-09-20 23:30:00"),
        Some("2026-09-21T00:30:00"),
        None,
        false,
    )
    .unwrap();
    assert_eq!(draft.end_ms - draft.start_ms, 3_600_000);
    assert_eq!(
        chrono::DateTime::from_timestamp_millis(draft.start_ms)
            .unwrap()
            .to_rfc3339(),
        "2026-09-20T15:30:00+00:00"
    );
    assert!(calendar_overlaps(
        draft.start_ms,
        draft.end_ms,
        draft.start_ms,
        draft.end_ms
    ));
    assert!(!calendar_overlaps(
        draft.start_ms,
        draft.end_ms,
        draft.end_ms,
        draft.end_ms + 1
    ));
    assert!(!calendar_overlaps(10, 5, 1, 20));
    assert!(
        bykc_calendar_draft(
            "测试",
            None,
            Some("2026-09-20"),
            Some("2026-09-21"),
            None,
            false
        )
        .is_none()
    );
    assert!(
        bykc_calendar_draft(
            "测试",
            None,
            Some("2026-09-21 12:00:00"),
            Some("2026-09-20 12:00:00"),
            None,
            false
        )
        .is_none()
    );
    let reminder =
        bykc_calendar_draft("测试", None, None, None, Some("2026-09-20 12:00:00"), true).unwrap();
    assert_eq!(reminder.end_ms - reminder.start_ms, 300_000);
    assert_eq!(reminder.reminder_minutes, Some(5));
    assert!(bykc_calendar_draft("", None, None, None, Some("2026-09-20 12:00:00"), true).is_none());
}
