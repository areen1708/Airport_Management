-- Airport Operations Pro: Jaipur International Airport-inspired synthetic dataset
-- MySQL 8.0+. All data is synthetic and for academic demonstration only; it is NOT live airport data.
-- Creates 1,000 flights over 100 calendar days: exactly 10 Jaipur-connected flights per day.
-- Every flight receives one unique synthetic passenger per aircraft seat, plus matching booking,
-- ticket, payment, and baggage rows (~190,000-200,000 passengers in total).
-- WARNING: this script drops/recreates airport_operations_pro and loads about 200,000 passengers.
-- Run the WHOLE file in one go (MySQL Workbench or: mysql < airport_operations_pro.sql).

DROP DATABASE IF EXISTS airport_operations_pro;
CREATE DATABASE airport_operations_pro CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE airport_operations_pro;

SET NAMES utf8mb4;
SET SESSION cte_max_recursion_depth = 1000000;
SET FOREIGN_KEY_CHECKS = 0;

-- ---------------------------------------------------------------------------
-- Schema
-- ---------------------------------------------------------------------------
CREATE TABLE airlines (
    airline_id INT PRIMARY KEY AUTO_INCREMENT,
    iata_code CHAR(2) NOT NULL UNIQUE,
    airline_name VARCHAR(100) NOT NULL,
    country VARCHAR(60) NOT NULL,
    airline_type ENUM('COMMERCIAL','REGIONAL','CHARTER','CARGO') NOT NULL DEFAULT 'COMMERCIAL',
    active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE aircraft_models (
    model_id INT PRIMARY KEY AUTO_INCREMENT,
    manufacturer VARCHAR(60) NOT NULL,
    model_name VARCHAR(60) NOT NULL,
    aircraft_category ENUM('NARROW_BODY','REGIONAL','WIDEBODY','CARGO','PRIVATE') NOT NULL,
    passenger_capacity INT NOT NULL,
    UNIQUE KEY uq_model (manufacturer, model_name)
);

CREATE TABLE aircraft (
    aircraft_id INT PRIMARY KEY AUTO_INCREMENT,
    registration_no VARCHAR(16) NOT NULL UNIQUE,
    airline_id INT NOT NULL,
    model_id INT NOT NULL,
    manufacture_year YEAR NOT NULL,
    status ENUM('ACTIVE','MAINTENANCE','GROUNDED','RETIRED') NOT NULL DEFAULT 'ACTIVE',
    FOREIGN KEY (airline_id) REFERENCES airlines(airline_id),
    FOREIGN KEY (model_id) REFERENCES aircraft_models(model_id)
);

CREATE TABLE terminals (
    terminal_id INT PRIMARY KEY AUTO_INCREMENT,
    terminal_name VARCHAR(50) NOT NULL UNIQUE,
    terminal_type ENUM('DOMESTIC','INTERNATIONAL','CARGO','MIXED') NOT NULL,
    description VARCHAR(255)
);

CREATE TABLE gates (
    gate_id INT PRIMARY KEY AUTO_INCREMENT,
    terminal_id INT NOT NULL,
    gate_code VARCHAR(8) NOT NULL UNIQUE,
    gate_type ENUM('DOMESTIC','INTERNATIONAL','BUS','REMOTE') NOT NULL,
    status ENUM('AVAILABLE','IN_USE','CLOSED','MAINTENANCE') NOT NULL DEFAULT 'AVAILABLE',
    FOREIGN KEY (terminal_id) REFERENCES terminals(terminal_id)
);

CREATE TABLE runways (
    runway_id INT PRIMARY KEY AUTO_INCREMENT,
    runway_code VARCHAR(12) NOT NULL UNIQUE,
    length_m INT NOT NULL,
    surface_type ENUM('ASPHALT','CONCRETE') NOT NULL DEFAULT 'ASPHALT',
    status ENUM('OPEN','CLOSED','MAINTENANCE') NOT NULL DEFAULT 'OPEN'
);

CREATE TABLE taxiways (
    taxiway_id INT PRIMARY KEY AUTO_INCREMENT,
    taxiway_code VARCHAR(12) NOT NULL UNIQUE,
    status ENUM('OPEN','CLOSED','MAINTENANCE') NOT NULL DEFAULT 'OPEN'
);

CREATE TABLE pilots (
    pilot_id INT PRIMARY KEY AUTO_INCREMENT,
    employee_code VARCHAR(16) NOT NULL UNIQUE,
    first_name VARCHAR(60) NOT NULL,
    last_name VARCHAR(60) NOT NULL,
    license_no VARCHAR(30) NOT NULL UNIQUE,
    license_type ENUM('COMMERCIAL','PRIVATE','CARGO') NOT NULL,
    years_experience TINYINT NOT NULL,
    status ENUM('AVAILABLE','ON_DUTY','LEAVE','SUSPENDED') NOT NULL DEFAULT 'AVAILABLE'
);

CREATE TABLE passengers (
    passenger_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    passenger_code VARCHAR(20) NOT NULL UNIQUE,
    first_name VARCHAR(60) NOT NULL,
    last_name VARCHAR(60) NOT NULL,
    email VARCHAR(120) NOT NULL UNIQUE,
    phone VARCHAR(20) NOT NULL,
    nationality VARCHAR(60) NOT NULL,
    date_of_birth DATE NOT NULL,
    passport_no VARCHAR(20) NULL UNIQUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE flights (
    flight_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    flight_number VARCHAR(12) NOT NULL,
    airline_id INT NOT NULL,
    aircraft_id INT NULL,
    origin_code CHAR(3) NOT NULL,
    destination_code CHAR(3) NOT NULL,
    flight_scope ENUM('DOMESTIC','REGIONAL','INTERNATIONAL','CHARTER','CARGO') NOT NULL,
    scheduled_departure DATETIME NOT NULL,
    scheduled_arrival DATETIME NOT NULL,
    actual_departure DATETIME NULL,
    actual_arrival DATETIME NULL,
    status ENUM('SCHEDULED','BOARDING','DEPARTED','ARRIVED','DELAYED','CANCELLED','DIVERTED') NOT NULL DEFAULT 'SCHEDULED',
    runway_id INT NULL,
    gate_id INT NULL,
    terminal_id INT NULL,
    fare_base DECIMAL(10,2) NOT NULL DEFAULT 2500.00,
    KEY idx_flight_departure (scheduled_departure),
    KEY idx_flight_route (origin_code, destination_code),
    KEY idx_flight_status (status),
    FOREIGN KEY (airline_id) REFERENCES airlines(airline_id),
    FOREIGN KEY (aircraft_id) REFERENCES aircraft(aircraft_id),
    FOREIGN KEY (runway_id) REFERENCES runways(runway_id),
    FOREIGN KEY (gate_id) REFERENCES gates(gate_id),
    FOREIGN KEY (terminal_id) REFERENCES terminals(terminal_id),
    CONSTRAINT flights_chk_1 CHECK (origin_code <> destination_code),
    CONSTRAINT flights_chk_2 CHECK (scheduled_arrival > scheduled_departure)
);

CREATE TABLE bookings (
    booking_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    pnr CHAR(6) NOT NULL UNIQUE,
    passenger_id BIGINT NOT NULL,
    flight_id BIGINT NOT NULL,
    booking_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    cabin_class ENUM('ECONOMY','PREMIUM_ECONOMY','BUSINESS','FIRST') NOT NULL DEFAULT 'ECONOMY',
    booking_status ENUM('CONFIRMED','CANCELLED','WAITLISTED','REFUNDED') NOT NULL DEFAULT 'CONFIRMED',
    total_fare DECIMAL(10,2) NOT NULL,
    KEY idx_booking_passenger (passenger_id),
    KEY idx_booking_flight (flight_id),
    FOREIGN KEY (passenger_id) REFERENCES passengers(passenger_id),
    FOREIGN KEY (flight_id) REFERENCES flights(flight_id)
);

CREATE TABLE tickets (
    ticket_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    booking_id BIGINT NOT NULL,
    ticket_number VARCHAR(20) NOT NULL UNIQUE,
    seat_number VARCHAR(5) NULL,
    check_in_status ENUM('NOT_CHECKED_IN','CHECKED_IN','BOARDED','NO_SHOW') NOT NULL DEFAULT 'NOT_CHECKED_IN',
    checked_in_at DATETIME NULL,
    baggage_kg DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    UNIQUE KEY booking_id (booking_id),
    FOREIGN KEY (booking_id) REFERENCES bookings(booking_id)
);

CREATE TABLE payments (
    payment_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    booking_id BIGINT NOT NULL,
    transaction_ref VARCHAR(32) NOT NULL UNIQUE,
    payment_method ENUM('UPI','CARD','NETBANKING','CASH','WALLET') NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    payment_status ENUM('SUCCESS','PENDING','FAILED','REFUNDED') NOT NULL,
    paid_at DATETIME NULL,
    KEY idx_payment_status (payment_status),
    FOREIGN KEY (booking_id) REFERENCES bookings(booking_id)
);

CREATE TABLE baggage (
    baggage_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    ticket_id BIGINT NOT NULL,
    tag_number VARCHAR(24) NOT NULL UNIQUE,
    weight_kg DECIMAL(5,2) NOT NULL,
    baggage_status ENUM('ACCEPTED','SCREENING','LOADED','ARRIVED','HELD','LOST') NOT NULL DEFAULT 'ACCEPTED',
    FOREIGN KEY (ticket_id) REFERENCES tickets(ticket_id)
);

CREATE TABLE flight_events (
    event_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    flight_id BIGINT NOT NULL,
    event_type ENUM('SCHEDULE_CREATED','GATE_ASSIGNED','DELAYED','BOARDING_STARTED','DEPARTED','ARRIVED','CANCELLED','STATUS_UPDATED') NOT NULL,
    event_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    event_note VARCHAR(255) NOT NULL,
    KEY idx_event_flight_time (flight_id, event_time),
    FOREIGN KEY (flight_id) REFERENCES flights(flight_id)
);

CREATE TABLE maintenance_logs (
    maintenance_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    aircraft_id INT NOT NULL,
    reported_at DATETIME NOT NULL,
    issue_description VARCHAR(255) NOT NULL,
    severity ENUM('LOW','MEDIUM','HIGH','CRITICAL') NOT NULL,
    maintenance_status ENUM('OPEN','IN_PROGRESS','RESOLVED') NOT NULL DEFAULT 'OPEN',
    resolved_at DATETIME NULL,
    FOREIGN KEY (aircraft_id) REFERENCES aircraft(aircraft_id)
);

CREATE TABLE audit_log (
    audit_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(40) NOT NULL,
    action_name VARCHAR(80) NOT NULL,
    entity_name VARCHAR(80) NOT NULL,
    entity_id VARCHAR(40) DEFAULT NULL,
    details VARCHAR(500) DEFAULT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_audit_created (created_at)
);

CREATE TABLE system_users (
    user_id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(40) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role ENUM('ADMIN','OPERATIONS','CUSTOMER_SERVICE') NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE
);

-- ---------------------------------------------------------------------------
-- Reference data
-- ---------------------------------------------------------------------------
INSERT INTO airlines (iata_code, airline_name, country, airline_type, active) VALUES
('6E','IndiGo','India','COMMERCIAL',TRUE),
('AI','Air India','India','COMMERCIAL',TRUE),
('SG','SpiceJet','India','COMMERCIAL',TRUE),
('UK','Vistara','India','COMMERCIAL',TRUE),
('IX','Air India Express','India','COMMERCIAL',TRUE),
('G8','Go First','India','COMMERCIAL',TRUE),
('EK','Emirates','United Arab Emirates','COMMERCIAL',TRUE),
('QR','Qatar Airways','Qatar','COMMERCIAL',TRUE),
('SQ','Singapore Airlines','Singapore','COMMERCIAL',TRUE),
('TG','Thai Airways','Thailand','COMMERCIAL',TRUE),
('MH','Malaysia Airlines','Malaysia','COMMERCIAL',TRUE),
('LH','Lufthansa','Germany','COMMERCIAL',TRUE),
('BA','British Airways','United Kingdom','COMMERCIAL',TRUE),
('AF','Air France','France','COMMERCIAL',TRUE),
('KL','KLM Royal Dutch Airlines','Netherlands','COMMERCIAL',TRUE),
('QF','Qantas','Australia','COMMERCIAL',TRUE),
('9I','Alliance Air','India','REGIONAL',TRUE),
('2T','TruJet','India','REGIONAL',TRUE),
('CV','Cargolux','Luxembourg','CARGO',TRUE);

INSERT INTO aircraft_models (manufacturer, model_name, aircraft_category, passenger_capacity) VALUES
('ATR','ATR 72-600','REGIONAL',72),          -- 1
('Airbus','A320neo','NARROW_BODY',186),      -- 2
('Airbus','A321neo','NARROW_BODY',232),      -- 3
('Boeing','737-800','NARROW_BODY',189),      -- 4
('Boeing','737 MAX 8','NARROW_BODY',210),    -- 5
('Airbus','A330-300','WIDEBODY',295),        -- 6
('Boeing','777-300ER','WIDEBODY',354),       -- 7
('Boeing','787-9 Dreamliner','WIDEBODY',296),-- 8
('Airbus','A350-900','WIDEBODY',325),        -- 9
('Embraer','E190','REGIONAL',98),            -- 10
('Boeing','737-900ER','NARROW_BODY',215),    -- 11
('Airbus','A319','NARROW_BODY',156),         -- 12
('Boeing','767-300ER','WIDEBODY',269),       -- 13
('ATR','ATR 42-600','REGIONAL',48),          -- 14
('Bombardier','CRJ900','REGIONAL',90),       -- 15
('Boeing','777F','CARGO',0),                 -- 16
('Airbus','A330-200F','CARGO',0),            -- 17
('Cessna','Citation X','PRIVATE',12);        -- 18

INSERT INTO terminals (terminal_name, terminal_type, description) VALUES
('Terminal 1','DOMESTIC','Domestic arrivals and departures'),
('Terminal 2','INTERNATIONAL','International arrivals and departures'),
('Terminal 3','MIXED','Integrated domestic and international operations'),
('Cargo Terminal','CARGO','Freight and cargo handling facility');

INSERT INTO runways (runway_code, length_m, surface_type, status) VALUES
('09/27', 3500, 'ASPHALT', 'OPEN'),
('11/29', 2800, 'ASPHALT', 'OPEN'),
('15/33', 3000, 'CONCRETE', 'MAINTENANCE');

INSERT INTO taxiways (taxiway_code, status)
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 12)
SELECT CONCAT('T', LPAD(n, 2, '0')), ELT(1 + (n % 4), 'OPEN', 'OPEN', 'OPEN', 'MAINTENANCE') FROM seq;

-- ---------------------------------------------------------------------------
-- Fleet (110 passenger aircraft + 10 cargo/private), gates, pilots
-- ---------------------------------------------------------------------------
INSERT INTO aircraft (registration_no, airline_id, model_id, manufacture_year, status)
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 120)
SELECT CONCAT('VT-', LPAD(n, 3, '0')),
       1 + (n % 19),
       CASE WHEN n <= 110 THEN 1 + (n % 15) ELSE 16 + (n % 3) END,
       2005 + (n % 20),
       ELT(1 + (n % 5), 'ACTIVE', 'ACTIVE', 'ACTIVE', 'MAINTENANCE', 'GROUNDED')
