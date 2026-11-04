package com.fitbite.workout;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/** 운동별로 가장 최근 세션(started_at 기준)의 세트를 돌려준다. */
@Component
class LastPerformanceQuery {

	// session_rank = 1이 운동별 최근 세션. set_number는 그 운동 안에서 order_no 순서다.
	private static final String SQL = """
			select exercise_id, started_at, set_number, weight_kg, reps from (
			  select s.exercise_id, w.started_at, s.weight_kg, s.reps,
			         dense_rank() over (partition by s.exercise_id order by w.started_at desc, w.id) as session_rank,
			         row_number() over (partition by s.exercise_id, w.id order by s.order_no) as set_number
			  from workout_sets s join workout_sessions w on w.id = s.session_id
			  where w.user_id = ?) t
			where session_rank = 1
			order by started_at desc, exercise_id, set_number
			""";

	private final JdbcTemplate jdbc;

	LastPerformanceQuery(JdbcTemplate jdbc) {
		this.jdbc = jdbc;
	}

	List<LastPerformance> find(UUID userId) {
		Map<UUID, LastPerformance> byExercise = new LinkedHashMap<>();
		jdbc.query(SQL, rs -> {
			UUID exerciseId = rs.getObject("exercise_id", UUID.class);
			LastPerformance p = byExercise.get(exerciseId);
			if (p == null) {
				p = new LastPerformance(exerciseId, rs.getObject("started_at", java.time.OffsetDateTime.class).toInstant(),
						new ArrayList<>());
				byExercise.put(exerciseId, p);
			}
			p.sets().add(new LastSet(rs.getInt("set_number"), rs.getBigDecimal("weight_kg"), rs.getInt("reps")));
		}, userId);
		return new ArrayList<>(byExercise.values());
	}
}
