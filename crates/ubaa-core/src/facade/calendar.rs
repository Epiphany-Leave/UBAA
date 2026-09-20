//! Local-only calendar rules. No session, network, persistence or diagnostics.
use chrono::{DateTime, FixedOffset, TimeZone};

pub struct CalendarDraft {
    pub title: String,
    pub location: String,
    pub description: String,
    pub start_ms: i64,
    pub end_ms: i64,
    pub reminder_minutes: Option<i32>,
}

fn timestamp(value: Option<&str>) -> Option<i64> {
    let text = value?.trim();
    if let Ok(date) = DateTime::parse_from_rfc3339(text) {
        return Some(date.timestamp_millis());
    }
    let date = crate::features::bykc::parse_datetime(Some(text))?;
    FixedOffset::east_opt(8 * 3600)?
        .from_local_datetime(&date)
        .single()
        .map(|date| date.timestamp_millis())
}

/// Build a system-calendar draft from already loaded Boya fields.
#[must_use]
pub fn bykc_calendar_draft(
    title: &str,
    location: Option<&str>,
    start: Option<&str>,
    end: Option<&str>,
    select_start: Option<&str>,
    reminder: bool,
) -> Option<CalendarDraft> {
    if title.trim().is_empty() {
        return None;
    }
    let (start_ms, end_ms) = if reminder {
        let start = timestamp(select_start)?;
        (start, start.checked_add(300_000)?)
    } else {
        (timestamp(start)?, timestamp(end)?)
    };
    if end_ms <= start_ms {
        return None;
    }
    Some(CalendarDraft {
        title: format!(
            "博雅{}：{}",
            if reminder { "选课提醒" } else { "课程" },
            title.trim()
        ),
        location: location.unwrap_or_default().to_owned(),
        description: if reminder {
            "开放选课时间见日程开始时间。请确认设置提前 5 分钟提醒；本提醒不会自动选课。"
        } else {
            "从 UBAA 添加的博雅课程。课程变动或退选后，请自行修改日历。"
        }
        .to_owned(),
        start_ms,
        end_ms,
        reminder_minutes: reminder.then_some(5),
    })
}

/// Half-open intervals: touching endpoints are not a conflict.
#[must_use]
pub fn calendar_overlaps(start: i64, end: i64, other_start: i64, other_end: i64) -> bool {
    start < end && other_start < other_end && start < other_end && other_start < end
}
