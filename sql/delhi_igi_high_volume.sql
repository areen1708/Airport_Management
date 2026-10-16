-- Airport Operations Pro: Delhi IGI (DEL) Scale High-Volume Dataset
-- MySQL 8.0+. Keeps original schema intact and uses set-based bulk generation.

DROP DATABASE IF EXISTS airport_operations_pro;
CREATE DATABASE airport_operations_pro CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE airport_operations_pro;

-- ============================================================================
-- 1. YOUR EXACT ORIGINAL SCHEMA
-- ============================================================================

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

-- Completed from your cut-off point (runway_id INT NULL,)
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
  FOREIGN KEY (airline_id) REFERENCES airlines(airline_id),
  FOREIGN KEY (aircraft_id) REFERENCES aircraft(aircraft_id),
  FOREIGN KEY (runway_id) REFERENCES runways(runway_id),
  FOREIGN KEY (gate_id) REFERENCES gates(gate_id)
);

-- ============================================================================
-- 2. SEED STATIC INFRASTRUCTURE (DELHI IGI SCALE)
-- ============================================================================

INSERT INTO airlines (iata_code, airline_name, country, airline_type, active) VALUES
('6E', 'IndiGo', 'India', 'COMMERCIAL', TRUE),
('AI', 'Air India', 'India', 'COMMERCIAL', TRUE),
('IX', 'Air India Express', 'India', 'COMMERCIAL', TRUE),
('QP', 'Akasa Air', 'India', 'COMMERCIAL', TRUE),
('SG', 'SpiceJet', 'India', 'COMMERCIAL', TRUE),
('9I', 'Alliance Air', 'India', 'REGIONAL', TRUE),
('EK', 'Emirates', 'United Arab Emirates', 'COMMERCIAL', TRUE),
('QR', 'Qatar Airways', 'Qatar', 'COMMERCIAL', TRUE),
('LH', 'Lufthansa', 'Germany', 'COMMERCIAL', TRUE),
('BA', 'British Airways', 'United Kingdom', 'COMMERCIAL', TRUE),
('SQ', 'Singapore Airlines', 'Singapore', 'COMMERCIAL', TRUE),
('EY', 'Etihad Airways', 'United Arab Emirates', 'COMMERCIAL', TRUE),
('TG', 'Thai Airways', 'Thailand', 'COMMERCIAL', TRUE),
('JL', 'Japan Airlines', 'Japan', 'COMMERCIAL', TRUE),
('BZ', 'Blue Dart Aviation', 'India', 'CARGO', TRUE),
('5X', 'UPS Airlines', 'United States', 'CARGO', TRUE);

INSERT INTO aircraft_models (manufacturer, model_name, aircraft_category, passenger_capacity) VALUES
('Airbus', 'A320neo', 'NARROW_BODY', 186),
('Airbus', 'A321neo', 'NARROW_BODY', 222),
('Boeing', '737 MAX 8', 'NARROW_BODY', 189),
('ATR', '72-600', 'REGIONAL', 78),
('Boeing', '787-8 Dreamliner', 'WIDEBODY', 256),
('Boeing', '787-9 Dreamliner', 'WIDEBODY', 296),
('Boeing', '777-300ER', 'WIDEBODY', 342),
('Airbus', 'A350-900', 'WIDEBODY', 316),
('Airbus', 'A380-800', 'WIDEBODY', 484),
('Boeing', '757-200PCF', 'CARGO', 0),
('Boeing', '747-8F', 'CARGO', 0),
('Bombardier', 'Global 6000', 'PRIVATE', 14);

INSERT INTO terminals (terminal_name, terminal_type, description) VALUES
('Terminal 1 (T1)', 'DOMESTIC', 'Low-cost carrier domestic operations (IndiGo, SpiceJet)'),
('Terminal 2 (T2)', 'DOMESTIC', 'High-volume domestic operations (Akasa Air, IndiGo expansion)'),
('Terminal 3 (T3)', 'MIXED', 'Flagship integrated International and Full-Service Domestic hub'),
('Cargo Terminal Complex', 'CARGO', 'Dedicated perishable, express, and heavy freight zone');

-- Real Delhi IGI Runways
INSERT INTO runways (runway_code, length_m, surface_type, status) VALUES
('09/27', 2816, 'ASPHALT', 'OPEN'),
('10/28', 3815, 'ASPHALT', 'OPEN'),
('11R/29L', 4430, 'CONCRETE', 'OPEN'),
('11L/29R', 4400, 'CONCRETE', 'OPEN');

INSERT INTO taxiways (taxiway_code, status) VALUES
('TWY-A', 'OPEN'), ('TWY-B', 'OPEN'), ('TWY-C', 'OPEN'), ('TWY-D', 'OPEN'),
('TWY-E', 'OPEN'), ('TWY-F', 'OPEN'), ('TWY-G', 'OPEN'), ('TWY-H', 'OPEN'),
('TWY-J', 'OPEN'), ('TWY-K', 'OPEN'), ('TWY-L', 'OPEN'), ('TWY-M', 'OPEN'),
('TWY-N', 'OPEN'), ('TWY-P', 'OPEN'), ('TWY-Q', 'OPEN'), ('TWY-R', 'OPEN'),
('TWY-S', 'OPEN'), ('TWY-T', 'OPEN'), ('TWY-U', 'MAINTENANCE'), ('TWY-W', 'OPEN');

