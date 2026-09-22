use crate::domain::{ActionEligibility, SigninClass};
use chrono::{DateTime, NaiveDate, NaiveTime, TimeZone, Utc};

fn time(value: &str, date: NaiveDate) -> Option<DateTime<Utc>> {
    if let Ok(value) = DateTime::parse_from_rfc3339(value) {
        return Some(value.to_utc());
    }
    let local = crate::features::bykc::parse_datetime(Some(value)).or_else(|| {
        ["%H:%M", "%H:%M:%S"].iter().find_map(|format| {
            NaiveTime::parse_from_str(value.trim(), format)
                .ok()
                .map(|time| date.and_time(time))
        })
    })?;
    chrono_tz::Asia::Shanghai
        .from_local_datetime(&local)
        .single()
        .map(|v| v.to_utc())
}

pub(crate) fn apply_window(class: &mut SigninClass, date: NaiveDate, now: DateTime<Utc>) {
    let message = if class.sign_status == Some(1) {
        Some("已签到")
    } else if let (Some(start), Some(end)) = (
        time(&class.class_begin_time, date),
        time(&class.class_end_time, date),
    ) {
        if end <= start || start.with_timezone(&chrono_tz::Asia::Shanghai).date_naive() != date {
            Some("课程时间无效，不能签到")
        } else if now < start - chrono::Duration::minutes(10) {
            Some("开课前 10 分钟开放签到")
        } else if now >= end {
            Some("课程已结束")
        } else if class.signin_eligibility != ActionEligibility::Allowed {
            Some("学校尚未提供可签到状态")
        } else {
            None
        }
    } else {
        Some("缺少有效课程时间，不能签到")
    };
    if let Some(message) = message {
        if class.signin_eligibility == ActionEligibility::Allowed {
            class.signin_eligibility = ActionEligibility::Denied;
        }
        class.availability_message = Some(message.into());
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn ten_minute_boundary_and_invalid_times_fail_closed() {
        let date = NaiveDate::from_ymd_opt(2026, 9, 22).unwrap();
        let row = SigninClass {
            class_begin_time: "08:00".into(),
            class_end_time: "09:35".into(),
            signin_eligibility: ActionEligibility::Allowed,
            sign_status: Some(0),
            ..Default::default()
        };
        for (clock, allowed) in [
            ("07:49:59", false),
            ("07:50:00", true),
            ("08:00:00", true),
            ("09:35:00", false),
        ] {
            let mut class = row.clone();
            apply_window(&mut class, date, time(clock, date).unwrap());
            assert_eq!(
                class.signin_eligibility == ActionEligibility::Allowed,
                allowed
            );
        }
        let mut invalid = row.clone();
        invalid.class_begin_time.clear();
        apply_window(&mut invalid, date, time("08:00", date).unwrap());
        assert_ne!(invalid.signin_eligibility, ActionEligibility::Allowed);
        let mut signed = row;
        signed.sign_status = Some(1);
        apply_window(&mut signed, date, time("08:00", date).unwrap());
        assert_ne!(signed.signin_eligibility, ActionEligibility::Allowed);
    }
}
