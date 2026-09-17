//! 课表、考试、成绩与空教室只读入口。

use crate::domain::{
    ClassroomQuery, ExamArrangement, GradeData, GradeOverview, ReadonlyFeature, Term, TodayClass,
    Week, WeeklySchedule,
};

use super::super::client::UbaaClient;
use super::super::routing::{invalid_input, routed_error};
use super::super::types::{Operation, RoutedResult};

impl UbaaClient {
    async fn ensure_academic_identity(
        &mut self,
        resolution: crate::connection::RouteResolution,
    ) -> std::result::Result<(), super::super::types::RoutedError> {
        let runtime = self.runtime_for(resolution.mode);
        if runtime.account_name().is_none() {
            let result = crate::features::user::get_user_info(runtime, &mut || {}).await;
            self.finish_routed(resolution, result)?;
        }
        if crate::features::schedule::graduate_account(self.runtime_for(resolution.mode)).is_none()
        {
            return Err(routed_error(
                invalid_input(
                    "无法根据学号确认本科或研究生身份；继续教育及其他学号暂不支持自动教务查询",
                ),
                resolution,
            ));
        }
        Ok(())
    }

    /// Read the active account's saved schedules without network access.
    /// # Errors
    /// Returns an error when private storage cannot be read.
    pub fn saved_schedule(&self) -> crate::error::Result<crate::domain::SavedSchedule> {
        self.config_dir.as_ref().map_or_else(
            || Ok(crate::domain::SavedSchedule::default()),
            |dir| crate::session::schedule_cache::read(dir),
        )
    }

    /// Manually refresh one complete semester; failure preserves the previous data.
    /// # Errors
    /// Authentication, upstream or storage failures leave the previous semester intact.
    pub async fn update_saved_schedule(
        &mut self,
        term: Option<&str>,
    ) -> crate::error::Result<crate::domain::SavedSchedule> {
        let dir = self
            .config_dir
            .clone()
            .ok_or_else(|| invalid_input("private storage unavailable"))?;
        let user = self
            .get_user_info()
            .await
            .map_err(|error| error.error)?
            .data;
        let owner = user
            .username
            .filter(|name| !name.trim().is_empty())
            .map(|name| name.trim().to_owned())
            .ok_or_else(|| invalid_input("无法确认课表所属账号"))?;
        crate::session::schedule_cache::select_owner(&dir, Some(&owner))?;
        let resolution = self
            .resolve_operation(Operation::Feature(ReadonlyFeature::Schedule))
            .map_err(|error| error.error)?;
        self.ensure_academic_identity(resolution)
            .await
            .map_err(|error| error.error)?;
        let result =
            crate::features::schedule::import_semester(self.runtime_for(resolution.mode), term)
                .await;
        let imported = self
            .finish_routed(resolution, result)
            .map_err(|error| error.error)?
            .data;
        self.guard_latest_session_ownership()?;
        crate::session::schedule_cache::save(&dir, &owner, imported.0, imported.1)?;
        self.saved_schedule()
    }
    /// 读取考试自身的可用学期。
    /// # Errors
    /// 路由、认证或上游协议失败时返回安全错误。
    pub async fn exam_terms(&mut self) -> RoutedResult<Vec<Term>> {
        let resolution = self.resolve_operation(Operation::Feature(ReadonlyFeature::Exam))?;
        self.ensure_academic_identity(resolution).await?;
        let result =
            crate::features::schedule::get_exam_terms(self.runtime_for(resolution.mode)).await;
        self.finish_routed(resolution, result)
    }

    /// 读取研究生完整成绩及统计；本科返回 graduate=false。
    /// # Errors
    /// 路由、认证、分页或上游协议失败时不返回部分成绩。
    pub async fn grade_overview(&mut self) -> RoutedResult<GradeOverview> {
        let resolution = self.resolve_operation(Operation::Feature(ReadonlyFeature::Grades))?;
        self.ensure_academic_identity(resolution).await?;
        let result = crate::features::grades::get_overview(self.runtime_for(resolution.mode)).await;
        self.finish_routed(resolution, result)
    }
    /// 通过课表路线策略读取可用学期。
    ///
    /// # Errors
    ///
    /// 路线解析、会话校验、上游请求或响应解析失败时返回错误。
    pub async fn schedule_terms(&mut self) -> RoutedResult<Vec<Term>> {
        let resolution = self.resolve_operation(Operation::Feature(ReadonlyFeature::Schedule))?;
        self.ensure_academic_identity(resolution).await?;
        let result = crate::features::schedule::get_terms(self.runtime_for(resolution.mode)).await;
        self.finish_routed(resolution, result)
    }

