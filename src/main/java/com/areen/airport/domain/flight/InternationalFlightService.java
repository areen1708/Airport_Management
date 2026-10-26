package com.areen.airport.domain.flight;

public final class InternationalFlightService extends FlightService {
    public InternationalFlightService(String origin, String destination) {
        super(origin, destination);
    }

    @Override
    public String serviceDescription() {
        return "International service";
    }
}
