package com.fitbite.auth;

import com.fitbite.common.ApiException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.HexFormat;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.stereotype.Service;

@Service
class TokenService {

	static final Duration ACCESS_TTL = Duration.ofMinutes(30);
	static final Duration REFRESH_TTL = Duration.ofDays(30);

	private final JwtEncoder encoder;
	private final RefreshTokenRepository refreshTokens;
	private final SecureRandom random = new SecureRandom();

	TokenService(JwtEncoder encoder, RefreshTokenRepository refreshTokens) {
		this.encoder = encoder;
		this.refreshTokens = refreshTokens;
	}

	/** 액세스 토큰을 만들고 재발급 토큰은 해시만 저장한다. 호출한 트랜잭션 안에서 쓴다. */
	TokenResponse issue(UUID userId) {
		Instant now = Instant.now();
		String access = encoder.encode(JwtEncoderParameters.from(JwsHeader.with(MacAlgorithm.HS256).build(),
				JwtClaimsSet.builder().subject(userId.toString()).issuedAt(now).expiresAt(now.plus(ACCESS_TTL))
						.build()))
				.getTokenValue();
		byte[] bytes = new byte[32];
		random.nextBytes(bytes);
		String refresh = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
		refreshTokens.save(new RefreshToken(userId, sha256(refresh), now.plus(REFRESH_TTL)));
		return new TokenResponse(access, refresh, ACCESS_TTL.toSeconds());
	}

	/** 재발급 토큰을 한 번만 쓸 수 있게 폐기하고 새 토큰 쌍을 낸다. */
	TokenResponse rotate(String refreshToken) {
		String hash = sha256(refreshToken);
		// ponytail: 재사용 탐지 없이 이전 토큰만 거부한다. 응답 유실 재시도로 잠기는 일을 피하려는 선택. 출시 시 토큰 계열 폐기를 검토한다.
		RefreshToken token = refreshTokens.findByTokenHash(hash).orElseThrow(TokenService::invalid);
		if (refreshTokens.revoke(hash, Instant.now()) == 0) {
			throw invalid();
		}
		return issue(token.getUserId());
	}

	void revoke(String refreshToken) {
		refreshTokens.revoke(sha256(refreshToken), Instant.now());
	}

	private static ApiException invalid() {
		return new ApiException(HttpStatus.UNAUTHORIZED, "INVALID_REFRESH_TOKEN", "유효하지 않은 재발급 토큰입니다.");
	}

	private static String sha256(String s) {
		try {
			return HexFormat.of()
					.formatHex(MessageDigest.getInstance("SHA-256").digest(s.getBytes(StandardCharsets.UTF_8)));
		} catch (NoSuchAlgorithmException e) {
			throw new IllegalStateException(e);
		}
	}
}
