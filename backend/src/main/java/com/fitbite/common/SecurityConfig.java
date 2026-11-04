package com.fitbite.common;

import com.nimbusds.jose.jwk.source.ImmutableSecret;
import java.nio.charset.StandardCharsets;
import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.MediaType;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.security.web.SecurityFilterChain;

/** stateless 보안 설정. JWT(HS256)는 APP_JWT_SECRET으로 서명하고 검증한다. */
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
				// 토큰이 없거나, 만료되었거나, 잘못된 경우 모두 같은 401 형식으로 답한다.
				.oauth2ResourceServer(o -> o.jwt(j -> { }).authenticationEntryPoint(unauthorized()))
				.exceptionHandling(e -> e.authenticationEntryPoint(unauthorized()))
				.build();
	}

	private static AuthenticationEntryPoint unauthorized() {
		return (req, res, ex) -> {
			res.setStatus(401);
			res.setContentType(MediaType.APPLICATION_PROBLEM_JSON_VALUE);
			res.setCharacterEncoding(StandardCharsets.UTF_8.name());
			res.getWriter().write("""
					{"type":"about:blank","title":"Unauthorized","status":401,\
					"detail":"인증이 필요합니다.","code":"UNAUTHORIZED"}""");
		};
	}

	@Bean
	PasswordEncoder passwordEncoder() {
		return new BCryptPasswordEncoder();
	}

	/** 값이 없거나 32바이트 미만이면 서버가 시작되지 않는다. */
	@Bean
	SecretKey jwtKey(@Value("${app.jwt-secret}") String secret) {
		byte[] bytes = secret.getBytes(StandardCharsets.UTF_8);
		if (bytes.length < 32) {
			throw new IllegalStateException("APP_JWT_SECRET must be at least 32 bytes");
		}
		return new SecretKeySpec(bytes, "HmacSHA256");
	}

	@Bean
	JwtEncoder jwtEncoder(SecretKey jwtKey) {
		return new NimbusJwtEncoder(new ImmutableSecret<>(jwtKey));
	}

	@Bean
	JwtDecoder jwtDecoder(SecretKey jwtKey) {
		return NimbusJwtDecoder.withSecretKey(jwtKey).macAlgorithm(MacAlgorithm.HS256).build();
	}
}