    /// 通过课表路线策略读取一个学期的教学周。
    ///
    /// # Errors
    ///
    /// 路线解析、会话校验、上游请求或响应解析失败时返回错误。
    pub async fn schedule_weeks(&mut self, term: &str) -> RoutedResult<Vec<Week>> {
        let resolution = self.resolve_operation(Operation::Feature(ReadonlyFeature::Schedule))?;
        self.ensure_academic_identity(resolution).await?;
        let result =
            crate::features::schedule::get_weeks(self.runtime_for(resolution.mode), term).await;
        self.finish_routed(resolution, result)
    }

    /// 通过课表路线策略读取指定周课表。
    ///
    /// # Errors
    ///
    /// 参数无效，或路线解析、会话校验、上游请求或响应解析失败时返回错误。
    pub async fn schedule_week(&mut self, term: &str, week: i32) -> RoutedResult<WeeklySchedule> {
        let resolution = self.resolve_operation(Operation::Feature(ReadonlyFeature::Schedule))?;
        if term.trim().is_empty() || week <= 0 {
            return Err(routed_error(
                invalid_input("term and positive week are required"),
                resolution,
            ));
        }
        self.ensure_academic_identity(resolution).await?;
        let result =
            crate::features::schedule::get_week(self.runtime_for(resolution.mode), term, week)
                .await;
        self.finish_routed(resolution, result)
    }

    /// 通过课表路线策略读取今日课表。
    ///
    /// # Errors
    ///
    /// 路线解析、会话校验、上游请求或响应解析失败时返回错误。
    pub async fn schedule_today(&mut self) -> RoutedResult<Vec<TodayClass>> {
        let resolution = self.resolve_operation(Operation::Feature(ReadonlyFeature::Schedule))?;
        self.ensure_academic_identity(resolution).await?;
        let result = crate::features::schedule::get_today(self.runtime_for(resolution.mode)).await;
        self.finish_routed(resolution, result)
    }

    /// 通过考试路线策略读取一个学期的考试安排。
    ///
    /// # Errors
    ///
    /// 参数无效，或路线解析、会话校验、上游请求或响应解析失败时返回错误。
    pub async fn exam_arrangement(&mut self, term: &str) -> RoutedResult<ExamArrangement> {
        let resolution = self.resolve_operation(Operation::Feature(ReadonlyFeature::Exam))?;
        if term.trim().is_empty() {
            return Err(routed_error(invalid_input("term is required"), resolution));
        }
        self.ensure_academic_identity(resolution).await?;
        let result =
            crate::features::schedule::get_exam(self.runtime_for(resolution.mode), term).await;
        self.finish_routed(resolution, result)
    }

    /// 通过成绩路线策略读取一个学期的成绩。
    ///
    /// # Errors
    ///
    /// 路线解析、会话校验、上游请求或响应解析失败时返回错误。
    pub async fn grades(&mut self, term: &str) -> RoutedResult<GradeData> {
        let resolution = self.resolve_operation(Operation::Feature(ReadonlyFeature::Grades))?;
        self.ensure_academic_identity(resolution).await?;
        let result =
            crate::features::grades::get_grades(self.runtime_for(resolution.mode), term).await;
        self.finish_routed(resolution, result)
    }

    /// 通过空教室路线策略查询可用教室。
    ///
    /// # Errors
    ///
    /// 路线解析、会话校验、上游请求或响应解析失败时返回错误。
    pub async fn classroom_search(
        &mut self,
        campus_id: i32,
        date: &str,
    ) -> RoutedResult<ClassroomQuery> {
        let resolution = self.resolve_operation(Operation::Feature(ReadonlyFeature::Classroom))?;
        let result =
            crate::features::classroom::search(self.runtime_for(resolution.mode), campus_id, date)
                .await;
        self.finish_routed(resolution, result)
    }
}
