package com.fitbite.workout;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.ResultActions;

class WorkoutApiTest extends WorkoutTestSupport {

	private static final String WEIGHT_999 = "select count(*) from workout_sets where weight_kg = 999";

	private ResultActions getOne(String token, UUID id) throws Exception {
		return mockMvc.perform(get("/api/v1/workouts/" + id).header("Authorization", "Bearer " + token));
	}

	private ResultActions del(String token, UUID id) throws Exception {
		return mockMvc.perform(delete("/api/v1/workouts/" + id).header("Authorization", "Bearer " + token));
	}

	private ResultActions list(String token, String from, String to) throws Exception {
		return mockMvc.perform(
				get("/api/v1/workouts?from=" + from + "&to=" + to).header("Authorization", "Bearer " + token));
	}

	@Test
	void put_savesSessionAndSets_inOrder() throws Exception {
		UUID id = UUID.randomUUID();
		// 일부러 orderNo 역순으로 보낸다.
		putWorkout(tokenA, id, bodyAt(START, END, "가슴 운동", set(UUID.randomUUID(), SQUAT, 2, "100", 5),
				set(UUID.randomUUID(), BENCH, 1, "60", 8))).andExpect(status().isOk())
				.andExpect(jsonPath("$.id").value(id.toString())).andExpect(jsonPath("$.memo").value("가슴 운동"))
				.andExpect(jsonPath("$.sets[0].orderNo").value(1))
				.andExpect(jsonPath("$.sets[0].exerciseName").value("벤치 프레스"))
				.andExpect(jsonPath("$.sets[1].exerciseName").value("백 스쿼트"));
		getOne(tokenA, id).andExpect(status().isOk()).andExpect(jsonPath("$.sets.length()").value(2))
				.andExpect(jsonPath("$.sets[0].orderNo").value(1)).andExpect(jsonPath("$.sets[1].orderNo").value(2));
	}

	@Test
	void put_sameRequestTwice_noDuplicates() throws Exception {
		UUID id = UUID.randomUUID();
		String json = body(set(UUID.randomUUID(), BENCH, 1, "60", 8), set(UUID.randomUUID(), BENCH, 2, "60", 8));
		putWorkout(tokenA, id, json).andExpect(status().isOk());
		putWorkout(tokenA, id, json).andExpect(status().isOk());
		assertEquals(1, countAll("workout_sessions"));
		assertEquals(2, countAll("workout_sets"));
	}

	@Test
	void put_withSetRemoved_deletesThatSet() throws Exception {
		UUID id = UUID.randomUUID();
		UUID keep = UUID.randomUUID();
		putWorkout(tokenA, id, body(set(keep, BENCH, 1, "60", 8), set(UUID.randomUUID(), BENCH, 2, "60", 8)))
				.andExpect(status().isOk());
		putWorkout(tokenA, id, body(set(keep, BENCH, 1, "62.5", 8))).andExpect(status().isOk())
				.andExpect(jsonPath("$.sets.length()").value(1));
		assertEquals(1, countAll("workout_sets"));
	}

	@Test
	void put_otherUsersSessionId_404_andNotOverwritten() throws Exception {
		UUID id = UUID.randomUUID();
		putWorkout(tokenA, id,
				body(set(UUID.randomUUID(), BENCH, 1, "60", 8), set(UUID.randomUUID(), BENCH, 2, "60", 8)))
				.andExpect(status().isOk());
		putWorkout(tokenB, id,
				body(set(UUID.randomUUID(), SQUAT, 1, "999", 1), set(UUID.randomUUID(), SQUAT, 2, "999", 1)))
				.andExpect(status().isNotFound()).andExpect(jsonPath("$.code").value("NOT_FOUND"));
		assertEquals(2, countAll("workout_sets"));
		assertEquals(0, count(WEIGHT_999));
	}

	@Test
	void put_otherUsersCustomExercise_404() throws Exception {
		String ex = createCustomExercise(tokenA, UUID.randomUUID());
		putWorkout(tokenB, UUID.randomUUID(), body(set(UUID.randomUUID(), ex, 1, "10", 10)))
				.andExpect(status().isNotFound());
		assertEquals(0, countAll("workout_sessions"));
	}

