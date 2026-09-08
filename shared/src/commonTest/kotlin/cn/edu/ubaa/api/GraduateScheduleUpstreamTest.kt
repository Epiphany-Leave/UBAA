package cn.edu.ubaa.api

import cn.edu.ubaa.api.feature.*
import io.ktor.client.HttpClient
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpStatusCode
import kotlin.test.*
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.test.runTest

class GraduateScheduleUpstreamTest {
  @Test
  fun authenticatesThroughOfficialEntryBeforeLoadingCourses() = runTest {
    val paths = mutableListOf<String>()
    val client =
        HttpClient(
            MockEngine { request ->
              paths.add(request.url.encodedPath)
              if (paths.size == 1) {
                assertTrue(request.url.encodedPath.endsWith("/*default/index.do"))
                respond("<html>已登录</html>")
              } else {
                assertTrue(request.url.encodedPath.endsWith("/xsxkCourse/loadKbxx.do"))
                assertEquals("0", request.url.parameters["sfyx"])
                respond("""{"results":[],"xkjgList":[],"rqpkjgallList":[]}""")
              }
            }
        )
    try {
      assertTrue(fetchGraduateSchedule(client) { it }.terms().isEmpty())
      assertEquals(2, paths.size)
    } finally {
      client.close()
    }
  }

  @Test
  fun identifiesLoginPageEvenWhenStatusIs200() = runTest {
    val client =
        HttpClient(MockEngine { respond("<html><title>CAS Login</title>private-token</html>") })
    try {
      val error =
          assertFailsWith<GraduateScheduleAuthenticationException> {
            fetchGraduateSchedule(client) { it }
          }
      assertTrue(error.message!!.contains("研究生登录"))
      assertFalse(error.message!!.contains("private-token"))
    } finally {
      client.close()
    }
  }

  @Test
  fun reportsRequestStageWithoutExposingResponse() = runTest {
    val client =
        HttpClient(
            MockEngine { request ->
              if (request.url.encodedPath.endsWith("/loadKbxx.do"))
                  respond("private-token", HttpStatusCode.ServiceUnavailable)
              else respond("<html>已登录</html>")
            }
        )
    try {
      val error =
          assertFailsWith<GraduateScheduleLoadException> { fetchGraduateSchedule(client) { it } }
      assertTrue(error.message!!.contains("研究生课表请求：HTTP 503"))
      assertFalse(error.message!!.contains("private-token"))
    } finally {
      client.close()
    }
  }

  @Test
  fun reportsParserStageWithoutExposingResponse() = runTest {
    val client =
        HttpClient(
            MockEngine { request ->
              respond(
                  if (request.url.encodedPath.endsWith("/loadKbxx.do")) "{private-token"
                  else "<html>已登录</html>"
              )
            }
        )
    try {
      val error =
          assertFailsWith<GraduateScheduleLoadException> { fetchGraduateSchedule(client) { it } }
      assertTrue(error.message!!.startsWith("研究生课表解析："))
      assertTrue(error.message!!.contains("字符数=14"))
      assertTrue(error.message!!.contains("位置="))
      assertEquals("{private-token", error.responseBody)
      assertFalse(error.message!!.contains("private-token"))
    } finally {
      client.close()
    }
  }

  @Test
  fun diagnosticsNeverIncludePayloadOrExceptionText() {
    val payload = "{\"name\":\"private-person\",\"token\":\"private-token\""
    val error =
        kotlinx.serialization.SerializationException(
            "Unexpected JSON token at offset 47: private-token. JSON input: $payload"
        )
    val diagnostic = jsonFailureDiagnostic(payload, error)
    assertTrue(diagnostic.contains("位置=47"))
    assertTrue(diagnostic.contains("对象结束=false"))
    assertTrue(diagnostic.contains("宽松解析=false"))
    assertFalse(diagnostic.contains("private"))
    val unquoted = "{results:[],xkjgList:[],rqpkjgallList:[]}"
    val unquotedError =
        assertFailsWith<kotlinx.serialization.SerializationException> {
          kotlinx.serialization.json.Json.parseToJsonElement(unquoted)
        }
    assertTrue(jsonFailureDiagnostic(unquoted, unquotedError).contains("宽松解析=true"))
  }

  @Test
  fun propagatesCancellation() = runTest {
    val client = HttpClient(MockEngine { throw CancellationException("cancelled") })
    try {
      assertFailsWith<CancellationException> { fetchGraduateSchedule(client) { it } }
    } finally {
      client.close()
    }
  }
}
