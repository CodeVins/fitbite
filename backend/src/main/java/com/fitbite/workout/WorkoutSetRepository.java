package com.fitbite.workout;

import java.util.Collection;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

interface WorkoutSetRepository extends JpaRepository<WorkoutSet, UUID> {

	/** [세트, 운동 이름] 쌍을 세션별 order_no 순으로 돌려준다. */
	@Query("select s, e.name from WorkoutSet s join Exercise e on e.id = s.exerciseId where s.sessionId in ?1 order by s.sessionId, s.orderNo")
	List<Object[]> findWithExerciseName(Collection<UUID> sessionIds);

	/** 요청의 세트 ID 중 다른 세션에 이미 있는 것. */
	@Query("select s.id from WorkoutSet s where s.id in ?1 and s.sessionId <> ?2")
	List<UUID> findIdsInOtherSessions(Collection<UUID> ids, UUID sessionId);

	@Modifying(flushAutomatically = true)
	@Query("delete from WorkoutSet s where s.sessionId = ?1")
	void deleteBySessionId(UUID sessionId);
}
