USE airport_operations_pro;

-- 1. Daily flight operations KPI
SELECT * FROM v_daily_airport_kpis ORDER BY operation_date;

-- 2. Airline flight volume and cancellation rate
SELECT al.airline_name, COUNT(*) AS total_flights,
       SUM(f.status='CANCELLED') AS cancelled,
       ROUND(100*SUM(f.status='CANCELLED')/COUNT(*),2) AS cancellation_pct
FROM flights f JOIN airlines al ON al.airline_id=f.airline_id
GROUP BY al.airline_id, al.airline_name ORDER BY total_flights DESC;

-- 3. Most common routes
SELECT origin_code, destination_code, COUNT(*) AS flight_count
FROM flights GROUP BY origin_code, destination_code
ORDER BY flight_count DESC LIMIT 25;

-- 4. Departures by terminal and gate
SELECT t.terminal_name, g.gate_code, COUNT(*) AS scheduled_flights
FROM flights f LEFT JOIN terminals t ON t.terminal_id=f.terminal_id
LEFT JOIN gates g ON g.gate_id=f.gate_id
GROUP BY t.terminal_name, g.gate_code ORDER BY scheduled_flights DESC;

-- 5. Flight status distribution by scope
SELECT flight_scope, status, COUNT(*) AS total
FROM flights GROUP BY flight_scope, status ORDER BY flight_scope, total DESC;

-- 6. Flights with no assigned aircraft
SELECT flight_id, flight_number, origin_code, destination_code, scheduled_departure, status
FROM flights WHERE aircraft_id IS NULL ORDER BY scheduled_departure;

-- 7. Aircraft utilization proxy (assigned flight count)
SELECT a.registration_no, al.airline_name, am.model_name, a.status,
       COUNT(f.flight_id) AS assigned_flights
FROM aircraft a JOIN airlines al ON al.airline_id=a.airline_id
JOIN aircraft_models am ON am.model_id=a.model_id
LEFT JOIN flights f ON f.aircraft_id=a.aircraft_id
GROUP BY a.aircraft_id ORDER BY assigned_flights DESC;

-- 8. Booking volume by cabin class
SELECT cabin_class, booking_status, COUNT(*) AS bookings,
       SUM(total_fare) AS booked_fare_total
FROM bookings GROUP BY cabin_class, booking_status;

-- 9. Successful payment revenue by method
SELECT payment_method, COUNT(*) AS transaction_count, SUM(amount) AS revenue
FROM payments WHERE payment_status='SUCCESS'
GROUP BY payment_method ORDER BY revenue DESC;

-- 10. Payment reconciliation candidates
SELECT b.pnr, b.total_fare, p.amount, p.payment_status, p.transaction_ref
FROM bookings b JOIN payments p ON p.booking_id=b.booking_id
WHERE p.payment_status <> 'SUCCESS' ORDER BY p.payment_status, b.booking_id;

-- 11. Confirmed booking manifest for a flight (replace 1 with flight_id)
SELECT * FROM v_booking_manifest WHERE booking_id IN
 (SELECT booking_id FROM bookings WHERE flight_id=1 AND booking_status='CONFIRMED');

-- 12. Check-in progress by flight
SELECT f.flight_number, f.origin_code, f.destination_code,
       COUNT(t.ticket_id) AS tickets,
       SUM(t.check_in_status='CHECKED_IN') AS checked_in,
       SUM(t.check_in_status='BOARDED') AS boarded,
       SUM(t.check_in_status='NO_SHOW') AS no_show
FROM flights f JOIN bookings b ON b.flight_id=f.flight_id
JOIN tickets t ON t.booking_id=b.booking_id
GROUP BY f.flight_id ORDER BY f.scheduled_departure LIMIT 100;

-- 13. Baggage status monitoring
SELECT baggage_status, COUNT(*) AS bag_count, ROUND(AVG(weight_kg),2) AS avg_weight_kg
FROM baggage GROUP BY baggage_status;

