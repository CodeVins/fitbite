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
		// 없을 때만 내 운동으로 선점하고 행을 잠근다. merge로 읽고-쓰지 않으므로 동시 요청이
		// 남의 운동이나 기본 운동을 덮어쓸 수 없다.
		repository.insertIfAbsent(id, userId, name, r.equipment(), r.bodyPart().name());
		Exercise e = repository.findForUpdate(id).filter(x -> userId.equals(x.getOwnerUserId()))
				.orElseThrow(ExerciseService::notFound);
		e.update(name, r.equipment(), r.bodyPart());
		return toResponse(e);
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