FROM seq;

INSERT INTO gates (terminal_id, gate_code, gate_type, status)
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 26)
SELECT 1 + (n % 4), CONCAT('G', LPAD(n, 2, '0')),
       ELT(1 + (n % 4), 'DOMESTIC', 'INTERNATIONAL', 'BUS', 'REMOTE'),
       ELT(1 + (n % 5), 'AVAILABLE', 'AVAILABLE', 'IN_USE', 'CLOSED', 'MAINTENANCE')
FROM seq;

INSERT INTO pilots (employee_code, first_name, last_name, license_no, license_type, years_experience, status)
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 300)
SELECT CONCAT('PLT', LPAD(n, 4, '0')),
       ELT(1 + (n % 10), 'Arjun', 'Rohan', 'Vikram', 'Sandeep', 'Karan', 'Meera', 'Sneha', 'Pooja', 'Rahul', 'Nisha'),
       ELT(1 + (n % 10), 'Mehta', 'Kapoor', 'Joshi', 'Chopra', 'Bose', 'Rao', 'Menon', 'Kulkarni', 'Ahuja', 'Sethi'),
       CONCAT('LIC-', LPAD(n, 5, '0')),
       ELT(1 + (n % 3), 'COMMERCIAL', 'PRIVATE', 'CARGO'),
       3 + (n % 35),
       ELT(1 + (n % 5), 'AVAILABLE', 'ON_DUTY', 'ON_DUTY', 'LEAVE', 'SUSPENDED')
