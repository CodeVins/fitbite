package com.fitbite.workout;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "workout_sets")
class WorkoutSet {

	@Id
	private UUID id;
	@Column(name = "session_id")
	private UUID sessionId;
	@Column(name = "exercise_id")
	private UUID exerciseId;
	@Column(name = "order_no")
	private int orderNo;
	@Column(name = "weight_kg")
	private BigDecimal weightKg;
	private int reps;
	@Column(name = "completed_at")
	private Instant completedAt;
	@Column(name = "rest_seconds")
	private Integer restSeconds;

	protected WorkoutSet() {
	}

	WorkoutSet(UUID sessionId, SetRequest r) {
		this.id = r.id();
		this.sessionId = sessionId;
		this.exerciseId = r.exerciseId();
		this.orderNo = r.orderNo();
		this.weightKg = r.weightKg().setScale(2); // DB(numeric(6,2))와 같은 표현으로 맞춘다. 검증이 소수 2자리까지만 통과시킨다.
		this.reps = r.reps();
		this.completedAt = r.completedAt();
		this.restSeconds = r.restSeconds();
	}

	SetResponse toResponse(String exerciseName) {
		return new SetResponse(id, exerciseId, orderNo, weightKg, reps, completedAt, restSeconds, exerciseName);
	}

	UUID getSessionId() {
		return sessionId;
	}
}
