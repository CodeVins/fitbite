package com.fitbite.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fitbite.IntegrationTest;
import com.jayway.jsonpath.JsonPath;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.test.web.servlet.ResultActions;

class AuthApiTest extends IntegrationTest {

	@Autowired
	JdbcTemplate jdbc;
	@Autowired
	JwtEncoder jwtEncoder;

	@BeforeEach
	void clean() {
		jdbc.execute("delete from users");
	}

	private ResultActions postJson(String path, String json) throws Exception {
		return mockMvc.perform(post(path).contentType(MediaType.APPLICATION_JSON).content(json));
	}

	private ResultActions signup(String email, String password, String invite, boolean consent) throws Exception {
		return postJson("/api/v1/auth/signup", """
				{"email":"%s","password":"%s","nickname":"tester","inviteCode":"%s","consentHealthData":%s}"""
				.formatted(email, password, invite, consent));
	}

	private String signupOk(String email) throws Exception {
		return signup(email, "password123", "test-invite", true).andExpect(status().isCreated()).andReturn()
				.getResponse().getContentAsString();
	}

	private static String field(String body, String name) {
		return JsonPath.read(body, "$." + name);
	}

	private ResultActions refresh(String token) throws Exception {
		return postJson("/api/v1/auth/refresh", "{\"refreshToken\":\"%s\"}".formatted(token));
	}

	@Test
	void signup_returnsTokens_andStoresConsent() throws Exception {
		signup("a@test.com", "password123", "test-invite", true)
				.andExpect(status().isCreated())
				.andExpect(jsonPath("$.accessToken").isNotEmpty())
				.andExpect(jsonPath("$.refreshToken").isNotEmpty())
				.andExpect(jsonPath("$.expiresInSeconds").value(1800));
		List<Map<String, Object>> rows = jdbc.queryForList("select type, version from consents");
		assertEquals(1, rows.size());
		assertEquals("HEALTH_DATA", rows.get(0).get("type"));
		assertEquals("2026-11-v1", rows.get(0).get("version"));
	}

	@Test
	void signup_wrongInviteCode_403() throws Exception {
		signup("a@test.com", "password123", "nope", true)
				.andExpect(status().isForbidden())
				.andExpect(jsonPath("$.code").value("INVALID_INVITE_CODE"));
	}

	@Test
	void signup_withoutConsent_400() throws Exception {
		signup("a@test.com", "password123", "test-invite", false)
				.andExpect(status().isBadRequest())
				.andExpect(jsonPath("$.code").value("CONSENT_REQUIRED"));
		assertEquals(0, jdbc.queryForObject("select count(*) from users", Integer.class));
	}

	@Test
	void signup_duplicateEmail_409() throws Exception {
		signupOk("a@test.com");
		signup("A@Test.com", "password123", "test-invite", true)
				.andExpect(status().isConflict())
				.andExpect(jsonPath("$.code").value("EMAIL_TAKEN"));
	}

	@Test
	void signup_shortPassword_400() throws Exception {
		signup("a@test.com", "1234567", "test-invite", true)
				.andExpect(status().isBadRequest())
				.andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
	}

	@Test
	void password_isStoredHashed() throws Exception {
		signupOk("a@test.com");
		String hash = jdbc.queryForObject("select password_hash from users", String.class);
		assertNotEquals("password123", hash);
		assertTrue(hash.startsWith("$2"));
	}

	@Test
	void login_succeeds_andIgnoresEmailCase() throws Exception {
		signupOk("a@test.com");
		postJson("/api/v1/auth/login", "{\"email\":\"A@test.com\",\"password\":\"password123\"}")
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.accessToken").isNotEmpty());
	}

