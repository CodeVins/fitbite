package com.fitbite.workout;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.function.Predicate;
import org.hibernate.resource.jdbc.spi.StatementInspector;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;

/**
 * 동시 요청 경쟁을 재현한다. Hibernate StatementInspector로 "B 요청이 확인을 마친 뒤, 쓰기 전" 지점에서
 * 다른 연결(별도 트랜잭션)이 A의 행을 커밋하게 한다.
 */
@TestPropertySource(properties = "spring.jpa.properties.hibernate.session_factory.statement_inspector=com.fitbite.workout.WorkoutRaceTest$Hook")
class WorkoutRaceTest extends WorkoutTestSupport {

	public static class Hook implements StatementInspector {
		static volatile Predicate<String> when;
		static volatile Runnable action;
		static volatile boolean join;
		static volatile Thread started;

		@Override
		public String inspect(String sql) {
			Predicate<String> p = when;
			if (p != null && p.test(sql.toLowerCase())) {
				Runnable a = action;
				when = null;
				action = null;
				Thread t = new Thread(a);
				t.start();
				started = t;
				try {
					if (join) {
						t.join();
					} else {
						Thread.sleep(1000); // 이 요청이 잠금을 쥔 채 다른 요청이 기다리게 한다.
					}
				} catch (InterruptedException e) {
					throw new RuntimeException(e);
				}
			}
			return sql;
		}
	}

	@AfterEach
	void reset() {
		Hook.when = null;
		Hook.action = null;
		Hook.join = true;
	}

	private String userId(String token) throws Exception {
		String b = mockMvc.perform(get("/api/v1/me").header("Authorization", "Bearer " + token)).andReturn()
				.getResponse().getContentAsString();
		return JsonPath.read(b, "$.id");
	}

	private void insertA(UUID session, UUID set, String aId) {
		jdbc.update(
				"insert into workout_sessions(id,user_id,started_at,ended_at,updated_at) values (?::uuid,?::uuid,now(),now()+interval '1 hour',now())",
				session.toString(), aId);
		jdbc.update(
				"insert into workout_sets(id,session_id,exercise_id,order_no,weight_kg,reps,completed_at) values (?::uuid,?::uuid,?::uuid,1,77,7,now())",
				set.toString(), session.toString(), BENCH);
	}

	@Test
	void setRace_otherUsersSetCommittedAfterCheck_409_andUnchanged() throws Exception {
		String a = userId(tokenA);
		UUID aSession = UUID.randomUUID();
		UUID shared = UUID.randomUUID();
		UUID bSession = UUID.randomUUID();
		Hook.join = true;
		Hook.action = () -> insertA(aSession, shared, a);
		Hook.when = s -> s.contains("delete from workout_sets");
		putWorkout(tokenB, bSession, body(set(shared, SQUAT, 1, "999", 1))).andExpect(status().isConflict())
				.andExpect(jsonPath("$.code").value("CONFLICT"));
		Map<String, Object> row = jdbc.queryForMap(
				"select session_id::text as sid, weight_kg, exercise_id::text as ex, reps from workout_sets where id = ?::uuid",
				shared.toString());
		assertEquals(aSession.toString(), row.get("sid"));
		assertEquals(0, new java.math.BigDecimal("77").compareTo((java.math.BigDecimal) row.get("weight_kg")));
		assertEquals(BENCH, row.get("ex"));
		assertEquals(7, row.get("reps"));
		assertEquals(0, count("select count(*) from workout_sessions where id = '" + bSession + "'"));
	}