	@Test
	void put_setIdBelongingToOtherSession_409() throws Exception {
		UUID shared = UUID.randomUUID();
		putWorkout(tokenB, UUID.randomUUID(), body(set(shared, BENCH, 1, "60", 8))).andExpect(status().isOk());
		// 다른 사용자의 세트 ID
		putWorkout(tokenA, UUID.randomUUID(), body(set(shared, SQUAT, 1, "999", 1))).andExpect(status().isConflict())
				.andExpect(jsonPath("$.code").value("CONFLICT"));
		// 같은 사용자의 다른 세션 세트 ID
		UUID mySet = UUID.randomUUID();
		putWorkout(tokenA, UUID.randomUUID(), body(set(mySet, BENCH, 1, "50", 5))).andExpect(status().isOk());
		putWorkout(tokenA, UUID.randomUUID(), body(set(mySet, SQUAT, 1, "999", 1))).andExpect(status().isConflict());
		assertEquals(0, count(WEIGHT_999));
		assertEquals(2, countAll("workout_sets"));
		assertEquals(2, countAll("workout_sessions"));
	}

	@Test
	void put_invalidValues_400() throws Exception {
		UUID a = UUID.randomUUID();
		UUID b = UUID.randomUUID();
		String ok = set(a, BENCH, 1, "60", 8);
		List<String> bad = List.of(body(set(a, BENCH, 1, "-1", 8)), body(set(a, BENCH, 1, "1000.01", 8)),
				body(set(a, BENCH, 1, "60.123", 8)), body(set(a, BENCH, 1, "60", 0)),
				body(set(a, BENCH, 1, "60", 1001)), body(setRaw(a.toString(), BENCH, 1, "60", 8, "-1")),
				body(setRaw(null, BENCH, 1, "60", 8, "null")), body(setRaw(a.toString(), null, 1, "60", 8, "null")),
				bodyAt(END, START, null, ok), bodyAt(START, null, null, ok), bodyAt(START, END, "x".repeat(501), ok),
				body(), body(set(a, BENCH, 1, "60", 8), set(b, BENCH, 1, "60", 8)),
				body(set(a, BENCH, 1, "60", 8), set(a, BENCH, 2, "60", 8)));
		for (String json : bad) {
			putWorkout(tokenA, UUID.randomUUID(), json).andExpect(status().isBadRequest())
					.andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
		}
		assertEquals(0, countAll("workout_sessions"));
	}

	@Test
	void put_fractionalWeight_roundTrips() throws Exception {
		UUID id = UUID.randomUUID();
		putWorkout(tokenA, id,
				body(set(UUID.randomUUID(), BENCH, 1, "2.5", 8), set(UUID.randomUUID(), BENCH, 2, "1.25", 8)))
				.andExpect(status().isOk()).andExpect(jsonPath("$.sets[0].weightKg").value(2.5))
				.andExpect(jsonPath("$.sets[1].weightKg").value(1.25));
		getOne(tokenA, id).andExpect(jsonPath("$.sets[0].weightKg").value(2.5))
				.andExpect(jsonPath("$.sets[1].weightKg").value(1.25));
	}

	@Test
	void put_nullRestSeconds_allowed() throws Exception {
		putWorkout(tokenA, UUID.randomUUID(), body(set(UUID.randomUUID(), BENCH, 1, "60", 8)))
				.andExpect(status().isOk()).andExpect(jsonPath("$.sets[0].restSeconds").doesNotExist());
	}

	@Test
	void get_otherUsersSession_404_sameBodyAsMissing() throws Exception {
		UUID id = UUID.randomUUID();
		putWorkout(tokenA, id, body(set(UUID.randomUUID(), BENCH, 1, "60", 8))).andExpect(status().isOk());
		String other = getOne(tokenB, id).andExpect(status().isNotFound())
				.andExpect(jsonPath("$.code").value("NOT_FOUND")).andReturn().getResponse().getContentAsString();
		UUID none = UUID.randomUUID();
		String missing = getOne(tokenB, none).andExpect(status().isNotFound()).andReturn().getResponse()
				.getContentAsString();
		assertEquals(other.replace(id.toString(), "X"), missing.replace(none.toString(), "X"));
	}

