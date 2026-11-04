package com.fitbite.workout;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.ResultActions;

class LastPerformanceApiTest extends WorkoutTestSupport {

	private static String pick(String exerciseId) {
		return "$[?(@.exerciseId=='" + exerciseId + "')]";
	}

	private ResultActions last(String token) throws Exception {
		return mockMvc.perform(get("/api/v1/exercises/last-performance").header("Authorization", "Bearer " + token));
	}

	private void save(String token, String started, String... sets) throws Exception {
		putWorkout(token, UUID.randomUUID(), bodyAt(started, "2026-12-31T00:00:00Z", null, sets))
				.andExpect(status().isOk());
	}

	@Test
	void returnsMostRecentSessionPerExercise() throws Exception {
		save(tokenA, "2026-11-01T01:00:00Z", set(UUID.randomUUID(), SQUAT, 1, "100", 5),
				set(UUID.randomUUID(), BENCH, 2, "50", 10));
		save(tokenA, "2026-11-03T01:00:00Z", set(UUID.randomUUID(), SQUAT, 1, "110", 5));
		save(tokenA, "2026-11-02T01:00:00Z", set(UUID.randomUUID(), BENCH, 1, "60", 8));
		last(tokenA).andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(2))
				.andExpect(jsonPath(pick(SQUAT) + ".sets[0].weightKg").value(110.0))
				.andExpect(jsonPath(pick(SQUAT) + ".performedAt").value("2026-11-03T01:00:00Z"))
				.andExpect(jsonPath(pick(BENCH) + ".sets[0].weightKg").value(60.0))
				.andExpect(jsonPath(pick(BENCH) + ".sets.length()").value(1));
	}

	@Test
	void setNumber_isPerExercise() throws Exception {
		save(tokenA, "2026-11-03T01:00:00Z", set(UUID.randomUUID(), SQUAT, 1, "100", 5),
				set(UUID.randomUUID(), BENCH, 2, "60", 8), set(UUID.randomUUID(), SQUAT, 3, "105", 4));
		last(tokenA).andExpect(jsonPath(pick(SQUAT) + ".sets[0].setNumber").value(1))
				.andExpect(jsonPath(pick(SQUAT) + ".sets[1].setNumber").value(2))
				.andExpect(jsonPath(pick(SQUAT) + ".sets[1].reps").value(4))
				.andExpect(jsonPath(pick(BENCH) + ".sets[0].setNumber").value(1));
	}

	@Test
	void excludesOtherUsers() throws Exception {
		save(tokenB, "2026-11-03T01:00:00Z", set(UUID.randomUUID(), SQUAT, 1, "100", 5));
		last(tokenA).andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(0));
	}

	@Test
	void noHistory_returnsEmptyList() throws Exception {
		last(tokenA).andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(0));
	}
}
