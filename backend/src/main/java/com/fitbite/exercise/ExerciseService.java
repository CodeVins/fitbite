package com.fitbite.exercise;

import com.fitbite.common.ApiException;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ExerciseService {

	private final ExerciseRepository repository;

	ExerciseService(ExerciseRepository repository) {
		this.repository = repository;
	}

	@Transactional(readOnly = true)
	List<ExerciseResponse> list(UUID userId) {
		return repository.findVisible(userId).stream().map(ExerciseService::toResponse).toList();
	}

	/** 새 ID면 내 운동으로 만들고, 내 운동이면 고친다. 기본 운동이나 남의 운동은 404. */
	@Transactional
	ExerciseResponse upsert(UUID userId, UUID id, ExerciseUpsertRequest r) {
		String name = r.name().trim();
		if (name.isEmpty()) {
			throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "이름은 필수입니다.");
		}
		Exercise e = repository.findById(id).orElse(null);
		if (e == null) {
			e = new Exercise(id, userId, name, r.equipment(), r.bodyPart());
		} else if (userId.equals(e.getOwnerUserId())) {
			e.update(name, r.equipment(), r.bodyPart());
		} else {
			throw notFound();
		}
		return toResponse(repository.save(e));
	}

	/** 기본 운동이거나 내 운동이면 돌려주고, 아니면 404. 운동 기록(작업 5)이 사용한다. */
	@Transactional(readOnly = true)
	public Exercise requireAccessible(UUID userId, UUID exerciseId) {
		return repository.findById(exerciseId)
				.filter(e -> e.getOwnerUserId() == null || e.getOwnerUserId().equals(userId))
				.orElseThrow(ExerciseService::notFound);
	}

	private static ApiException notFound() {
		return new ApiException(HttpStatus.NOT_FOUND, "NOT_FOUND", "운동을 찾을 수 없습니다.");
	}

	private static ExerciseResponse toResponse(Exercise e) {
		return new ExerciseResponse(e.getId(), e.getName(), e.getEquipment(), e.getBodyPart(),
				e.getOwnerUserId() != null);
	}
}
