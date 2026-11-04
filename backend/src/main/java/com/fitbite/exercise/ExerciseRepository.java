package com.fitbite.exercise;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

interface ExerciseRepository extends JpaRepository<Exercise, UUID> {

	@Query("select e from Exercise e where e.hiddenAt is null and (e.ownerUserId is null or e.ownerUserId = ?1) order by e.name")
	List<Exercise> findVisible(UUID userId);
}
