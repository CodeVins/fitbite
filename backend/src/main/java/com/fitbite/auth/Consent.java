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
@Table(name = "consents")
class Consent {

	@Id
	@GeneratedValue(strategy = GenerationType.IDENTITY)
	private Long id;
	@Column(name = "user_id")
	private UUID userId;
	private String type;
	private String version;
	@Column(name = "agreed_at")
	private Instant agreedAt;

	protected Consent() {
	}

	Consent(UUID userId, String type, String version) {
		this.userId = userId;
		this.type = type;
		this.version = version;
		this.agreedAt = Instant.now();
	}
}
