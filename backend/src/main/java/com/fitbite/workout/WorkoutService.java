package com.fitbite.workout;

import com.fitbite.common.ApiException;
import com.fitbite.exercise.ExerciseService;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
class WorkoutService {

	private static final ZoneId SEOUL = ZoneId.of("Asia/Seoul");

	private final WorkoutRepository sessions;
	private final WorkoutSetRepository sets;
	private final ExerciseService exercises;
	private final LastPerformanceQuery lastPerformance;

	WorkoutService(WorkoutRepository sessions, WorkoutSetRepository sets, ExerciseService exercises,
			LastPerformanceQuery lastPerformance) {
		this.sessions = sessions;
		this.sets = sets;
		this.exercises = exercises;
		this.lastPerformance = lastPerformance;
	}

	/** 세션 전체를 통째로 저장한다. 같은 요청을 여러 번 보내도 결과가 같다(마지막 수정 우선). */
	@Transactional
	WorkoutResponse upsert(UUID userId, UUID id, WorkoutUpsertRequest r) {
		validate(r);
		for (UUID exerciseId : r.sets().stream().map(SetRequest::exerciseId).collect(Collectors.toSet())) {
			exercises.requireAccessible(userId, exerciseId);
		}
		// 세션 ID를 먼저 선점하고(없을 때만 넣음) 행을 잠근다. 같은 사용자의 동시 요청은 순서대로 성공하고,
		// 남의 세션은 선점 시점과 관계없이 404다. 읽고-쓰는 merge를 쓰지 않으므로 남의 행을 덮어쓸 수 없다.
		sessions.insertIfAbsent(id, userId, r.startedAt(), r.endedAt());
		WorkoutSession session = sessions.findForUpdate(id).filter(w -> w.getUserId().equals(userId))
				.orElseThrow(WorkoutService::notFound);
		List<UUID> setIds = r.sets().stream().map(SetRequest::id).toList();
		if (!sets.findIdsInOtherSessions(setIds, id).isEmpty()) {
			throw conflict();
		}
		session.update(r.startedAt(), r.endedAt(), r.memo());
		try {
			sessions.flush();
			sets.deleteBySessionId(id);
			sets.saveAllAndFlush(r.sets().stream().map(s -> new WorkoutSet(id, s)).toList());
		} catch (DataIntegrityViolationException e) {
			// 검사 뒤에 다른 세션이 같은 세트 ID를 커밋하면 기본 키 위반이 난다. 이것도 409다.
			throw conflict();
		}
		return detail(session);
	}

	@Transactional(readOnly = true)
	WorkoutResponse get(UUID userId, UUID id) {
		return detail(owned(userId, id));
	}

	@Transactional
	void delete(UUID userId, UUID id) {
		sessions.delete(owned(userId, id)); // 세트는 DB의 ON DELETE CASCADE로 함께 지워진다.
	}

	@Transactional(readOnly = true)
	List<WorkoutSummary> list(UUID userId, LocalDate from, LocalDate to) {
		if (from.isAfter(to)) {
			throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "from은 to보다 늦을 수 없습니다.");
		}
		List<WorkoutSession> found = sessions.findInRange(userId, from.atStartOfDay(SEOUL).toInstant(),
				to.plusDays(1).atStartOfDay(SEOUL).toInstant());
		Map<UUID, List<Object[]>> rows = rowsBySession(found);
		return found.stream().map(w -> {
			List<Object[]> r = rows.getOrDefault(w.getId(), List.of());
			Set<String> names = new LinkedHashSet<>();
			r.forEach(row -> names.add((String) row[1]));
			return new WorkoutSummary(w.getId(), w.getStartedAt(), w.getEndedAt(), r.size(), new ArrayList<>(names));
		}).toList();
	}

	@Transactional(readOnly = true)
	List<LastPerformance> lastPerformance(UUID userId) {
		return lastPerformance.find(userId);
	}

	private WorkoutResponse detail(WorkoutSession w) {
		List<SetResponse> setResponses = rowsBySession(List.of(w)).getOrDefault(w.getId(), List.of()).stream()
				.map(row -> ((WorkoutSet) row[0]).toResponse((String) row[1])).toList();
		return new WorkoutResponse(w.getId(), w.getStartedAt(), w.getEndedAt(), w.getMemo(), setResponses);
	}

	private Map<UUID, List<Object[]>> rowsBySession(List<WorkoutSession> found) {
		if (found.isEmpty()) {
			return Map.of();
		}
		return sets.findWithExerciseName(found.stream().map(WorkoutSession::getId).toList()).stream()
				.collect(Collectors.groupingBy(row -> ((WorkoutSet) row[0]).getSessionId()));
	}

	/** 없는 세션과 남의 세션은 같은 404로 답한다. */
	private WorkoutSession owned(UUID userId, UUID id) {
		return sessions.findById(id).filter(w -> w.getUserId().equals(userId)).orElseThrow(WorkoutService::notFound);
	}

	private static void validate(WorkoutUpsertRequest r) {
		if (r.endedAt().isBefore(r.startedAt())) {
			throw invalid("endedAt은 startedAt보다 빠를 수 없습니다.");
		}
		Set<Integer> orderNos = new HashSet<>();
		Set<UUID> ids = new HashSet<>();
		for (SetRequest s : r.sets()) {
			if (!orderNos.add(s.orderNo())) {
				throw invalid("orderNo가 중복되었습니다.");
			}
			if (!ids.add(s.id())) {
				throw invalid("세트 id가 중복되었습니다.");
			}
		}
	}

	private static ApiException invalid(String message) {
		return new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", message);
	}

	private static ApiException notFound() {
		return new ApiException(HttpStatus.NOT_FOUND, "NOT_FOUND", "운동 기록을 찾을 수 없습니다.");
	}

	private static ApiException conflict() {
		return new ApiException(HttpStatus.CONFLICT, "CONFLICT", "이미 다른 운동 기록에 사용된 ID입니다.");
	}
}