FROM seq;

-- ---------------------------------------------------------------------------
-- 1,000 flights over 100 days: exactly 10 Jaipur-connected flights per day
-- ---------------------------------------------------------------------------
INSERT INTO flights (flight_id, flight_number, airline_id, aircraft_id, origin_code, destination_code, flight_scope,
                     scheduled_departure, scheduled_arrival, actual_departure, actual_arrival,
                     status, runway_id, gate_id, terminal_id, fare_base)
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 1000)
SELECT n,
       CONCAT(ELT(1 + (n % 6), '6E', 'AI', 'SG', 'UK', 'IX', 'G8'), LPAD(n, 4, '0')),
       1 + (n % 6),
       1 + (n % 110),
       origin, dest, 'DOMESTIC',
       dep,
       DATE_ADD(dep, INTERVAL dur MINUTE),
       CASE WHEN st IN ('DEPARTED', 'ARRIVED') THEN DATE_ADD(dep, INTERVAL (n % 25) MINUTE) ELSE NULL END,
       CASE WHEN st = 'ARRIVED' THEN DATE_ADD(DATE_ADD(dep, INTERVAL dur MINUTE), INTERVAL (n % 25) MINUTE) ELSE NULL END,
       st,
       1 + (n % 3),
       1 + (n % 26),
       1 + (n % 4),
       ROUND(2000 + (n % 10) * 500, 2)
