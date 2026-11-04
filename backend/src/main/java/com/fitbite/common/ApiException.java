package com.fitbite.common;

import org.springframework.http.HttpStatus;

/** 업무 규칙 위반을 나타낸다. GlobalExceptionHandler가 공통 오류 응답으로 바꾼다. */
public class ApiException extends RuntimeException {

	private final HttpStatus status;
	private final String code;

	public ApiException(HttpStatus status, String code, String message) {
		super(message);
		this.status = status;
		this.code = code;
	}

	public HttpStatus getStatus() {
		return status;
	}

	public String getCode() {
		return code;
	}
}
