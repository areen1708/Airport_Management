package com.areen.airport.domain.flight;

public final class FlightServiceFactory {
    private FlightServiceFactory() {
    }

    public static FlightService create(String scope, String origin, String destination) {
        if ("REGIONAL".equalsIgnoreCase(scope)) {
            return new RegionalFlightService(origin, destination);
        }
        if ("INTERNATIONAL".equalsIgnoreCase(scope)) {
            return new InternationalFlightService(origin, destination);
        }
        return new DomesticFlightService(origin, destination);
    }
}
