package com.fitbite.workout;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

interface WorkoutRepository extends JpaRepository<WorkoutSession, UUID> {

	/** 세션 ID 선점: 이미 있으면 아무 일도 하지 않는다. 동시 요청은 먼저 넣은 쪽이 끝날 때까지 기다린다. */
	@Modifying
	@Query(nativeQuery = true, value = "insert into workout_sessions (id, user_id, started_at, ended_at, updated_at) values (?1, ?2, ?3, ?4, now()) on conflict (id) do nothing")
	void insertIfAbsent(UUID id, UUID userId, Instant startedAt, Instant endedAt);

	/** 행을 잠그고 읽는다. 같은 세션에 대한 요청이 순서대로 처리된다. */
	@Lock(LockModeType.PESSIMISTIC_WRITE)
	@Query("select w from WorkoutSession w where w.id = ?1")
	Optional<WorkoutSession> findForUpdate(UUID id);

	@Query("select w from WorkoutSession w where w.userId = ?1 and w.startedAt >= ?2 and w.startedAt < ?3 order by w.startedAt desc")
	List<WorkoutSession> findInRange(UUID userId, Instant from, Instant to);
}
