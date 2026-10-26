package com.areen.airport.domain;

public enum FlightStatus {
    SCHEDULED,
    BOARDING,
    DEPARTED,
    ARRIVED,
    DELAYED,
    CANCELLED,
    DIVERTED;

    public static FlightStatus fromInput(String input) {
        if (input == null || input.isBlank()) {
            throw new IllegalArgumentException("Flight status is required.");
        }
        try {
            return FlightStatus.valueOf(input.trim().toUpperCase());
        } catch (IllegalArgumentException ex) {
            throw new IllegalArgumentException("Invalid status. Use SCHEDULED, BOARDING, DEPARTED, ARRIVED, DELAYED, CANCELLED, or DIVERTED.");
        }
    }

    public String toEventType() {
        return switch (this) {
            case DEPARTED -> "DEPARTED";
            case ARRIVED -> "ARRIVED";
            case CANCELLED -> "CANCELLED";
            case DELAYED -> "DELAYED";
            default -> "STATUS_UPDATED";
        };
    }
}
