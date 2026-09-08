package cn.edu.ubaa.api.feature

import cn.edu.ubaa.model.dto.GraduateSchedule
import io.ktor.client.HttpClient
import io.ktor.client.request.*
import io.ktor.client.statement.HttpResponse
import io.ktor.client.statement.bodyAsText
import io.ktor.http.*
import kotlinx.coroutines.CancellationException
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json

open class GraduateScheduleLoadException(message: String, val responseBody: String? = null) :
    Exception(message)

class GraduateScheduleAuthenticationException(stage: String, status: Int) :
    GraduateScheduleLoadException("$stage：仍停留在统一认证登录页（HTTP $status），请退出账号后重新登录")

/** 复用调用方的会话和直连/WebVPN URL 转换，不携带浏览器复制的 Cookie。 */
suspend fun fetchGraduateSchedule(
    client: HttpClient,
    upstreamUrl: (String) -> String,
): GraduateSchedule {
  val base = "https://yjsxk.buaa.edu.cn/yjsxkapp/sys/xsxkappbuaa"
  // 官方 index.html 的“点击进入登录”入口。course.html 是公开静态页，不建立 SSO 会话。
  graduateStage("研究生登录") {
    checkGraduateResponse(client.get(upstreamUrl("$base/*default/index.do")), "研究生登录", upstreamUrl)
  }
  val body =
      graduateStage("研究生课表请求") {
        val response =
            client.get(upstreamUrl("$base/xsxkCourse/loadKbxx.do")) {
              parameter("sfyx", "0")
              header(HttpHeaders.Accept, "application/json, text/javascript, */*; q=0.01")
              header("X-Requested-With", "XMLHttpRequest")
              header(HttpHeaders.Referrer, upstreamUrl("$base/course.html"))
            }
        checkGraduateResponse(response, "研究生课表请求", upstreamUrl).also {
          if (!it.trimStart().startsWith("{")) {
            throw GraduateScheduleLoadException(
                "研究生课表请求：HTTP ${response.status.value}，返回的不是 JSON 课表"
            )
          }
        }
      }
  return graduateStage("研究生课表解析") {
    try {
      GraduateSchedule.parse(body)
    } catch (e: SerializationException) {
      throw GraduateScheduleLoadException(
          "研究生课表解析：${jsonFailureDiagnostic(body, e)}",
          responseBody = body,
      )
    }
  }
}

/** 异常原文可能带整段响应；只提取数字位置和固定分类，不输出姓名、课程或会话内容。 */
internal fun jsonFailureDiagnostic(body: String, error: SerializationException): String {
  val message = error.message.orEmpty()
  val offset =
      Regex("(?:offset|position)\\s+(\\d+)").find(message)?.groupValues?.get(1)?.toIntOrNull()
  val reason =
      when {
        message.contains("EOF", ignoreCase = true) -> "内容结束或尾部异常"
        message.contains("trailing comma", ignoreCase = true) -> "多余逗号"
        message.contains("escape", ignoreCase = true) -> "转义异常"
        message.contains("quotation", ignoreCase = true) -> "引号异常"
        else -> "JSON 语法异常"
      }
  val character =
      when (val c = offset?.let(body::getOrNull)) {
        null -> "未知/末尾"
        '{',
        '}',
        '[',
        ']',
        ':',
        ',',
        '"',
        '\\' -> "结构符号 U+${c.code.toString(16).uppercase().padStart(4, '0')}"
        in '0'..'9' -> "数字"
        in 'a'..'z',
        in 'A'..'Z' -> "字母"
        else -> if (c.isWhitespace()) "空白" else "其他字符"
      }
  val lenientReadable = runCatching { Json { isLenient = true }.parseToJsonElement(body) }.isSuccess
  return "$reason；字符数=${body.length}；位置=${offset ?: "未知"}；字符=$character；对象结束=${body.trimEnd().endsWith('}')}；宽松解析=$lenientReadable"
}

private suspend fun checkGraduateResponse(
    response: HttpResponse,
    stage: String,
    upstreamUrl: (String) -> String,
): String {
  val body = response.bodyAsText()
  val finalUrl = response.call.request.url
  val loginUrl = Url(upstreamUrl("https://sso.buaa.edu.cn/login"))
  if (
      response.status == HttpStatusCode.Unauthorized ||
          (finalUrl.host == loginUrl.host && finalUrl.encodedPath == loginUrl.encodedPath) ||
          body.contains("<title>CAS Login</title>", ignoreCase = true) ||
          body.contains("name=\"execution\"") ||
          body.contains("name='execution'")
  ) {
    throw GraduateScheduleAuthenticationException(stage, response.status.value)
  }
  if (response.status != HttpStatusCode.OK) {
    throw GraduateScheduleLoadException("$stage：HTTP ${response.status.value}")
  }
  return body
}

private suspend fun <T> graduateStage(stage: String, block: suspend () -> T): T =
    try {
      block()
    } catch (e: CancellationException) {
      throw e
    } catch (e: GraduateScheduleLoadException) {
      throw e
    } catch (e: Exception) {
      // 不显示异常正文：JSON 解析器可能在异常中包含姓名、学号或响应片段。
      throw GraduateScheduleLoadException("$stage：${e::class.simpleName}")
    }