FROM (
    SELECT n,
           DATE_ADD(DATE_ADD(CURDATE() - INTERVAL (99 - ((n - 1) DIV 10)) DAY,
                             INTERVAL (5 + ((n - 1) MOD 10) * 2) HOUR),
                    INTERVAL ((n % 4) * 15) MINUTE) AS dep,
           (60 + (n % 5) * 30) AS dur,
           CASE (n % 6) WHEN 0 THEN 'JAI' WHEN 1 THEN 'DEL' WHEN 2 THEN 'BOM' WHEN 3 THEN 'BLR' WHEN 4 THEN 'JAI' ELSE 'AMD' END AS origin,
           CASE (n % 6) WHEN 0 THEN 'DEL' WHEN 1 THEN 'JAI' WHEN 2 THEN 'JAI' WHEN 3 THEN 'JAI' WHEN 4 THEN 'BOM' ELSE 'JAI' END AS dest,
           CASE
               WHEN CURDATE() - INTERVAL (99 - ((n - 1) DIV 10)) DAY < CURDATE() THEN IF(n % 10 < 9, 'ARRIVED', 'DEPARTED')
               WHEN CURDATE() - INTERVAL (99 - ((n - 1) DIV 10)) DAY = CURDATE() THEN ELT(1 + (n % 5), 'SCHEDULED', 'BOARDING', 'DEPARTED', 'ARRIVED', 'DELAYED')
               ELSE CASE WHEN n % 13 = 0 THEN 'CANCELLED' WHEN n % 9 = 0 THEN 'DELAYED' ELSE 'SCHEDULED' END
           END AS st
    FROM seq
) t;