-- ============================================================================
-- 3. HIGH-SPEED MASS DATA GENERATOR (SET-BASED MULTIPLICATION)
-- ============================================================================

-- Speed up bulk insertion by disabling per-row autocommit and index checks temporarily
SET SESSION unique_checks = 0;
SET SESSION foreign_key_checks = 0;

-- Create a temporary helper table of 1,000 integers (0 to 999)
CREATE TEMPORARY TABLE seq_1000 (n INT PRIMARY KEY);
INSERT INTO seq_1000 (n)
SELECT d0.d + d1.d * 10 + d2.d * 100
FROM (SELECT 0 AS d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) d0
CROSS JOIN (SELECT 0 AS d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) d1
CROSS JOIN (SELECT 0 AS d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) d2;

-- 3A. Generate 160 Gates across T1, T2, T3, and Cargo
INSERT INTO gates (terminal_id, gate_code, gate_type, status)
SELECT 
  (n % 4) + 1 AS terminal_id,
  CONCAT('G', LPAD(n + 1, 3, '0')) AS gate_code,
  ELT((n % 4) + 1, 'DOMESTIC', 'DOMESTIC', 'INTERNATIONAL', 'REMOTE') AS gate_type,
  ELT(IF(n % 15 = 0, 4, (n % 2) + 1), 'AVAILABLE', 'IN_USE', 'CLOSED', 'MAINTENANCE') AS status
FROM seq_1000
WHERE n < 160;

-- 3B. Generate 600 Aircraft (VT-xxx Indian & International registrations)
INSERT INTO aircraft (registration_no, airline_id, model_id, manufacture_year, status)
SELECT 
  CONCAT(IF((n % 16) < 6, 'VT-', 'INT-'), LPAD(n + 100, 4, '0')) AS registration_no,
  (n % 16) + 1 AS airline_id,
  (n % 12) + 1 AS model_id,
  2010 + (n % 16) AS manufacture_year,
  IF(n % 25 = 0, 'MAINTENANCE', 'ACTIVE') AS status
FROM seq_1000
WHERE n < 600;

-- 3C. Generate 1,200 Pilots
INSERT INTO pilots (employee_code, first_name, last_name, license_no, license_type, years_experience, status)
SELECT 
  CONCAT('PLT-', LPAD(seq.id, 5, '0')) AS employee_code,
  ELT((seq.id % 16) + 1, 'Aarav','Vikram','Rohan','Kabir','Aditya','Siddharth','Neha','Ananya','Priya','Meera','Karan','Arjun','Riya','Dev','Ishaan','Tara') AS first_name,
  ELT(((seq.id DIV 16) % 16) + 1, 'Sharma','Singh','Verma','Kapoor','Nair','Iyer','Patel','Rathore','Mehta','Joshi','Chauhan','Reddy','Malhotra','Gupta','Bhatia','Khanna') AS last_name,
  CONCAT('DGCA-ATPL-', LPAD(seq.id, 6, '0')) AS license_no,
  ELT(IF(seq.id % 10 = 0, 3, 1), 'COMMERCIAL', 'PRIVATE', 'CARGO') AS license_type,
  1 + (seq.id % 32) AS years_experience,
  ELT((seq.id % 3) + 1, 'AVAILABLE', 'ON_DUTY', 'LEAVE') AS status
FROM (
  SELECT a.n + b.n * 1000 + 1 AS id
  FROM seq_1000 a
  CROSS JOIN (SELECT 0 AS n UNION ALL SELECT 1) b
  WHERE a.n + b.n * 1000 < 1200
) seq;

-- 3D. Generate 100,000 Passengers (High-Speed Cross Join)
-- NOTE: Change `WHERE n < 100` in `b` below to `WHERE n < 500` if you want 500,000 passengers!
INSERT INTO passengers (passenger_code, first_name, last_name, email, phone, nationality, date_of_birth, passport_no)
SELECT 
  CONCAT('PAX', LPAD(seq.id, 8, '0')) AS passenger_code,
  ELT((seq.id % 20) + 1, 'Aarav','Vivaan','Aditya','Vihaan','Arjun','Sai','Rohan','Krishna','Ishaan','Shaurya','Ananya','Diya','Aditi','Kiara','Pari','Riya','Neha','Pooja','Sneha','Kavya') AS first_name,
  ELT(((seq.id DIV 20) % 20) + 1, 'Sharma','Verma','Gupta','Malhotra','Bhatia','Saxena','Mehta','Joshi','Chauhan','Patel','Reddy','Nair','Iyer','Kapoor','Singh','Rathore','Khanna','Chopra','Bansal','Agarwal') AS last_name,
  CONCAT('pax', seq.id, '@', ELT((seq.id % 4) + 1, 'gmail.com', 'outlook.com', 'yahoo.in', 'icloud.com')) AS email,
  CONCAT('+91-9', LPAD((seq.id * 7919) % 1000000000, 9, '0')) AS phone,
  ELT(IF(seq.id % 5 = 0, (seq.id % 6) + 2, 1), 'India', 'United States', 'United Kingdom', 'UAE', 'Singapore', 'Germany', 'Japan') AS nationality,
  DATE_SUB('2006-01-01', INTERVAL (seq.id % 18000) DAY) AS date_of_birth,
  CONCAT('P', LPAD(seq.id, 8, '0')) AS passport_no
