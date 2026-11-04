package com.fitbite.auth;

import java.time.Instant;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

interface RefreshTokenRepository extends JpaRepository<RefreshToken, Long> {

	Optional<RefreshToken> findByTokenHash(String tokenHash);

	/** 아직 유효한 토큰만 폐기한다. 동시에 두 번 재발급해도 한 요청만 1을 돌려받는다. */
	@Modifying
	@Query("update RefreshToken t set t.revokedAt = :now where t.tokenHash = :hash and t.revokedAt is null and t.expiresAt > :now")
	int revoke(String hash, Instant now);
}
