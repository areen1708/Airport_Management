package com.areen.airport.domain.flight;

public final class DomesticFlightService extends FlightService {
    public DomesticFlightService(String origin, String destination) {
        super(origin, destination);
    }

    @Override
    public String serviceDescription() {
        return "Domestic service";
    }
}
