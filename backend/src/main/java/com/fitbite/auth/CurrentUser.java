package com.fitbite.auth;

import java.util.UUID;
import org.springframework.security.oauth2.jwt.Jwt;

/** 로그인한 사용자 ID를 얻는 유일한 방법. */
public final class CurrentUser {

	private CurrentUser() {
	}

	public static UUID id(Jwt jwt) {
		return UUID.fromString(jwt.getSubject());
	}
}
