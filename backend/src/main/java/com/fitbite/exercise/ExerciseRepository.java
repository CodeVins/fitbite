package com.fitbite.exercise;

import jakarta.persistence.LockModeType;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

interface ExerciseRepository extends JpaRepository<Exercise, UUID> {

	@Modifying
	@Query(nativeQuery = true, value = "insert into exercises (id, owner_user_id, name, equipment, body_part) values (?1, ?2, ?3, ?4, ?5) on conflict (id) do nothing")
	void insertIfAbsent(UUID id, UUID ownerUserId, String name, String equipment, String bodyPart);

	@Lock(LockModeType.PESSIMISTIC_WRITE)
	@Query("select e from Exercise e where e.id = ?1")
	Optional<Exercise> findForUpdate(UUID id);

	@Query("select e from Exercise e where e.hiddenAt is null and (e.ownerUserId is null or e.ownerUserId = ?1) order by e.name")
	List<Exercise> findVisible(UUID userId);
}
