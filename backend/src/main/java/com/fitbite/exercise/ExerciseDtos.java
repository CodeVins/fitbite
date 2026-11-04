package com.fitbite.exercise;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.UUID;

record ExerciseUpsertRequest(@NotBlank @Size(max = 50) String name, @Size(max = 50) String equipment,
		@NotNull BodyPart bodyPart) {
}

record ExerciseResponse(UUID id, String name, String equipment, BodyPart bodyPart, boolean custom) {
}