-- ---------------------------------------------------------------------------
-- Seat manifest: one row per (flight, seat) -> drives passengers + downstream rows
-- ---------------------------------------------------------------------------
CREATE TEMPORARY TABLE _seat_manifest (
    seq BIGINT PRIMARY KEY,
    flight_id BIGINT NOT NULL,
    seat_no INT NOT NULL
) ENGINE = InnoDB;

INSERT INTO _seat_manifest (seq, flight_id, seat_no)
WITH RECURSIVE seats(s) AS (SELECT 1 UNION ALL SELECT s + 1 FROM seats WHERE s < 400)
SELECT ROW_NUMBER() OVER (ORDER BY f.flight_id, s.s),
       f.flight_id,
       s.s
FROM flights f
JOIN aircraft a ON a.aircraft_id = f.aircraft_id
JOIN aircraft_models m ON m.model_id = a.model_id
JOIN seats s ON s.s <= m.passenger_capacity
WHERE m.passenger_capacity > 0;

-- ---------------------------------------------------------------------------
-- Passengers (one per seat), bookings, tickets, payments, baggage
-- ---------------------------------------------------------------------------
INSERT INTO passengers (passenger_id, passenger_code, first_name, last_name, email, phone, nationality, date_of_birth, passport_no)
SELECT seq, CONCAT('PAX', LPAD(seq, 8, '0')),
       ELT(1 + (seq % 10), 'Aarav', 'Vivaan', 'Aditya', 'Ishaan', 'Rohan', 'Ananya', 'Diya', 'Priya', 'Neha', 'Kavya'),
       ELT(1 + (seq % 10), 'Sharma', 'Patel', 'Singh', 'Gupta', 'Verma', 'Nair', 'Reddy', 'Iyer', 'Khan', 'Das'),
       CONCAT('passenger', seq, '@example.com'),
       CONCAT('+91-9', LPAD(100000000 + seq, 9, '0')),
       ELT(1 + (seq % 8), 'India', 'India', 'India', 'United Arab Emirates', 'Singapore', 'Thailand', 'United Kingdom', 'Germany'),
       DATE_ADD('1975-01-01', INTERVAL (seq % 9500) DAY),
       CONCAT('P', LPAD(seq, 8, '0'))
