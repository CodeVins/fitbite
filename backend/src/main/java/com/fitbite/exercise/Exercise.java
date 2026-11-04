package com.fitbite.exercise;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "exercises")
public class Exercise {

	@Id
	private UUID id;
	@Column(name = "owner_user_id")
	private UUID ownerUserId;
	private String name;
	private String equipment;
	@Enumerated(EnumType.STRING)
	@Column(name = "body_part")
	private BodyPart bodyPart;
	@Column(name = "hidden_at")
	private Instant hiddenAt;

	protected Exercise() {
	}

	Exercise(UUID id, UUID ownerUserId, String name, String equipment, BodyPart bodyPart) {
		this.id = id;
		this.ownerUserId = ownerUserId;
		update(name, equipment, bodyPart);
	}

	void update(String name, String equipment, BodyPart bodyPart) {
		this.name = name;
		this.equipment = equipment;
		this.bodyPart = bodyPart;
	}

	public UUID getId() {
		return id;
	}

	UUID getOwnerUserId() {
		return ownerUserId;
	}

	String getName() {
		return name;
	}

	String getEquipment() {
		return equipment;
	}

	BodyPart getBodyPart() {
		return bodyPart;
	}
}
