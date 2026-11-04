package com.fitbite.common;

import java.nio.charset.StandardCharsets;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.MediaType;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;

/** stateless 보안 설정. JWT 검증은 Task 3에서 추가한다. */
@Configuration
class SecurityConfig {

	@Bean
	SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
		return http
				.csrf(AbstractHttpConfigurer::disable)
				.sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
				.authorizeHttpRequests(a -> a
						.requestMatchers("/v3/api-docs/**", "/swagger-ui/**", "/swagger-ui.html", "/api/v1/auth/**")
						.permitAll()
						.anyRequest().authenticated())
				.exceptionHandling(e -> e.authenticationEntryPoint((req, res, ex) -> {
					res.setStatus(401);
					res.setContentType(MediaType.APPLICATION_PROBLEM_JSON_VALUE);
					res.setCharacterEncoding(StandardCharsets.UTF_8.name());
					res.getWriter().write("""
							{"type":"about:blank","title":"Unauthorized","status":401,\
							"detail":"인증이 필요합니다.","code":"UNAUTHORIZED"}""");
				}))
				.build();
	}
}