FROM (
  SELECT a.n + b.n * 1000 + 1 AS id
  FROM seq_1000 a
  CROSS JOIN (SELECT n FROM seq_1000 WHERE n < 100) b
) seq;

-- 3E. Generate 30,000 Realistic DEL Flights (~1,440 flights/day across ~21 days)
-- Every flight either departs from DEL or arrives at DEL.
INSERT INTO flights (
  flight_number, airline_id, aircraft_id, origin_code, destination_code,
  flight_scope, scheduled_departure, scheduled_arrival,
  actual_departure, actual_arrival, status, runway_id, gate_id
)
SELECT 
  CONCAT(
    ELT(airline_num, '6E','AI','IX','QP','SG','9I','EK','QR','LH','BA','SQ','EY','TG','JL','BZ','5X'),
    '-',
    LPAD(100 + (id % 899), 3, '0')
  ) AS flight_number,
  airline_num AS airline_id,
  ((id % 600) + 1) AS aircraft_id,
  IF(id % 2 = 0, 'DEL', other_airport) AS origin_code,
  IF(id % 2 = 0, other_airport, 'DEL') AS destination_code,
  CASE 
    WHEN airline_num IN (15, 16) THEN 'CARGO'
    WHEN airline_num = 6 THEN 'REGIONAL'
    WHEN airline_num >= 7 THEN 'INTERNATIONAL'
    ELSE 'DOMESTIC'
  END AS flight_scope,
  sched_dep AS scheduled_departure,
  DATE_ADD(sched_dep, INTERVAL flight_duration_mins MINUTE) AS scheduled_arrival,
  CASE 
    WHEN status_code IN ('DEPARTED', 'ARRIVED') THEN DATE_ADD(sched_dep, INTERVAL (id % 15) MINUTE)
    WHEN status_code = 'DELAYED' THEN DATE_ADD(sched_dep, INTERVAL (45 + (id % 120)) MINUTE)
    ELSE NULL
  END AS actual_departure,
  CASE 
    WHEN status_code = 'ARRIVED' THEN DATE_ADD(sched_dep, INTERVAL (flight_duration_mins + (id % 15)) MINUTE)
    WHEN status_code = 'DELAYED' THEN DATE_ADD(sched_dep, INTERVAL (flight_duration_mins + 45 + (id % 120)) MINUTE)
    ELSE NULL
  END AS actual_arrival,
  status_code AS status,
  ((id % 4) + 1) AS runway_id,
  ((id % 160) + 1) AS gate_id
FROM (
  SELECT 
    raw.id,
    (raw.id % 16) + 1 AS airline_num,
    CASE 
      WHEN (raw.id % 16) + 1 >= 7 AND (raw.id % 16) + 1 <= 14 THEN 
        ELT((raw.id % 10) + 1, 'DXB','DOH','LHR','FRA','SIN','AUH','BKK','NRT','JFK','CDG')
      ELSE 
        ELT((raw.id % 14) + 1, 'BOM','BLR','HYD','MAA','CCU','JAI','PNQ','AMD','GOI','COK','LKO','ATQ','SXR','GAU')
    END AS other_airport,
    DATE_ADD('2026-10-01 00:00:00', INTERVAL (raw.id * 60) SECOND) AS sched_dep,
    IF((raw.id % 16) + 1 BETWEEN 7 AND 14, 240 + (raw.id % 300), 75 + (raw.id % 95)) AS flight_duration_mins,
    CASE 
      WHEN raw.id < 20000 THEN 
        ELT(IF(raw.id % 20 = 0, 2, 1), 'ARRIVED', 'CANCELLED')
      WHEN raw.id BETWEEN 20000 AND 21500 THEN 
        ELT((raw.id % 4) + 1, 'DEPARTED', 'BOARDING', 'DELAYED', 'DIVERTED')
      ELSE 'SCHEDULED'
    END AS status_code
  FROM (
    SELECT a.n + b.n * 1000 + 1 AS id
    FROM seq_1000 a
    CROSS JOIN (SELECT n FROM seq_1000 WHERE n < 30) b
  ) raw
) generated_flights;

-- Clean up and restore safety checks
DROP TEMPORARY TABLE seq_1000;
SET SESSION foreign_key_checks = 1;
SET SESSION unique_checks = 1;

-- Add high-performance indexes so querying 100k+ rows doesn't lag
CREATE INDEX idx_flights_origin_dest ON flights(origin_code, destination_code);
CREATE INDEX idx_flights_sched_dep ON flights(scheduled_departure);
CREATE INDEX idx_flights_status ON flights(status);
