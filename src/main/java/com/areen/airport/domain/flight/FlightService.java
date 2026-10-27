package com.areen.airport.domain.flight;

public abstract class FlightService {
    private final String origin;
    private final String destination;

    protected FlightService(String origin, String destination) {
        this.origin = origin;
        this.destination = destination;
    }

    public String route() {
        return origin + " -> " + destination;
    }

    public abstract String serviceDescription();
}
