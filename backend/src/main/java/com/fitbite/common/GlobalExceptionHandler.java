package com.fitbite.common;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.web.ErrorResponse;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.WebRequest;
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler;

/** 모든 오류를 RFC 9457 ProblemDetail + code 속성으로 통일한다. */
@RestControllerAdvice
public class GlobalExceptionHandler extends ResponseEntityExceptionHandler {

	private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

	@ExceptionHandler(ApiException.class)
	ResponseEntity<Object> handleApi(ApiException e) {
		return ResponseEntity.status(e.getStatus()).body(problem(e.getStatus(), e.getCode(), e.getMessage()));
	}

	@ExceptionHandler(Exception.class)
	ResponseEntity<Object> handleUnexpected(Exception e) {
		// 상세 메시지는 응답에 넣지 않는다. 스택 트레이스만 서버 로그에 남긴다.
		log.error("Unexpected error", e);
		HttpStatus s = HttpStatus.INTERNAL_SERVER_ERROR;
		return ResponseEntity.status(s).body(problem(s, "INTERNAL_ERROR", "서버 오류가 발생했습니다."));
	}

	/** Spring MVC 표준 예외(검증 실패, 없는 경로 등)에도 code를 붙인다. */
	@Override
	protected ResponseEntity<Object> handleExceptionInternal(Exception ex, Object body, HttpHeaders headers,
			HttpStatusCode statusCode, WebRequest request) {
		// 표준 예외는 body가 null로 들어오므로 ErrorResponse에서 직접 꺼낸다.
		if (body == null && ex instanceof ErrorResponse er) {
			body = er.getBody();
		}
		if (body instanceof ProblemDetail pd) {
			pd.setProperty("code", codeFor(statusCode));
		}
		return super.handleExceptionInternal(ex, body, headers, statusCode, request);
	}

	static String codeFor(HttpStatusCode s) {
		return switch (s.value()) {
			case 400 -> "VALIDATION_ERROR";
			case 401 -> "UNAUTHORIZED";
			case 404 -> "NOT_FOUND";
			case 409 -> "CONFLICT";
			default -> "INTERNAL_ERROR";
		};
	}

	static ProblemDetail problem(HttpStatus status, String code, String detail) {
		ProblemDetail pd = ProblemDetail.forStatusAndDetail(status, detail);
		pd.setProperty("code", code);
		return pd;
	}
}
