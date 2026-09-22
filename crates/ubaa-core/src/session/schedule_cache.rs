use super::{
    file_safety::{
        create_temporary_file, open_existing_session_file, prevent_symlink_following,
        restrict_file_creation, session_error, sync_directory, validate_directory,
        validate_open_regular_file,
    },
    storage::{TemporaryFile, lock_file},
};
use crate::{
    domain::{SavedSchedule, SavedSemester, Term},
    error::Result,
};
use serde::{Deserialize, Serialize};
use std::{
    collections::BTreeMap,
    fs::{self, OpenOptions},
    io::{Read, Write},
    path::Path,
};

const MAX_BYTES: u64 = 16 * 1024 * 1024;

#[derive(Default, Serialize, Deserialize)]
struct Cache {
    active: Option<String>,
    accounts: BTreeMap<String, SavedSchedule>,
    #[serde(default)]
    reads: BTreeMap<String, BTreeMap<String, ReadSnapshot>>,
}

#[derive(Clone, Serialize, Deserialize)]
pub(crate) struct ReadSnapshot {
    pub data: serde_json::Value,
    pub resolution: crate::connection::RouteResolution,
    pub saved_at: String,
}

pub(crate) fn active_owner(dir: &Path) -> Result<Option<String>> {
    access(dir, false, |cache| Ok(cache.active.clone()))
}

pub(crate) fn read_snapshot(dir: &Path, owner: &str, key: &str) -> Result<Option<ReadSnapshot>> {
    access(dir, false, |cache| {
        if cache.active.as_deref() != Some(owner) {
            return Ok(None);
        }
        Ok(cache
            .reads
            .get(owner)
            .and_then(|reads| reads.get(key))
            .cloned())
    })
}

pub(crate) fn save_snapshot(
    dir: &Path,
    owner: &str,
    key: &str,
    snapshot: ReadSnapshot,
) -> Result<()> {
    access(dir, true, |cache| {
        if cache.active.as_deref() != Some(owner) {
            return Err(session_error("账号已切换，未保存数据"));
        }
        cache
            .reads
            .entry(owner.to_owned())
            .or_default()
            .insert(key.to_owned(), snapshot);
        Ok(())
    })
}

fn access<T>(
    dir: &Path,
    write: bool,
    operation: impl FnOnce(&mut Cache) -> Result<T>,
) -> Result<T> {
    validate_directory(dir)?;
    let mut options = OpenOptions::new();
    options.read(true).write(true).create(true);
    restrict_file_creation(&mut options);
    prevent_symlink_following(&mut options);
    let lock = options
        .open(dir.join(".schedule.lock"))
        .map_err(|_| session_error("无法打开课表缓存锁"))?;
    validate_open_regular_file(&lock, "课表缓存锁无效", "无法检查课表缓存锁")?;
    lock_file(&lock).map_err(|_| session_error("无法锁定课表缓存"))?;
    let path = dir.join("schedule-v1.json");
    let mut cache = match open_existing_session_file(&path)? {
        None => Cache::default(),
        Some(file) => {
            let mut bytes = Vec::new();
            file.take(MAX_BYTES + 1)
                .read_to_end(&mut bytes)
                .map_err(|_| session_error("无法读取课表缓存"))?;
            if bytes.len() as u64 > MAX_BYTES {
                return Err(session_error("课表缓存过大"));
            }
            serde_json::from_slice(&bytes).map_err(|_| session_error("课表缓存损坏"))?
        }
    };
    let result = operation(&mut cache)?;
    if write {
        let bytes = serde_json::to_vec(&cache).map_err(|_| session_error("无法编码课表缓存"))?;
        if bytes.len() as u64 > MAX_BYTES {
            return Err(session_error("课表缓存过大"));
        }
        let (temp_path, mut file) = create_temporary_file(dir)?;
        let mut cleanup = TemporaryFile::new(temp_path);
        file.write_all(&bytes)
            .and_then(|()| file.sync_all())
            .map_err(|_| session_error("无法保存课表缓存"))?;
        drop(file);
        fs::rename(cleanup.path(), path).map_err(|_| session_error("无法替换课表缓存"))?;
        cleanup.persisted();
        sync_directory(dir)?;
    }
    Ok(result)
}

pub(crate) fn select_owner(dir: &Path, owner: Option<&str>) -> Result<()> {
    access(dir, true, |cache| {
        cache.active = owner.map(str::to_owned);
        Ok(())
    })
}

pub(crate) fn begin_login(dir: &Path, username: &str) -> Result<()> {
    access(dir, true, |cache| {
        if cache.active.as_deref() != Some(username) {
            cache.active = None;
        }
        Ok(())
    })
}

pub(crate) fn read(dir: &Path) -> Result<SavedSchedule> {
    access(dir, false, |cache| {
        let saved = cache
            .active
            .as_ref()
            .and_then(|owner| cache.accounts.get(owner))
            .cloned()
            .unwrap_or_default();
        for semester in &saved.semesters {
            validate(&saved.terms, semester)?;
        }
        Ok(saved)
    })
}

