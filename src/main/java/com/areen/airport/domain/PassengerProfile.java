package com.areen.airport.domain;

import java.time.LocalDate;
import java.time.format.DateTimeParseException;

/**
 * Encapsulated passenger profile value object.
 */
public final class PassengerProfile extends Person {
    private final String email;
    private final String phone;
    private final String nationality;
    private final LocalDate dateOfBirth;
    private final String passportNumber;

    private PassengerProfile(String firstName,
                             String lastName,
                             String email,
                             String phone,
                             String nationality,
                             LocalDate dateOfBirth,
                             String passportNumber) {
        super(firstName, lastName);
        this.email = requireEmail(email);
        this.phone = requireBounded("Phone", phone, 20);
        this.nationality = requireBounded("Nationality", nationality, 60);
        this.dateOfBirth = dateOfBirth;
        this.passportNumber = normalizePassport(passportNumber);
    }

    public static PassengerProfile fromConsoleInput(String firstName,
                                                    String lastName,
                                                    String email,
                                                    String phone,
                                                    String nationality,
                                                    String dob,
                                                    String passportNumber) {
        LocalDate parsedDob = parseDob(dob);
        return new PassengerProfile(firstName, lastName, email, phone, nationality, parsedDob, passportNumber);
    }

    public String getEmail() {
        return email;
    }

    public String getPhone() {
        return phone;
    }

    public String getNationality() {
        return nationality;
    }

    public LocalDate getDateOfBirth() {
        return dateOfBirth;
    }

    public String getPassportNumber() {
        return passportNumber;
    }

    private static String requireEmail(String email) {
        String normalized = requireNonBlank(email, "Email").toLowerCase();
        if (normalized.length() > 120 || !normalized.contains("@")) {
            throw new IllegalArgumentException("Email must be valid and up to 120 characters.");
        }
        return normalized;
    }

    private static String requireBounded(String fieldName, String value, int maxLength) {
        String normalized = requireNonBlank(value, fieldName);
        if (normalized.length() > maxLength) {
            throw new IllegalArgumentException(fieldName + " exceeds max length " + maxLength + ".");
        }
        return normalized;
    }

    private static LocalDate parseDob(String dob) {
        String normalized = requireNonBlank(dob, "Date of birth");
        try {
            return LocalDate.parse(normalized);
        } catch (DateTimeParseException ex) {
            throw new IllegalArgumentException("Date of birth must be YYYY-MM-DD.");
        }
    }

    private static String normalizePassport(String passportNumber) {
        if (passportNumber == null || passportNumber.isBlank()) {
            return null;
        }
        String normalized = passportNumber.trim();
        if (normalized.length() > 20) {
            throw new IllegalArgumentException("Passport number exceeds max length 20.");
        }
        return normalized;
    }
}
