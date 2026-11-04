package com.fitbite.common;

import static org.hamcrest.Matchers.not;
import static org.hamcrest.Matchers.containsString;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fitbite.IntegrationTest;
import org.junit.jupiter.api.Test;

class ErrorResponseTest extends IntegrationTest {

	@Test
	void apiDocs_isPublic() throws Exception {
		mockMvc.perform(get("/v3/api-docs")).andExpect(status().isOk());
	}

	@Test
	void unknownRouteWithoutToken_returns401WithCode() throws Exception {
		mockMvc.perform(get("/api/v1/nope"))
				.andExpect(status().isUnauthorized())
				.andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
	}

	@Test
	void apiException_isConvertedToProblemDetail() throws Exception {
		mockMvc.perform(get("/test/conflict").with(user("u")))
				.andExpect(status().isConflict())
				.andExpect(jsonPath("$.code").value("CONFLICT"));
	}

	@Test
	void unexpectedException_hidesDetails() throws Exception {
		mockMvc.perform(get("/test/boom").with(user("u")))
				.andExpect(status().isInternalServerError())
				.andExpect(jsonPath("$.code").value("INTERNAL_ERROR"))
				.andExpect(content().string(not(containsString("secret"))));
	}
}
