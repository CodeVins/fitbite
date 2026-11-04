package com.fitbite.workout;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

interface WorkoutRepository extends JpaRepository<WorkoutSession, UUID> {

	@Query("select w from WorkoutSession w where w.userId = ?1 and w.startedAt >= ?2 and w.startedAt < ?3 order by w.startedAt desc")
	List<WorkoutSession> findInRange(UUID userId, Instant from, Instant to);
}