FROM _seat_manifest;

INSERT INTO bookings (booking_id, pnr, passenger_id, flight_id, booking_date, cabin_class, booking_status, total_fare)
SELECT seq, LPAD(CONV(seq, 10, 36), 6, '0'), seq, flight_id,
       NOW() - INTERVAL (seq % 100) DAY,
       ELT(1 + (seq % 4), 'ECONOMY', 'ECONOMY', 'PREMIUM_ECONOMY', 'BUSINESS'),
       CASE WHEN seq % 15 = 0 THEN 'CANCELLED' WHEN seq % 15 = 1 THEN 'WAITLISTED' ELSE 'CONFIRMED' END,
       1500 + (seq % 20) * 250 + (seq % 7) * 100
FROM _seat_manifest;

INSERT INTO tickets (ticket_id, booking_id, ticket_number, seat_number, check_in_status, checked_in_at, baggage_kg)
SELECT seq, seq, CONCAT('TKT', LPAD(seq, 8, '0')),
       CONCAT(CEIL(seat_no / 6), SUBSTRING('ABCDEF', 1 + ((seat_no - 1) % 6), 1)),
       ELT(1 + (seq % 4), 'NOT_CHECKED_IN', 'CHECKED_IN', 'BOARDED', 'NO_SHOW'),
       CASE WHEN seq % 4 IN (1, 2) THEN NOW() - INTERVAL (seq % 5) DAY ELSE NULL END,
       ROUND((seq % 30) * 0.7, 2)
