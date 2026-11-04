package com.fitbite.workout;

import com.fitbite.auth.CurrentUser;
import jakarta.validation.Valid;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
class WorkoutController {

	private final WorkoutService service;

	WorkoutController(WorkoutService service) {
		this.service = service;
	}

	@PutMapping("/api/v1/workouts/{id}")
	WorkoutResponse upsert(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id,
			@Valid @RequestBody WorkoutUpsertRequest r) {
		return service.upsert(CurrentUser.id(jwt), id, r);
	}

	@GetMapping("/api/v1/workouts")
	List<WorkoutSummary> list(@AuthenticationPrincipal Jwt jwt,
			@RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
			@RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
		return service.list(CurrentUser.id(jwt), from, to);
	}

	@GetMapping("/api/v1/workouts/{id}")
	WorkoutResponse get(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) {
		return service.get(CurrentUser.id(jwt), id);
	}

	@DeleteMapping("/api/v1/workouts/{id}")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	void delete(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) {
		service.delete(CurrentUser.id(jwt), id);
	}

	// 운동 목록 경로(/exercises/{id})와 겹치지 않도록 workout 패키지에서 받는다.
	@GetMapping("/api/v1/exercises/last-performance")
	List<LastPerformance> lastPerformance(@AuthenticationPrincipal Jwt jwt) {
		return service.lastPerformance(CurrentUser.id(jwt));
	}
}
