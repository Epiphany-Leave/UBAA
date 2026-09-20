//! Local calendar operations use only Core's public facade.
#[derive(Clone)]
pub struct BridgeCalendarDraft {
    pub title: String,
    pub location: String,
    pub description: String,
    pub start_ms: i64,
    pub end_ms: i64,
    pub reminder_minutes: Option<i32>,
}

#[flutter_rust_bridge::frb(sync)]
pub fn bykc_calendar_draft(
    title: String,
    location: Option<String>,
    start: Option<String>,
    end: Option<String>,
    select_start: Option<String>,
    reminder: bool,
) -> Option<BridgeCalendarDraft> {
    ubaa_core::facade::bykc_calendar_draft(
        &title,
        location.as_deref(),
        start.as_deref(),
        end.as_deref(),
        select_start.as_deref(),
        reminder,
    )
    .map(|draft| BridgeCalendarDraft {
        title: draft.title,
        location: draft.location,
        description: draft.description,
        start_ms: draft.start_ms,
        end_ms: draft.end_ms,
        reminder_minutes: draft.reminder_minutes,
    })
}

#[flutter_rust_bridge::frb(sync)]
pub fn calendar_overlaps(start: i64, end: i64, other_start: i64, other_end: i64) -> bool {
    ubaa_core::facade::calendar_overlaps(start, end, other_start, other_end)
}
