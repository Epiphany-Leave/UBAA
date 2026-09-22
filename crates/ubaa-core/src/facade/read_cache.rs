//! Opt-in persistent reads. Original facade methods retain live semantics.
use super::{CachedRead, Routed, RoutedError, RoutedResult, UbaaClient};
use crate::{
    domain::{
        ExamArrangement, GradeData, GradeOverview, JudgeAssignmentSummary, SpocAssignments, Term,
    },
    session::schedule_cache,
};
use serde::{Serialize, de::DeserializeOwned};
use std::{future::Future, pin::Pin};

impl UbaaClient {
    pub(super) async fn cached<T, F>(
        &mut self,
        key: String,
        refresh: bool,
        fetch: F,
    ) -> Result<CachedRead<T>, RoutedError>
    where
        T: Serialize + DeserializeOwned,
        F: for<'a> FnOnce(
            &'a mut Self,
        ) -> Pin<Box<dyn Future<Output = RoutedResult<T>> + Send + 'a>>,
    {
        let error = |error| RoutedError {
            error,
            resolution: None,
        };
        self.guard_latest_session_ownership().map_err(error)?;
        let storage = match self.config_dir.clone() {
            Some(dir) => schedule_cache::active_owner(&dir)
                .map_err(error)?
                .map(|owner| (dir, owner)),
            None => None,
        };
        if !refresh
            && let Some((dir, owner)) = &storage
            && let Some(saved) = schedule_cache::read_snapshot(dir, owner, &key).map_err(error)?
            && let Ok(data) = serde_json::from_value(saved.data)
        {
            return Ok(CachedRead {
                result: Routed {
                    data,
                    resolution: saved.resolution,
                },
                saved_at: Some(saved.saved_at),
                from_cache: true,
            });
        }
        if refresh {
            for runtime in [&self.direct_runtime, &self.webvpn_runtime] {
                if key == "v1/spoc_assignments" {
                    runtime.feature_state().spoc.clear();
                }
                if key.starts_with("v1/judge/") {
                    runtime.feature_state().judge.clear();
                }
            }
        }
        let result = fetch(self).await?;
        let mut saved_at = None;
        self.guard_latest_session_ownership().map_err(error)?;
        if let Some((dir, owner)) = storage {
            let data = serde_json::to_value(&result.data).map_err(|_| {
                error(crate::error::UbaaError::new(
                    crate::error::ErrorCode::InternalError,
                    crate::error::ErrorKind::Internal,
                    false,
                    "无法编码本地数据",
                ))
            })?;
            let timestamp = chrono::Utc::now().to_rfc3339();
            schedule_cache::save_snapshot(
                &dir,
                &owner,
                &key,
                schedule_cache::ReadSnapshot {
                    data,
                    resolution: result.resolution,
                    saved_at: timestamp.clone(),
                },
            )
            .map_err(error)?;
            saved_at = Some(timestamp);
        }
        Ok(CachedRead {
            result,
            saved_at,
            from_cache: false,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::connection::{NetworkState, RouteDiagnostic, RouteResolution};
    use crate::domain::{ConnectionMode, RoutePolicy};
    fn result(data: Vec<String>) -> Routed<Vec<String>> {
        Routed {
            data,
            resolution: RouteResolution {
                mode: ConnectionMode::Direct,
                policy: RoutePolicy::Direct,
                diagnostic: RouteDiagnostic::new(NetworkState::Unknown, ConnectionMode::Direct),
            },
        }
    }
    fn failure() -> RoutedError {
        RoutedError {
            error: super::super::routing::invalid_input("fixture failure"),
            resolution: None,
        }
    }
    #[test]
    fn restart_refresh_empty_failure_and_account_isolation() {
        tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .unwrap()
            .block_on(async {
                let dir = std::env::temp_dir().join(format!(
                    "ubaa-read-cache-{}-{}",
                    std::process::id(),
                    chrono::Utc::now().timestamp_nanos_opt().unwrap()
                ));
                std::fs::create_dir_all(&dir).unwrap();
                let mut client = UbaaClient::open(&dir).unwrap();
                schedule_cache::select_owner(&dir, Some("Gfixture")).unwrap();
                let first = client
                    .cached("grades/term-a".into(), false, |_| {
                        Box::pin(async { Ok(result(vec!["fixture".into()])) })
                    })
                    .await
                    .unwrap();
                drop(client);
                let mut client = UbaaClient::open(&dir).unwrap();
                let saved = client
                    .cached::<Vec<String>, _>("grades/term-a".into(), false, |_| {
                        Box::pin(async { panic!("cache hit must not fetch") })
                    })
                    .await
                    .unwrap();
                assert!(saved.from_cache);
                assert_eq!(saved.result.data, first.result.data);
                assert_eq!(saved.saved_at, first.saved_at);
                assert!(
                    client
                        .cached::<Vec<String>, _>("grades/term-a".into(), true, |_| Box::pin(
                            async { Err(failure()) }
                        ))
                        .await
                        .is_err()
                );
                assert!(
                    client
                        .cached::<Vec<String>, _>("grades/term-b".into(), false, |_| Box::pin(
                            async { Err(failure()) }
                        ))
                        .await
                        .is_err()
                );
                assert_eq!(
                    schedule_cache::read_snapshot(&dir, "Gfixture", "grades/term-a")
                        .unwrap()
                        .unwrap()
                        .data,
                    serde_json::json!(["fixture"])
                );
                client
                    .cached("grades/term-a".into(), true, |_| {
                        Box::pin(async { Ok(result(vec![])) })
                    })
                    .await
                    .unwrap();
                assert!(
                    client
                        .cached::<Vec<String>, _>("grades/term-a".into(), false, |_| Box::pin(
                            async { panic!("empty result is a cache hit") }
                        ))
                        .await
                        .unwrap()
                        .result
                        .data
                        .is_empty()
                );
                schedule_cache::select_owner(&dir, Some("19100000")).unwrap();
                assert!(
                    client
                        .cached::<Vec<String>, _>("grades/term-a".into(), false, |_| Box::pin(
                            async { Err(failure()) }
                        ))
                        .await
                        .is_err()
                );
                let switched = dir.clone();
                assert!(
                    client
                        .cached("grades/term-a".into(), true, move |_| Box::pin(
                            async move {
                                schedule_cache::select_owner(&switched, Some("new-owner")).unwrap();
                                Ok(result(vec!["late".into()]))
                            }
                        ))
                        .await
                        .is_err()
                );
                schedule_cache::select_owner(&dir, None).unwrap();
                assert!(
                    schedule_cache::read_snapshot(&dir, "Gfixture", "grades/term-a")
                        .unwrap()
                        .is_none()
                );
                drop(client);
                std::fs::remove_dir_all(dir).unwrap();
            });
    }
}

macro_rules! cached_read {
    ($name:ident, $live:ident, $result:ty) => {
        impl UbaaClient {
            #[doc = "Read a private account snapshot, or refresh it from the original live API."]
            #[doc = "# Errors"]
            #[doc = "Returns ownership, storage or original live API errors; failed refresh keeps the old snapshot."]
            pub async fn $name(&mut self, refresh: bool) -> Result<CachedRead<$result>, RoutedError> {
                self.cached(concat!("v1/", stringify!($live)).into(), refresh,
                    |client| Box::pin(async move { client.$live().await })).await
            }
        }
    };
    ($name:ident, $live:ident, $result:ty, $arg:ident: $argty:ty) => {
        impl UbaaClient {
            #[doc = "Read a private account/query snapshot, or refresh it from the original live API."]
            #[doc = "# Errors"]
            #[doc = "Returns ownership, storage or original live API errors; failed refresh keeps the old snapshot."]
            pub async fn $name(&mut self, $arg: $argty, refresh: bool) -> Result<CachedRead<$result>, RoutedError> {
                let key = format!("v1/{}/{}", stringify!($live), $arg);
                let $arg = $arg.to_owned();
                self.cached(key, refresh, move |client| Box::pin(async move { client.$live(&$arg).await })).await
            }
        }
    };
}
cached_read!(cached_grade_overview, grade_overview, GradeOverview);
cached_read!(cached_exam_terms, exam_terms, Vec<Term>);
cached_read!(cached_schedule_terms, schedule_terms, Vec<Term>);
cached_read!(cached_grades, grades, GradeData, term: &str);
cached_read!(cached_exam_arrangement, exam_arrangement, ExamArrangement, term: &str);
cached_read!(cached_spoc_assignments, spoc_assignments, SpocAssignments);

impl UbaaClient {
    /// Read saved Judge summaries, with a separate key for expired assignments.
    /// # Errors
    /// Ownership, storage and live read errors preserve the prior snapshot.
    pub async fn cached_judge_assignments(
        &mut self,
        include_expired: bool,
        refresh: bool,
    ) -> Result<CachedRead<Vec<JudgeAssignmentSummary>>, RoutedError> {
        self.cached(
            format!("v1/judge/{include_expired}"),
            refresh,
            move |client| Box::pin(async move { client.judge_assignments(include_expired).await }),
        )
        .await
    }
}
