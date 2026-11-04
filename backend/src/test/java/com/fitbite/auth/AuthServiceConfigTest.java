package com.fitbite.auth;

import static org.junit.jupiter.api.Assertions.assertThrows;

import org.junit.jupiter.api.Test;

class AuthServiceConfigTest {

	@Test
	void blankInviteCode_failsStartup() {
		for (String blank : new String[] { "", "   " }) {
			assertThrows(IllegalStateException.class, () -> new AuthService(null, null, null, null, blank));
		}
	}
}