pub(crate) fn validate(terms: &[Term], semester: &SavedSemester) -> Result<()> {
    if !terms.iter().any(|t| t.item_code == semester.term)
        || semester.weeks.len() != semester.schedules.len()
        || semester.weeks.len() > 128
    {
        return Err(session_error("课表周次不完整，保留旧课表"));
    }
    let mut numbers = std::collections::BTreeSet::new();
    for week in &semester.weeks {
        let from = schedule_date(&week.start_date);
        let to = schedule_date(&week.end_date);
        if week.term != semester.term
            || week.serial_number <= 0
            || !numbers.insert(week.serial_number)
            || !matches!((from, to), (Some(a), Some(b)) if a <= b)
        {
            return Err(session_error("课表日期或学期不一致，保留旧课表"));
        }
    }
    Ok(())
}

pub(crate) fn schedule_date(value: &str) -> Option<chrono::NaiveDate> {
    let value = value.trim();
    chrono::NaiveDate::parse_from_str(value, "%Y-%m-%d")
        .ok()
        .or_else(|| {
            chrono::NaiveDateTime::parse_from_str(value, "%Y-%m-%d %H:%M:%S%.f")
                .ok()
                .map(|v| v.date())
        })
        .or_else(|| {
            chrono::NaiveDateTime::parse_from_str(value, "%Y-%m-%dT%H:%M:%S%.f")
                .ok()
                .map(|v| v.date())
        })
        .or_else(|| {
            chrono::DateTime::parse_from_rfc3339(value)
                .ok()
                .map(|v| v.with_timezone(&chrono_tz::Asia::Shanghai).date_naive())
        })
}

pub(crate) fn save(
    dir: &Path,
    owner: &str,
    terms: Vec<Term>,
    semester: SavedSemester,
) -> Result<()> {
    validate(&terms, &semester)?;
    access(dir, true, |cache| {
        if cache.active.as_deref() != Some(owner) {
            return Err(session_error("账号已切换，未保存课表"));
        }
        let library = cache.accounts.entry(owner.to_owned()).or_default();
        let mut terms = terms;
        for old in &library.terms {
            if !terms.iter().any(|term| term.item_code == old.item_code) {
                let mut old = old.clone();
                old.selected = false;
                terms.push(old);
            }
        }
        library.terms = terms;
        library
            .semesters
            .retain(|saved| saved.term != semester.term);
        library.semesters.insert(0, semester);
        Ok(())
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn undergraduate_student_code_and_datetime_weeks_are_valid() {
        let term = Term {
            item_code: "2026-2027-1".into(),
            ..Default::default()
        };
        let mut semester = SavedSemester {
            term: term.item_code.clone(),
            weeks: vec![crate::domain::Week {
                term: term.item_code.clone(),
                serial_number: 1,
                start_date: "2026-09-07 00:00:00".into(),
                end_date: "2026-09-13T23:59:59".into(),
                ..Default::default()
            }],
            schedules: vec![crate::domain::WeeklySchedule {
                code: "19000001".into(),
                ..Default::default()
            }],
            ..Default::default()
        };
        assert!(validate(std::slice::from_ref(&term), &semester).is_ok());
        semester.weeks[0].end_date = "2026-09-06".into();
        assert!(validate(std::slice::from_ref(&term), &semester).is_err());
        semester.weeks[0].end_date = "2026-09-13garbage".into();
        assert!(validate(&[term], &semester).is_err());
    }

    #[test]
    fn complete_semester_only_account_isolation_and_logout() {
        let dir = std::env::temp_dir().join(format!(
            "ubaa-schedule-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        std::fs::create_dir(&dir).unwrap();
        select_owner(&dir, Some("a")).unwrap();
        let term = crate::domain::Term {
            item_code: "20261".into(),
            ..Default::default()
        };
        let semester = crate::domain::SavedSemester {
            term: term.item_code.clone(),
            weeks: vec![crate::domain::Week {
                term: term.item_code.clone(),
                serial_number: 1,
                start_date: "2026-09-07".into(),
                end_date: "2026-09-13".into(),
                ..Default::default()
            }],
            schedules: vec![crate::domain::WeeklySchedule {
                code: term.item_code.clone(),
                ..Default::default()
            }],
            ..Default::default()
        };
        save(&dir, "a", vec![term.clone()], semester.clone()).unwrap();
        begin_login(&dir, "a").unwrap();
        assert_eq!(read(&dir).unwrap().semesters, vec![semester.clone()]);
        begin_login(&dir, "b").unwrap();
        assert!(read(&dir).unwrap().semesters.is_empty());
        select_owner(&dir, Some("a")).unwrap();
        let mut invalid = semester.clone();
        invalid.schedules.clear();
        assert!(save(&dir, "a", vec![term], invalid).is_err());
        assert_eq!(read(&dir).unwrap().semesters, vec![semester.clone()]);
        select_owner(&dir, Some("b")).unwrap();
        assert!(read(&dir).unwrap().semesters.is_empty());
        assert!(save(&dir, "a", vec![], semester.clone()).is_err());
        select_owner(&dir, Some("a")).unwrap();
        assert_eq!(read(&dir).unwrap().semesters, vec![semester]);
        select_owner(&dir, None).unwrap();
        assert!(read(&dir).unwrap().semesters.is_empty());
        std::fs::remove_dir_all(dir).unwrap();
    }
}
