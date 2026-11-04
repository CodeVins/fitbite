package com.fitbite.workout;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "workout_sessions")
class WorkoutSession {

	@Id
	private UUID id;
	@Column(name = "user_id")
	private UUID userId;
	@Column(name = "started_at")
	private Instant startedAt;
	@Column(name = "ended_at")
	private Instant endedAt;
	private String memo;
	@Column(name = "updated_at")
	private Instant updatedAt;

	protected WorkoutSession() {
	}

	WorkoutSession(UUID id, UUID userId) {
		this.id = id;
		this.userId = userId;
	}

	void update(Instant startedAt, Instant endedAt, String memo) {
		this.startedAt = startedAt;
		this.endedAt = endedAt;
		this.memo = memo;
		this.updatedAt = Instant.now();
	}

	UUID getId() {
		return id;
	}

	UUID getUserId() {
		return userId;
	}

	Instant getStartedAt() {
		return startedAt;
	}

	Instant getEndedAt() {
		return endedAt;
	}

	String getMemo() {
		return memo;
	}
}
