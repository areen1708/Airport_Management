package com.areen.airport.domain;

public enum CabinClass {
    ECONOMY,
    PREMIUM_ECONOMY,
    BUSINESS,
    FIRST;

    public static CabinClass fromInput(String input) {
        if (input == null || input.isBlank()) {
            throw new IllegalArgumentException("Cabin class is required.");
        }
        try {
            return CabinClass.valueOf(input.trim().toUpperCase());
        } catch (IllegalArgumentException ex) {
            throw new IllegalArgumentException("Invalid cabin. Use ECONOMY, PREMIUM_ECONOMY, BUSINESS, or FIRST.");
        }
    }
}
