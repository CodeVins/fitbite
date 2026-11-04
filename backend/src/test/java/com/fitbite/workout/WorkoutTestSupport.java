package com.fitbite.workout;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fitbite.IntegrationTest;
import com.jayway.jsonpath.JsonPath;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.ResultActions;

/** 운동 API 테스트 공통 도구. 가상 데이터만 쓴다. */
abstract class WorkoutTestSupport extends IntegrationTest {

	static final String BENCH = "00000000-0000-0000-0000-000000000001";
	static final String SQUAT = "00000000-0000-0000-0000-000000000030";
	static final String START = "2026-11-04T01:00:00Z";
	static final String END = "2026-11-04T02:00:00Z";

	@Autowired
	JdbcTemplate jdbc;

	String tokenA;
	String tokenB;

	@BeforeEach
	void cleanAndSignup() throws Exception {
		// 기본 운동(owner null)은 남기고 사용자와 그 데이터만 지운다.
		jdbc.execute("delete from users");
		tokenA = signup("a@test.com");
		tokenB = signup("b@test.com");
	}

	String signup(String email) throws Exception {
		String json = """
				{"email":"%s","password":"password123","nickname":"tester","inviteCode":"test-invite","consentHealthData":true}"""
				.formatted(email);
		String body = mockMvc.perform(post("/api/v1/auth/signup").contentType(MediaType.APPLICATION_JSON).content(json))
				.andExpect(status().isCreated()).andReturn().getResponse().getContentAsString();
		return JsonPath.read(body, "$.accessToken");
	}

	String createCustomExercise(String token, UUID id) throws Exception {
		mockMvc.perform(put("/api/v1/exercises/" + id).header("Authorization", "Bearer " + token)
				.contentType(MediaType.APPLICATION_JSON)
				.content("{\"name\":\"내 운동\",\"equipment\":\"덤벨\",\"bodyPart\":\"ARMS\"}"))
				.andExpect(status().isOk());
		return id.toString();
	}

	static String set(UUID id, String exerciseId, int orderNo, String weight, int reps) {
		return setRaw(id.toString(), exerciseId, orderNo, weight, reps, "null");
	}

	static String setRaw(String id, String exerciseId, int orderNo, String weight, int reps, String rest) {
		return """
				{"id":%s,"exerciseId":%s,"orderNo":%d,"weightKg":%s,"reps":%d,"completedAt":"2026-11-04T01:10:00Z","restSeconds":%s}"""
				.formatted(q(id), q(exerciseId), orderNo, weight, reps, rest);
	}

	private static String q(String s) {
		return s == null ? "null" : "\"" + s + "\"";
	}

	static String bodyAt(String started, String ended, String memo, String... sets) {
		return """
				{"startedAt":%s,"endedAt":%s,"memo":%s,"sets":[%s]}"""
				.formatted(q(started), q(ended), q(memo), String.join(",", sets));
	}

	static String body(String... sets) {
		return bodyAt(START, END, null, sets);
	}

	ResultActions putWorkout(String token, UUID id, String json) throws Exception {
		return mockMvc.perform(put("/api/v1/workouts/" + id).header("Authorization", "Bearer " + token)
				.contentType(MediaType.APPLICATION_JSON).content(json));
	}

	int count(String sql) {
		return jdbc.queryForObject(sql, Integer.class);
	}

	int countAll(String table) {
		return count("select count(*) from " + table);
	}
}
