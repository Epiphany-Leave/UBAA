use super::types::Operation;
use super::{CachedRead, RoutedError, RoutedResult, UbaaClient};
use crate::domain::{ReadonlyFeature, SavedSchedule, SigninClass, SigninDay};
use chrono::{Datelike, NaiveDate};

fn parse_date(date: &str) -> Result<NaiveDate, RoutedError> {
    NaiveDate::parse_from_str(date, "%Y-%m-%d")
        .ok()
        .filter(|parsed| date.len() == 10 && (1..=9999).contains(&parsed.year()))
        .ok_or_else(|| RoutedError {
            error: super::routing::invalid_input("签到日期应为 YYYY-MM-DD"),
            resolution: None,
        })
}

impl UbaaClient {
    /// Query an iClass day, supplement display rows and recalculate the time window.
    /// # Errors
    /// Invalid dates, authentication and upstream errors remain failures.
    pub async fn signin_on(&mut self, date: &str) -> RoutedResult<Vec<SigninClass>> {
        let date = parse_date(date)?;
        let resolution = self.resolve_operation(Operation::Feature(ReadonlyFeature::Signin))?;
        let response = crate::features::signin::get_on_date(
            self.runtime_for(resolution.mode),
            &date.format("%Y%m%d").to_string(),
        )
        .await;
        let mut result = self.finish_routed(resolution, response)?;
        let saved = self.saved_schedule().map_err(|error| RoutedError {
            error,
            resolution: Some(resolution),
        })?;
        decorate_day(&mut result.data, date, &saved);
        Ok(result)
    }

    /// Read a complete account-scoped week; only explicit refresh replaces a saved week.
    /// # Errors
    /// Any failed day prevents replacing the prior snapshot. Writes always use live preflight.
    pub async fn signin_week(
        &mut self,
        date: &str,
        refresh: bool,
    ) -> Result<CachedRead<Vec<SigninDay>>, RoutedError> {
        let date = parse_date(date)?;
        let monday =
            date - chrono::Duration::days(i64::from(date.weekday().num_days_from_monday()));
        let mut cached = self
            .cached(format!("v1/signin_week/{monday}"), refresh, move |client| {
                Box::pin(async move { client.fetch_signin_week(monday).await })
            })
            .await?;
        let saved = self.saved_schedule().map_err(|error| RoutedError {
            error,
            resolution: Some(cached.result.resolution),
        })?;
        let today = chrono::Utc::now()
            .with_timezone(&chrono_tz::Asia::Shanghai)
            .date_naive();
        for day in &mut cached.result.data {
            let date = parse_date(&day.date)?;
            day.is_future = date > today;
            decorate_day(&mut day.classes, date, &saved);
        }
        Ok(cached)
    }

    async fn fetch_signin_week(&mut self, monday: NaiveDate) -> RoutedResult<Vec<SigninDay>> {
        let resolution = self.resolve_operation(Operation::Feature(ReadonlyFeature::Signin))?;
        let mut days = Vec::with_capacity(7);
        for offset in 0..7 {
            let date = monday
                .checked_add_signed(chrono::Duration::days(offset))
                .ok_or_else(|| RoutedError {
                    error: super::routing::invalid_input("签到日期超出范围"),
                    resolution: Some(resolution),
                })?;
            let response = crate::features::signin::get_on_date(
                self.runtime_for(resolution.mode),
                &date.format("%Y%m%d").to_string(),
            )
            .await;
            let classes = self.finish_routed(resolution, response)?.data;
            days.push(SigninDay {
                date: date.to_string(),
                is_future: false,
                classes,
            });
        }
        self.finish_routed(resolution, Ok(days))
    }
}

fn decorate_day(classes: &mut Vec<SigninClass>, date: NaiveDate, saved: &SavedSchedule) {
    for semester in &saved.semesters {
        for (week, schedule) in semester.weeks.iter().zip(&semester.schedules) {
            let start = crate::session::schedule_cache::schedule_date(&week.start_date);
            let end = crate::session::schedule_cache::schedule_date(&week.end_date);
            if !matches!((start, end), (Some(start), Some(end)) if date >= start && date <= end) {
                continue;
            }
            for course in &schedule.arranged_list {
                if course.day_of_week != Some(date.weekday().number_from_monday().cast_signed())
                    || classes
                        .iter()
                        .any(|row| row.course_name.trim() == course.course_name.trim())
                {
                    continue;
                }
                classes.push(SigninClass {
                    course_name: course.course_name.clone(),
                    class_begin_time: course.begin_time.clone().unwrap_or_default(),
                    class_end_time: course.end_time.clone().unwrap_or_default(),
                    availability_message: Some("来自本地课表；学校未返回签到记录，仅供查看".into()),
                    ..Default::default()
                });
            }
        }
    }
    for class in classes {
        if class.signin_target.is_some() {
            crate::features::signin::apply_window(class, date, chrono::Utc::now());
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{
        connection::{NetworkState, RouteDiagnostic, RouteResolution},
        domain::{ActionEligibility, ConnectionMode, RoutePolicy},
        session::schedule_cache,
    };

    #[test]
    fn saved_week_survives_restart_and_recalculates_future_dates() {
        let runtime = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .unwrap();
        runtime.block_on(async {
            let root = std::env::temp_dir().join(format!(
                "ubaa-signin-week-{}-{}",
                std::process::id(),
                chrono::Utc::now().timestamp_nanos_opt().unwrap()
            ));
            std::fs::create_dir_all(&root).unwrap();
            schedule_cache::select_owner(&root, Some("Gfixture")).unwrap();
            let date = NaiveDate::from_ymd_opt(2099, 1, 5).unwrap();
            let monday =
                date - chrono::Duration::days(i64::from(date.weekday().num_days_from_monday()));
            let days: Vec<_> = (0..7)
                .map(|offset| SigninDay {
                    date: (monday + chrono::Duration::days(offset)).to_string(),
                    is_future: false,
                    classes: vec![SigninClass {
                        course_id: format!("day-{offset}"),
                        signin_target: Some(format!("day-{offset}")),
                        class_begin_time: "08:00".into(),
                        class_end_time: "10:00".into(),
                        sign_status: Some(0),
                        signin_eligibility: ActionEligibility::Allowed,
                        ..Default::default()
                    }],
                })
                .collect();
            schedule_cache::save_snapshot(
                &root,
                "Gfixture",
                &format!("v1/signin_week/{monday}"),
                schedule_cache::ReadSnapshot {
                    data: serde_json::to_value(days).unwrap(),
                    saved_at: "2026-09-22T01:00:00Z".into(),
                    resolution: RouteResolution {
                        mode: ConnectionMode::Direct,
                        policy: RoutePolicy::Direct,
                        diagnostic: RouteDiagnostic::new(
                            NetworkState::Unknown,
                            ConnectionMode::Direct,
                        ),
                    },
                },
            )
            .unwrap();
            for offset in [0, 3, 6] {
                let mut client = UbaaClient::open(&root).unwrap();
                let cached = client
                    .signin_week(
                        &(monday + chrono::Duration::days(offset)).to_string(),
                        false,
                    )
                    .await
                    .unwrap();
                assert!(cached.from_cache);
                assert_eq!(cached.result.data.len(), 7);
                assert!(cached.result.data.iter().all(|day| day.is_future
                    && day.classes[0].signin_eligibility == ActionEligibility::Denied));
                assert_eq!(cached.saved_at.as_deref(), Some("2026-09-22T01:00:00Z"));
            }
            std::fs::remove_dir_all(root).unwrap();
        });
    }
}
