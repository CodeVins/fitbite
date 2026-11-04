package com.fitbite.exercise;

import com.fitbite.auth.CurrentUser;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/exercises")
class ExerciseController {

	private final ExerciseService service;

	ExerciseController(ExerciseService service) {
		this.service = service;
	}

	@GetMapping
	List<ExerciseResponse> list(@AuthenticationPrincipal Jwt jwt) {
		return service.list(CurrentUser.id(jwt));
	}

	@PutMapping("/{id}")
	ExerciseResponse upsert(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id,
			@Valid @RequestBody ExerciseUpsertRequest r) {
		return service.upsert(CurrentUser.id(jwt), id, r);
	}
}