-- 14. Heavy baggage records
SELECT bg.tag_number, bg.weight_kg, bg.baggage_status, tk.ticket_number, b.pnr, f.flight_number
FROM baggage bg JOIN tickets tk ON tk.ticket_id=bg.ticket_id
JOIN bookings b ON b.booking_id=tk.booking_id JOIN flights f ON f.flight_id=b.flight_id
WHERE bg.weight_kg >= 25 ORDER BY bg.weight_kg DESC;

-- 15. Maintenance backlog by severity and status
SELECT severity, maintenance_status, COUNT(*) AS records
FROM maintenance_logs GROUP BY severity, maintenance_status
ORDER BY FIELD(severity,'CRITICAL','HIGH','MEDIUM','LOW');

-- 16. Aircraft with open critical/high maintenance
SELECT a.registration_no, am.model_name, m.severity, m.issue_description, m.reported_at
FROM maintenance_logs m JOIN aircraft a ON a.aircraft_id=m.aircraft_id
JOIN aircraft_models am ON am.model_id=a.model_id
WHERE m.maintenance_status <> 'RESOLVED' AND m.severity IN ('CRITICAL','HIGH')
ORDER BY FIELD(m.severity,'CRITICAL','HIGH'), m.reported_at;

-- 17. Passenger repeat-travel proxy
SELECT p.passenger_code, p.first_name, p.last_name, COUNT(b.booking_id) AS booking_count,
       SUM(b.booking_status='CONFIRMED') AS confirmed_count
FROM passengers p JOIN bookings b ON b.passenger_id=p.passenger_id
GROUP BY p.passenger_id ORDER BY booking_count DESC LIMIT 50;

-- 18. Booking value by nationality
SELECT p.nationality, COUNT(b.booking_id) AS bookings, SUM(b.total_fare) AS booked_value
FROM passengers p JOIN bookings b ON b.passenger_id=p.passenger_id
GROUP BY p.nationality ORDER BY booked_value DESC;

-- 19. Flights delayed by airline and route
SELECT al.airline_name, f.origin_code, f.destination_code, COUNT(*) AS delayed_count
FROM flights f JOIN airlines al ON al.airline_id=f.airline_id
WHERE f.status='DELAYED'
GROUP BY al.airline_name, f.origin_code, f.destination_code
ORDER BY delayed_count DESC LIMIT 30;

-- 20. Event timeline for a flight (replace 1 with flight_id)
SELECT f.flight_number, e.event_type, e.event_time, e.event_note
FROM flight_events e JOIN flights f ON f.flight_id=e.flight_id
WHERE f.flight_id=1 ORDER BY e.event_time;

-- 21. Gate status inventory
SELECT t.terminal_name, g.gate_type, g.status, COUNT(*) AS gates
FROM gates g JOIN terminals t ON t.terminal_id=g.terminal_id
GROUP BY t.terminal_name, g.gate_type, g.status;

-- 22. Runway and taxiway inventory
SELECT 'RUNWAY' AS asset_type, runway_code AS asset_code, status FROM runways
UNION ALL SELECT 'TAXIWAY', taxiway_code, status FROM taxiways;

-- 23. Flight schedule conflict candidate report: same gate with overlapping intervals
SELECT f1.gate_id, f1.flight_number AS flight_1, f2.flight_number AS flight_2,
       f1.scheduled_departure AS departure_1, f2.scheduled_departure AS departure_2
FROM flights f1 JOIN flights f2 ON f1.gate_id=f2.gate_id AND f1.flight_id < f2.flight_id
 AND f1.scheduled_departure < f2.scheduled_arrival
 AND f2.scheduled_departure < f1.scheduled_arrival
WHERE f1.gate_id IS NOT NULL ORDER BY f1.gate_id LIMIT 100;

-- 24. Flights with arrival before scheduled departure (should return zero due to CHECK)
SELECT flight_id, flight_number FROM flights WHERE scheduled_arrival <= scheduled_departure;

-- 25. Latest audit trail
SELECT * FROM audit_log ORDER BY created_at DESC LIMIT 50;
