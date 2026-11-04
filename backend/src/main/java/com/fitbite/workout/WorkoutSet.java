package com.fitbite.workout;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;
import org.springframework.data.domain.Persistable;

@Entity
@Table(name = "workout_sets")
class WorkoutSet implements Persistable<UUID> {

	@Id
	private UUID id;
	@Column(name = "session_id", updatable = false)
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

	/** 세트는 항상 새로 넣는다. merge로 남의 행을 덮어쓰지 않고, ID가 겹치면 기본 키 위반이 난다. */
	@Override
	public boolean isNew() {
		return true;
	}

	@Override
	public UUID getId() {
		return id;
	}

	UUID getSessionId() {
		return sessionId;
	}
}