FROM _seat_manifest;

INSERT INTO payments (payment_id, booking_id, transaction_ref, payment_method, amount, payment_status, paid_at)
SELECT seq, seq, CONCAT('TXN', LPAD(seq, 10, '0')),
       ELT(1 + (seq % 5), 'UPI', 'CARD', 'NETBANKING', 'CASH', 'WALLET'),
       1500 + (seq % 20) * 250 + (seq % 7) * 100,
       CASE WHEN seq % 20 = 0 THEN 'PENDING' WHEN seq % 50 = 0 THEN 'FAILED' ELSE 'SUCCESS' END,
       NOW() - INTERVAL (seq % 100) DAY
FROM _seat_manifest;

INSERT INTO baggage (baggage_id, ticket_id, tag_number, weight_kg, baggage_status)
SELECT seq, seq, CONCAT('BAG', LPAD(seq, 8, '0')),
       ROUND(8 + (seq % 22) * 0.7, 2),
       ELT(1 + (seq % 6), 'ACCEPTED', 'SCREENING', 'LOADED', 'ARRIVED', 'ARRIVED', 'HELD')
FROM _seat_manifest
WHERE seq % 10 < 7;

DROP TEMPORARY TABLE _seat_manifest;

-- ---------------------------------------------------------------------------
-- Flight events, maintenance, audit, users
-- ---------------------------------------------------------------------------
INSERT INTO flight_events (flight_id, event_type, event_time, event_note)
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 3000)
SELECT 1 + (n % 1000),
       ELT(1 + (n % 8), 'SCHEDULE_CREATED', 'GATE_ASSIGNED', 'BOARDING_STARTED', 'DEPARTED', 'ARRIVED', 'DELAYED', 'STATUS_UPDATED', 'CANCELLED'),
       NOW() - INTERVAL (n % 100) DAY + INTERVAL (n % 24) HOUR,
       CONCAT('Automated event #', n, ' recorded by operations control')
FROM seq;

INSERT INTO maintenance_logs (aircraft_id, reported_at, issue_description, severity, maintenance_status, resolved_at)
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 500)
SELECT 1 + (n % 120),
       NOW() - INTERVAL (n % 90) DAY,
       ELT(1 + (n % 6),
           'Routine A-check inspection',
           'Hydraulic pressure warning on landing gear',
           'Cabin pressurization sensor fault',
           'Engine oil consumption above threshold',
           'Avionics software update required',
           'Tyre wear replacement on main gear'),
       ELT(1 + (n % 4), 'LOW', 'MEDIUM', 'HIGH', 'CRITICAL'),
       ELT(1 + (n % 3), 'OPEN', 'IN_PROGRESS', 'RESOLVED'),
       CASE WHEN n % 3 = 2 THEN NOW() - INTERVAL (n % 5) DAY ELSE NULL END
FROM seq;

INSERT INTO audit_log (username, action_name, entity_name, entity_id, details) VALUES
('admin', 'SEED_DATABASE', 'system', NULL, 'Full synthetic dataset loaded'),
('admin', 'IMPORT_FLIGHTS', 'flights', '1000', 'Created 1000 Jaipur-connected flights over 100 days'),
('admin', 'IMPORT_PASSENGERS', 'passengers', '~196000', 'Created one synthetic passenger per aircraft seat'),
('admin', 'IMPORT_BOOKINGS', 'bookings', '~196000', 'Created matching bookings, tickets and payments'),
('admin', 'ASSIGN_GATES', 'gates', '26', 'Gate allocation generated'),
('admin', 'SEED_COMPLETED', 'system', NULL, 'Airport Operations Pro dataset ready');