	@Test
	void login_wrongPasswordAndUnknownEmail_sameResponse() throws Exception {
		signupOk("a@test.com");
		String wrong = postJson("/api/v1/auth/login", "{\"email\":\"a@test.com\",\"password\":\"wrongpass1\"}")
				.andExpect(status().isUnauthorized())
				.andExpect(jsonPath("$.code").value("INVALID_CREDENTIALS"))
				.andReturn().getResponse().getContentAsString();
		String unknown = postJson("/api/v1/auth/login", "{\"email\":\"x@test.com\",\"password\":\"wrongpass1\"}")
				.andExpect(status().isUnauthorized())
				.andExpect(jsonPath("$.code").value("INVALID_CREDENTIALS"))
				.andReturn().getResponse().getContentAsString();
		assertEquals(wrong, unknown);
	}

	@Test
	void me_returnsCurrentUser() throws Exception {
		String access = field(signupOk("a@test.com"), "accessToken");
		mockMvc.perform(get("/api/v1/me").header("Authorization", "Bearer " + access))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.id").isNotEmpty())
				.andExpect(jsonPath("$.email").value("a@test.com"))
				.andExpect(jsonPath("$.nickname").value("tester"));
		mockMvc.perform(get("/api/v1/me")).andExpect(status().isUnauthorized());
	}

	@Test
	void refresh_rotates() throws Exception {
		String old = field(signupOk("a@test.com"), "refreshToken");
		String body = refresh(old).andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
		assertNotEquals(old, field(body, "refreshToken"));
		refresh(old).andExpect(status().isUnauthorized())
				.andExpect(jsonPath("$.code").value("INVALID_REFRESH_TOKEN"));
		refresh(field(body, "refreshToken")).andExpect(status().isOk());
	}

	@Test
	void refresh_unknownToken_401() throws Exception {
		refresh("garbage").andExpect(status().isUnauthorized())
				.andExpect(jsonPath("$.code").value("INVALID_REFRESH_TOKEN"));
	}

	@Test
	void refreshToken_storedHashed() throws Exception {
		String token = field(signupOk("a@test.com"), "refreshToken");
		String stored = jdbc.queryForObject("select token_hash from refresh_tokens", String.class);
		assertNotEquals(token, stored);
	}

	@Test
	void logout_revokes() throws Exception {
		String token = field(signupOk("a@test.com"), "refreshToken");
		postJson("/api/v1/auth/logout", "{\"refreshToken\":\"%s\"}".formatted(token))
				.andExpect(status().isNoContent());
		refresh(token).andExpect(status().isUnauthorized())
				.andExpect(jsonPath("$.code").value("INVALID_REFRESH_TOKEN"));
	}

	private String tokenFor(String id, Instant exp) {
		return jwtEncoder.encode(JwtEncoderParameters.from(JwsHeader.with(MacAlgorithm.HS256).build(),
				JwtClaimsSet.builder().subject(id).issuedAt(exp.minusSeconds(1800)).expiresAt(exp).build()))
				.getTokenValue();
	}

	@Test
	void expiredAccessToken_401() throws Exception {
		signupOk("a@test.com");
		String id = jdbc.queryForObject("select id::text from users", String.class);
		// 같은 사용자(sub)라도 exp가 지난 토큰만 거부되어야 한다. 대조군은 미래 exp로 200.
		mockMvc.perform(get("/api/v1/me").header("Authorization",
				"Bearer " + tokenFor(id, Instant.now().plus(1, ChronoUnit.HOURS))))
				.andExpect(status().isOk());
		mockMvc.perform(get("/api/v1/me").header("Authorization",
				"Bearer " + tokenFor(id, Instant.now().minus(2, ChronoUnit.HOURS))))
				.andExpect(status().isUnauthorized())
				.andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
	}

	@Test
	void invalidOrMalformedAccessToken_401() throws Exception {
		String valid = field(signupOk("a@test.com"), "accessToken");
		String tampered = valid.substring(0, valid.length() - 2) + (valid.endsWith("AA") ? "BB" : "AA");
		for (String bad : List.of("garbage", "a.b.c", tampered)) {
			mockMvc.perform(get("/api/v1/me").header("Authorization", "Bearer " + bad))
					.andExpect(status().isUnauthorized())
					.andExpect(jsonPath("$.code").value("UNAUTHORIZED"))
					.andExpect(jsonPath("$.status").value(401));
		}
	}
}
