package com.fitbite.auth;

import org.springframework.data.jpa.repository.JpaRepository;

interface ConsentRepository extends JpaRepository<Consent, Long> {
}