	@Test
	void delete_otherUsersSession_404_andKept() throws Exception {
		UUID id = UUID.randomUUID();
		putWorkout(tokenA, id, body(set(UUID.randomUUID(), BENCH, 1, "60", 8))).andExpect(status().isOk());
		del(tokenB, id).andExpect(status().isNotFound());
		assertEquals(1, countAll("workout_sessions"));
		assertEquals(1, countAll("workout_sets"));
	}

	@Test
	void delete_removesSets_secondDelete_404() throws Exception {
		UUID id = UUID.randomUUID();
		putWorkout(tokenA, id, body(set(UUID.randomUUID(), BENCH, 1, "60", 8))).andExpect(status().isOk());
		del(tokenA, id).andExpect(status().isNoContent());
		assertEquals(0, countAll("workout_sessions"));
		assertEquals(0, countAll("workout_sets"));
		del(tokenA, id).andExpect(status().isNotFound());
	}

	@Test
	void deleteUser_withSetsOnOwnCustomExercise_succeeds() throws Exception {
		String ex = createCustomExercise(tokenA, UUID.randomUUID());
		putWorkout(tokenA, UUID.randomUUID(), body(set(UUID.randomUUID(), ex, 1, "10", 10)))
				.andExpect(status().isOk());
		jdbc.execute("delete from users");
		assertEquals(0, countAll("workout_sets"));
		assertEquals(0, countAll("workout_sessions"));
	}

	@Test
	void list_usesSeoulDate() throws Exception {
		// 서울 11월 4일 00:30
		putWorkout(tokenA, UUID.randomUUID(),
				bodyAt("2026-11-03T15:30:00Z", "2026-11-03T16:30:00Z", null, set(UUID.randomUUID(), BENCH, 1, "60", 8),
						set(UUID.randomUUID(), SQUAT, 2, "60", 8), set(UUID.randomUUID(), BENCH, 3, "60", 8)))
				.andExpect(status().isOk());
		list(tokenA, "2026-11-04", "2026-11-04").andExpect(status().isOk())
				.andExpect(jsonPath("$.length()").value(1)).andExpect(jsonPath("$[0].setCount").value(3))
				.andExpect(jsonPath("$[0].exerciseNames.length()").value(2))
				.andExpect(jsonPath("$[0].exerciseNames[0]").value("벤치 프레스"))
				.andExpect(jsonPath("$[0].exerciseNames[1]").value("백 스쿼트"));
		list(tokenA, "2026-11-03", "2026-11-03").andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(0));
	}

	@Test
	void list_newestFirst_excludesOtherUsers_validatesRange() throws Exception {
		putWorkout(tokenA, UUID.randomUUID(), bodyAt("2026-11-04T01:00:00Z", "2026-11-04T02:00:00Z", null,
				set(UUID.randomUUID(), BENCH, 1, "60", 8))).andExpect(status().isOk());
		UUID later = UUID.randomUUID();
		putWorkout(tokenA, later, bodyAt("2026-11-04T05:00:00Z", "2026-11-04T06:00:00Z", null,
				set(UUID.randomUUID(), BENCH, 1, "60", 8))).andExpect(status().isOk());
		putWorkout(tokenB, UUID.randomUUID(), body(set(UUID.randomUUID(), BENCH, 1, "60", 8)))
				.andExpect(status().isOk());
		list(tokenA, "2026-11-01", "2026-11-30").andExpect(jsonPath("$.length()").value(2))
				.andExpect(jsonPath("$[0].id").value(later.toString()));
		list(tokenA, "2026-11-05", "2026-11-04").andExpect(status().isBadRequest())
				.andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
		mockMvc.perform(get("/api/v1/workouts").header("Authorization", "Bearer " + tokenA))
				.andExpect(status().isBadRequest());
	}
}
