package com.fitbite.auth;

import com.fitbite.common.ApiException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Locale;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
class AuthService {

	static final String CONSENT_VERSION = "2026-11-v1";

	private final UserRepository users;
	private final ConsentRepository consents;
	private final TokenService tokens;
	private final PasswordEncoder encoder;
	private final byte[] inviteCode;
	/** 없는 이메일로 로그인해도 해시 비교 시간이 같도록 쓰는 더미 해시. */
	private final String dummyHash;

	AuthService(UserRepository users, ConsentRepository consents, TokenService tokens, PasswordEncoder encoder,
			@Value("${app.invite-code}") String inviteCode) {
		if (inviteCode.isBlank()) {
			throw new IllegalStateException("APP_INVITE_CODE must not be blank");
		}
		this.users = users;
		this.consents = consents;
		this.tokens = tokens;
		this.encoder = encoder;
		this.inviteCode = inviteCode.getBytes(StandardCharsets.UTF_8);
		this.dummyHash = encoder.encode("dummy-password");
	}

	@Transactional
	TokenResponse signup(SignupRequest r) {
		if (!MessageDigest.isEqual(inviteCode, r.inviteCode().getBytes(StandardCharsets.UTF_8))) {
			throw new ApiException(HttpStatus.FORBIDDEN, "INVALID_INVITE_CODE", "초대 코드가 올바르지 않습니다.");
		}
		if (!r.consentHealthData()) {
			throw new ApiException(HttpStatus.BAD_REQUEST, "CONSENT_REQUIRED", "건강 정보 수집·이용 동의가 필요합니다.");
		}
		// BCrypt는 72바이트까지만 읽는다. 한글처럼 글자 수보다 바이트가 많은 경우를 막는다.
		if (tooLong(r.password())) {
			throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "비밀번호가 너무 깁니다.");
		}
		String email = normalize(r.email());
		if (users.findByEmail(email).isPresent()) {
			throw emailTaken();
		}
		User user;
		try {
			user = users.saveAndFlush(new User(email, encoder.encode(r.password()), r.nickname().trim()));
		} catch (DataIntegrityViolationException e) {
			throw emailTaken(); // 동시 가입 경쟁
		}
		consents.save(new Consent(user.getId(), "HEALTH_DATA", CONSENT_VERSION));
		return tokens.issue(user.getId());
	}

	@Transactional
	TokenResponse login(LoginRequest r) {
		User user = users.findByEmail(normalize(r.email())).orElse(null);
		boolean ok = !tooLong(r.password())
				&& encoder.matches(r.password(), user == null ? dummyHash : user.getPasswordHash())
				&& user != null;
		if (!ok) {
			throw new ApiException(HttpStatus.UNAUTHORIZED, "INVALID_CREDENTIALS", "이메일 또는 비밀번호가 올바르지 않습니다.");
		}
		return tokens.issue(user.getId());
	}

	@Transactional
	TokenResponse refresh(String refreshToken) {
		return tokens.rotate(refreshToken);
	}

	@Transactional
	void logout(String refreshToken) {
		tokens.revoke(refreshToken);
	}

	@Transactional(readOnly = true)
	MeResponse me(UUID id) {
		User u = users.findById(id)
				.orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "UNAUTHORIZED", "인증이 필요합니다."));
		return new MeResponse(u.getId(), u.getEmail(), u.getNickname());
	}

	private static String normalize(String email) {
		return email.trim().toLowerCase(Locale.ROOT);
	}

	private static boolean tooLong(String password) {
		return password.getBytes(StandardCharsets.UTF_8).length > 72;
	}

	private static ApiException emailTaken() {
		return new ApiException(HttpStatus.CONFLICT, "EMAIL_TAKEN", "이미 가입된 이메일입니다.");
	}
}
