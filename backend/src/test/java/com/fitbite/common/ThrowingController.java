package com.fitbite.common;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/** 테스트 전용 컨트롤러. 테스트 소스에만 있어 운영에는 포함되지 않는다. */
@RestController
class ThrowingController {

	@GetMapping("/test/conflict")
	void conflict() {
		throw new ApiException(HttpStatus.CONFLICT, "CONFLICT", "x");
	}

	@GetMapping("/test/boom")
	void boom() {
		throw new IllegalStateException("secret");
	}
}