	@Test
	void sessionRace_otherUsersSessionCommittedAfterCheck_404_andIntact() throws Exception {
		String a = userId(tokenA);
		UUID sid = UUID.randomUUID();
		UUID aSet = UUID.randomUUID();
		Hook.join = true;
		Hook.action = () -> insertA(sid, aSet, a);
		Hook.when = s -> s.contains("from exercises");
		putWorkout(tokenB, sid, body(set(UUID.randomUUID(), BENCH, 1, "999", 1))).andExpect(status().isNotFound())
				.andExpect(jsonPath("$.code").value("NOT_FOUND"));
		assertEquals(a, jdbc.queryForObject("select user_id::text from workout_sessions where id = ?::uuid",
				String.class, sid.toString()));
		assertEquals(List.of(aSet.toString()),
				jdbc.queryForList("select id::text from workout_sets where session_id = ?::uuid", String.class,
						sid.toString()));
		assertEquals(0, count("select count(*) from workout_sets where weight_kg = 999"));
	}

	@Test
	void concurrentDuplicateFirstPut_sameUser_bothOk_noDuplicates() throws Exception {
		UUID sid = UUID.randomUUID();
		String json = body(set(UUID.randomUUID(), BENCH, 1, "60", 8), set(UUID.randomUUID(), BENCH, 2, "60", 8));
		AtomicInteger second = new AtomicInteger();
		Hook.join = false;
		Hook.action = () -> {
			try {
				second.set(putWorkout(tokenA, sid, json).andReturn().getResponse().getStatus());
			} catch (Exception e) {
				throw new RuntimeException(e);
			}
		};
		// 첫 요청이 세션 행을 쓴 뒤(커밋 전) 같은 요청이 들어온다.
		Hook.when = s -> s.contains("delete from workout_sets");
		putWorkout(tokenA, sid, json).andExpect(status().isOk());
		Hook.started.join();
		assertEquals(200, second.get());
		assertEquals(1, countAll("workout_sessions"));
		assertEquals(2, countAll("workout_sets"));
	}

	@Test
	void concurrentFirstPut_otherUser_404_notOverwritten() throws Exception {
		UUID sid = UUID.randomUUID();
		AtomicInteger second = new AtomicInteger();
		Hook.join = false;
		Hook.action = () -> {
			try {
				second.set(putWorkout(tokenB, sid, body(set(UUID.randomUUID(), SQUAT, 1, "999", 1))).andReturn()
						.getResponse().getStatus());
			} catch (Exception e) {
				throw new RuntimeException(e);
			}
		};
		Hook.when = s -> s.contains("delete from workout_sets");
		putWorkout(tokenA, sid, body(set(UUID.randomUUID(), BENCH, 1, "60", 8))).andExpect(status().isOk());
		Hook.started.join();
		assertEquals(404, second.get());
		assertEquals(1, countAll("workout_sets"));
		assertEquals(0, count("select count(*) from workout_sets where weight_kg = 999"));
	}

	@Test
	void exerciseRace_otherUsersExerciseCommittedAfterCheck_404_andUnchanged() throws Exception {
		String a = userId(tokenA);
		UUID id = UUID.randomUUID();
		AtomicInteger selects = new AtomicInteger();
		Hook.join = true;
		Hook.action = () -> jdbc.update(
				"insert into exercises(id, owner_user_id, name, equipment, body_part) values (?::uuid, ?::uuid, 'A원본', '바벨', 'CHEST')",
				id.toString(), a);
		// B의 쓰기 직전: 새 구현은 첫 insert 앞, 이전 구현(findById 후 merge)은 두 번째 select 앞.
		Hook.when = s -> s.contains("insert into exercises")
				|| (s.contains("from exercises") && selects.incrementAndGet() == 2);
		mockMvc.perform(put("/api/v1/exercises/" + id).header("Authorization", "Bearer " + tokenB)
				.contentType(MediaType.APPLICATION_JSON)
				.content("{\"name\":\"B덮어쓰기\",\"equipment\":\"덤벨\",\"bodyPart\":\"ARMS\"}"))
				.andExpect(status().isNotFound());
		Map<String, Object> row = jdbc.queryForMap(
				"select owner_user_id::text as owner, name, equipment, body_part from exercises where id = ?::uuid",
				id.toString());
		assertEquals(a, row.get("owner"));
		assertEquals("A원본", row.get("name"));
		assertEquals("바벨", row.get("equipment"));
		assertEquals("CHEST", row.get("body_part"));
	}
}
