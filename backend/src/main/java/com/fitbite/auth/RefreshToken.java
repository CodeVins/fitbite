package com.fitbite.auth;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "refresh_tokens")
class RefreshToken {

	@Id
	@GeneratedValue(strategy = GenerationType.IDENTITY)
	private Long id;
	@Column(name = "user_id")
	private UUID userId;
	@Column(name = "token_hash")
	private String tokenHash;
	@Column(name = "expires_at")
	private Instant expiresAt;
	@Column(name = "revoked_at")
	private Instant revokedAt;

	protected RefreshToken() {
	}

	RefreshToken(UUID userId, String tokenHash, Instant expiresAt) {
		this.userId = userId;
		this.tokenHash = tokenHash;
		this.expiresAt = expiresAt;
	}

	UUID getUserId() {
		return userId;
	}
}
