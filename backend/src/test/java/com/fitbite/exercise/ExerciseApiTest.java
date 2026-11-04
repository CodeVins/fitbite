package com.fitbite.exercise;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fitbite.IntegrationTest;
import com.jayway.jsonpath.JsonPath;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.ResultActions;

class ExerciseApiTest extends IntegrationTest {

	@Autowired
	JdbcTemplate jdbc;

	String tokenA;
	String tokenB;

	@BeforeEach
	void setUp() throws Exception {
		// 기본 운동(owner null)은 남기고 사용자와 그 운동만 지운다.
		jdbc.execute("delete from users");
		tokenA = signup("a@test.com");
		tokenB = signup("b@test.com");
	}

	private String signup(String email) throws Exception {
		String json = """
				{"email":"%s","password":"password123","nickname":"tester","inviteCode":"test-invite","consentHealthData":true}"""
				.formatted(email);
		String body = mockMvc.perform(post("/api/v1/auth/signup").contentType(MediaType.APPLICATION_JSON).content(json))
				.andExpect(status().isCreated()).andReturn().getResponse().getContentAsString();
		return JsonPath.read(body, "$.accessToken");
	}

	private ResultActions list(String token) throws Exception {
		return mockMvc.perform(get("/api/v1/exercises").header("Authorization", "Bearer " + token));
	}

	private ResultActions putEx(String token, UUID id, String name) throws Exception {
		return mockMvc.perform(put("/api/v1/exercises/" + id).header("Authorization", "Bearer " + token)
				.contentType(MediaType.APPLICATION_JSON)
				.content("{\"name\":\"%s\",\"equipment\":\"덤벨\",\"bodyPart\":\"ARMS\"}".formatted(name)));
	}

	private List<String> ids(String token) throws Exception {
		String body = list(token).andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
		return JsonPath.read(body, "$[*].id");
	}

	private String nameOf(UUID id) {
		return jdbc.queryForObject("select name from exercises where id = ?", String.class, id);
	}

	@Test
	void seed_hasAtLeast50_andEveryBodyPart() throws Exception {
		String body = list(tokenA).andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
		List<String> parts = JsonPath.read(body, "$[*].bodyPart");
		assertTrue(parts.size() >= 50);
		for (BodyPart p : BodyPart.values()) {
			assertTrue(parts.contains(p.name()), p.name());
		}
	}

	@Test
	void list_returnsSystemAndOwnOnly() throws Exception {
		UUID id = UUID.randomUUID();
		putEx(tokenA, id, "내 운동").andExpect(status().isOk());
		assertTrue(ids(tokenA).contains(id.toString()));
		assertFalse(ids(tokenB).contains(id.toString()));
	}

	@Test
	void put_createsCustom_thenUpdates_sameId() throws Exception {
		UUID id = UUID.randomUUID();
		putEx(tokenA, id, "처음").andExpect(status().isOk()).andExpect(jsonPath("$.custom").value(true))
				.andExpect(jsonPath("$.id").value(id.toString()));
		putEx(tokenA, id, "  바뀜  ").andExpect(status().isOk()).andExpect(jsonPath("$.name").value("바뀜"));
		assertEquals(1, jdbc.queryForObject("select count(*) from exercises where id = ?", Integer.class, id));
		assertEquals("바뀜", nameOf(id));
	}

	@Test
	void put_otherUsersExercise_404() throws Exception {
		UUID id = UUID.randomUUID();
		putEx(tokenA, id, "원본").andExpect(status().isOk());
		putEx(tokenB, id, "탈취").andExpect(status().isNotFound()).andExpect(jsonPath("$.code").value("NOT_FOUND"));
		assertEquals("원본", nameOf(id));
	}

	@Test
	void put_systemExercise_404() throws Exception {
		UUID id = UUID.fromString("00000000-0000-0000-0000-000000000001");
		String before = nameOf(id);
		putEx(tokenA, id, "변경").andExpect(status().isNotFound());
		assertEquals(before, nameOf(id));
	}

	@Test
	void put_blankName_400() throws Exception {
		putEx(tokenA, UUID.randomUUID(), "   ").andExpect(status().isBadRequest())
				.andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
	}

	@Test
	void put_nameOver50_400() throws Exception {
		putEx(tokenA, UUID.randomUUID(), "가".repeat(51)).andExpect(status().isBadRequest());
		putEx(tokenA, UUID.randomUUID(), "가".repeat(50)).andExpect(status().isOk());
	}

	@Test
	void list_excludesHidden() throws Exception {
		UUID id = UUID.fromString("00000000-0000-0000-0000-000000000002");
		assertTrue(ids(tokenA).contains(id.toString()));
		jdbc.update("update exercises set hidden_at = now() where id = ?", id);
		try {
			assertFalse(ids(tokenA).contains(id.toString()));
		} finally {
			jdbc.update("update exercises set hidden_at = null where id = ?", id);
		}
	}
}
