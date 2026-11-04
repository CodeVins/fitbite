package com.fitbite.auth;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.UUID;

record SignupRequest(
		@NotBlank @Email @Size(max = 254) String email,
		@NotBlank @Size(min = 8, max = 72) String password,
		@NotBlank @Size(max = 50) String nickname,
		@NotBlank String inviteCode,
		boolean consentHealthData) {
}

record LoginRequest(@NotBlank String email, @NotBlank String password) {
}

record RefreshRequest(@NotBlank String refreshToken) {
}

record TokenResponse(String accessToken, String refreshToken, long expiresInSeconds) {
}

record MeResponse(UUID id, String email, String nickname) {
}
