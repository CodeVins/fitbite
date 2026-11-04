package com.fitbite.auth;

import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
class AuthController {

	private final AuthService service;

	AuthController(AuthService service) {
		this.service = service;
	}

	@PostMapping("/auth/signup")
	@ResponseStatus(HttpStatus.CREATED)
	TokenResponse signup(@Valid @RequestBody SignupRequest r) {
		return service.signup(r);
	}

	@PostMapping("/auth/login")
	TokenResponse login(@Valid @RequestBody LoginRequest r) {
		return service.login(r);
	}

	@PostMapping("/auth/refresh")
	TokenResponse refresh(@Valid @RequestBody RefreshRequest r) {
		return service.refresh(r.refreshToken());
	}

	@PostMapping("/auth/logout")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	void logout(@Valid @RequestBody RefreshRequest r) {
		service.logout(r.refreshToken());
	}

	@GetMapping("/me")
	MeResponse me(@AuthenticationPrincipal Jwt jwt) {
		return service.me(CurrentUser.id(jwt));
	}
}
