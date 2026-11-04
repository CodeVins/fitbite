package com.fitbite.auth;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "users")
class User {

	@Id
	private UUID id;
	private String email;
	@Column(name = "password_hash")
	private String passwordHash;
	private String nickname;
	@Column(name = "created_at")
	private Instant createdAt;

	protected User() {
	}

	User(String email, String passwordHash, String nickname) {
		this.id = UUID.randomUUID();
		this.email = email;
		this.passwordHash = passwordHash;
		this.nickname = nickname;
		this.createdAt = Instant.now();
	}

	UUID getId() {
		return id;
	}

	String getEmail() {
		return email;
	}

	String getPasswordHash() {
		return passwordHash;
	}

	String getNickname() {
		return nickname;
	}
}
