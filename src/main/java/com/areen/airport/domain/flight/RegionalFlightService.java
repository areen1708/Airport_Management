package com.areen.airport.domain.flight;

public final class RegionalFlightService extends FlightService {
    public RegionalFlightService(String origin, String destination) {
        super(origin, destination);
    }

    @Override
    public String serviceDescription() {
        return "Regional connectivity";
    }
}
