CREATE TABLE workout_sessions (
    id         UUID PRIMARY KEY,
    user_id    UUID        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    started_at TIMESTAMPTZ NOT NULL,
    ended_at   TIMESTAMPTZ NOT NULL,
    memo       VARCHAR(500),
    updated_at TIMESTAMPTZ NOT NULL,
    CHECK (ended_at >= started_at)
);
CREATE INDEX workout_sessions_user_started_idx ON workout_sessions (user_id, started_at DESC);

-- exercise_id FK는 운동 삭제를 막는다. 다만 사용자 삭제 때 운동 삭제가 세션(세트) 삭제보다 먼저 처리되므로
-- 검사를 커밋 시점으로 미뤄(DEFERRABLE) 운동과 세트가 함께 지워지는 것을 허용한다.
CREATE TABLE workout_sets (
    id           UUID PRIMARY KEY,
    session_id   UUID          NOT NULL REFERENCES workout_sessions (id) ON DELETE CASCADE,
    exercise_id  UUID          NOT NULL REFERENCES exercises (id) DEFERRABLE INITIALLY DEFERRED,
    order_no     INT           NOT NULL,
    weight_kg    NUMERIC(6, 2) NOT NULL CHECK (weight_kg >= 0 AND weight_kg <= 1000),
    reps         INT           NOT NULL CHECK (reps >= 1 AND reps <= 1000),
    completed_at TIMESTAMPTZ   NOT NULL,
    rest_seconds INT CHECK (rest_seconds >= 0),
    UNIQUE (session_id, order_no)
);
CREATE INDEX workout_sets_exercise_idx ON workout_sets (exercise_id);
