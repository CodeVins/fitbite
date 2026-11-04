package com.fitbite.workout;

import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

record WorkoutUpsertRequest(@NotNull Instant startedAt, @NotNull Instant endedAt, @Size(max = 500) String memo,
		@NotEmpty List<@NotNull @Valid SetRequest> sets) {
}

record SetRequest(@NotNull UUID id, @NotNull UUID exerciseId, @Min(0) int orderNo,
		@NotNull @DecimalMin("0") @DecimalMax("1000") @Digits(integer = 4, fraction = 2) BigDecimal weightKg,
		@Min(1) @Max(1000) int reps, @NotNull Instant completedAt, @Min(0) Integer restSeconds) {
}

record SetResponse(UUID id, UUID exerciseId, int orderNo, BigDecimal weightKg, int reps, Instant completedAt,
		Integer restSeconds, String exerciseName) {
}

record WorkoutResponse(UUID id, Instant startedAt, Instant endedAt, String memo, List<SetResponse> sets) {
}

record WorkoutSummary(UUID id, Instant startedAt, Instant endedAt, int setCount, List<String> exerciseNames) {
}

record LastSet(int setNumber, BigDecimal weightKg, int reps) {
}

record LastPerformance(UUID exerciseId, Instant performedAt, List<LastSet> sets) {
}
