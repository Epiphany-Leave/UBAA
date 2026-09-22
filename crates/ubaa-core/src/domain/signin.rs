use serde::{Deserialize, Serialize};

use super::ActionEligibility;

/// Parsed day in a weekly display snapshot. Writes must re-fetch current authority.
#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct SigninDay {
    pub date: String,
    pub is_future: bool,
    pub classes: Vec<SigninClass>,
}

/// 一条 iClass 课堂签到状态。
#[derive(Clone, Debug, Default, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SigninClass {
    /// Reason the time window or upstream authority prevents signing in.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub availability_message: Option<String>,
    /// 上游课程安排标识。
    pub course_id: String,
    /// 课程显示名称。
    pub course_name: String,
    /// 上课开始时间。
    pub class_begin_time: String,
    /// 上课结束时间。
    pub class_end_time: String,
    /// 上游原始签到状态；缺失或畸形时为 `None`，不得推断为未签到。
    pub sign_status: Option<i32>,
    /// Core 根据今日响应判定的签到资格；`Unknown` 必须按拒绝处理。
    pub signin_eligibility: ActionEligibility,
    /// Core 已核对的课程安排目标；空标识不会成为写目标。
    pub signin_target: Option<String>,
}

/// 课堂签到写操作结果。
#[derive(Clone, Debug, Default, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SigninActionResult {
    pub code: i32,
    pub success: bool,
    pub message: String,
}