INSERT INTO system_users (username, password_hash, role, active) VALUES
('admin', 'pbkdf2$120000$1/d9af9dv7I/9N5NNCWWkA==$/I6wu/CxCD8X8JApgPkBkos+Rc7D1op65FImOApr1C0=', 'ADMIN', TRUE);

-- ---------------------------------------------------------------------------
-- Reporting views
-- ---------------------------------------------------------------------------
CREATE VIEW v_flight_operations AS
SELECT f.flight_id, f.flight_number, al.airline_name, f.origin_code, f.destination_code,
       f.flight_scope, f.scheduled_departure, f.scheduled_arrival, f.status,
       t.terminal_name, g.gate_code, r.runway_code, ac.registration_no, am.model_name
FROM flights f
JOIN airlines al ON al.airline_id = f.airline_id
LEFT JOIN terminals t ON t.terminal_id = f.terminal_id
LEFT JOIN gates g ON g.gate_id = f.gate_id
LEFT JOIN runways r ON r.runway_id = f.runway_id
LEFT JOIN aircraft ac ON ac.aircraft_id = f.aircraft_id
LEFT JOIN aircraft_models am ON am.model_id = ac.model_id;

CREATE VIEW v_booking_manifest AS
SELECT b.booking_id, b.pnr, p.passenger_code, CONCAT(p.first_name, ' ', p.last_name) AS passenger_name,
       f.flight_number, f.origin_code, f.destination_code, f.scheduled_departure,
       b.cabin_class, b.booking_status, tk.ticket_number, tk.seat_number, tk.check_in_status,
       py.payment_status, b.total_fare
FROM bookings b
JOIN passengers p ON p.passenger_id = b.passenger_id
JOIN flights f ON f.flight_id = b.flight_id
LEFT JOIN tickets tk ON tk.booking_id = b.booking_id
LEFT JOIN payments py ON py.booking_id = b.booking_id;

CREATE VIEW v_daily_airport_kpis AS
SELECT CAST(scheduled_departure AS DATE) AS operation_date,
       COUNT(*) AS scheduled_flights,
       SUM(status = 'CANCELLED') AS cancelled_flights,
       SUM(status = 'DELAYED') AS delayed_flights,
       SUM(status IN ('DEPARTED', 'ARRIVED')) AS departed_or_arrived_flights
FROM flights
GROUP BY CAST(scheduled_departure AS DATE);

SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------------
-- Quick sanity output
-- ---------------------------------------------------------------------------
SELECT 'airlines' AS entity, COUNT(*) AS rows_loaded FROM airlines
UNION ALL SELECT 'aircraft', COUNT(*) FROM aircraft
UNION ALL SELECT 'pilots', COUNT(*) FROM pilots
UNION ALL SELECT 'gates', COUNT(*) FROM gates
UNION ALL SELECT 'flights', COUNT(*) FROM flights
UNION ALL SELECT 'passengers', COUNT(*) FROM passengers
UNION ALL SELECT 'bookings', COUNT(*) FROM bookings
UNION ALL SELECT 'tickets', COUNT(*) FROM tickets
UNION ALL SELECT 'payments', COUNT(*) FROM payments
UNION ALL SELECT 'baggage', COUNT(*) FROM baggage
UNION ALL SELECT 'flight_events', COUNT(*) FROM flight_events
UNION ALL SELECT 'maintenance_logs', COUNT(*) FROM maintenance_logs
UNION ALL SELECT 'audit_log', COUNT(*) FROM audit_log
UNION ALL SELECT 'system_users', COUNT(*) FROM system_users;
