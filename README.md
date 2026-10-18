# Airport Operations Pro — Jaipur Airport-inspired Academic Project

A Java 17 + MySQL 8 project for a second-year BTech CSE portfolio. The database and records are **synthetic academic demo data**, not official Jaipur International Airport operational data. The project is not suitable for actual airport operations.

## Features

- Relational schema with airlines, aircraft models, aircraft, pilots, terminals, gates, runways, taxiways, passengers, flights, bookings, tickets, payments, baggage, maintenance, flight events and audit log.
- Seed procedure creates 120 aircraft, 150 pilots, 3,000 passengers, 4,000 flights, 6,000 bookings, tickets/payments, baggage, maintenance records and flight event history.
- SQL views for flight operations, booking manifest and daily KPIs.
- Java JDBC console with sign-in and role-based menus: customer-service registration, admin bootstrap using an environment secret, PBKDF2 password hashing, KPI dashboard, flight search, today's operations, passenger search with full-profile view/edit (name, email, phone, nationality, date of birth and optional passport number), PNR lookup, transactional booking creation, check-in, flight-status updates with event history, maintenance overview, CSV export and audit log.
- Demonstrates OOP abstraction, inheritance and polymorphism; encapsulated private state in model classes; prepared statements; transaction commit/rollback; try/catch; file handling.

## Requirements

- MySQL 8.0+
- Java 17+
- Maven 3.8+
- MySQL Workbench (recommended)

## 1. Import SQL

1. Open MySQL Workbench and connect to your local MySQL server.
2. Open `sql/airport_operations_pro.sql`.
3. Execute the whole script. It creates/replaces `airport_operations_pro` and generates synthetic data. It may take a little while because it inserts thousands of relational records.
4. Verify the row counts in the final output. Do not run this on a database that contains data you need: the script drops and recreates this demo database.

## 2. Configure the Java app

From the project folder, set your own local MySQL credentials. On macOS/Linux:

```bash
export AIRPORT_DB_URL='jdbc:mysql://localhost:3306/airport_operations_pro?useSSL=false&serverTimezone=Asia/Kolkata'
export AIRPORT_DB_USER='root'
export AIRPORT_DB_PASSWORD='YOUR_MYSQL_PASSWORD'
```

To enable the first admin account, set a one-time bootstrap secret before launching the app:

```bash
export AIRPORT_ADMIN_BOOTSTRAP_KEY='choose-a-long-random-secret'
```

Choose menu option `3` to create the admin account, enter that secret, and then sign in. Normal registrations receive the `CUSTOMER_SERVICE` role. The application stores salted PBKDF2 password hashes, not plaintext passwords. Keep the bootstrap secret private and unset it after creating the admin account.

On Windows PowerShell:

```powershell
$env:AIRPORT_ADMIN_BOOTSTRAP_KEY='choose-a-long-random-secret'
$env:AIRPORT_DB_URL='jdbc:mysql://localhost:3306/airport_operations_pro?useSSL=false&serverTimezone=Asia/Kolkata'
$env:AIRPORT_DB_USER='root'
$env:AIRPORT_DB_PASSWORD='YOUR_MYSQL_PASSWORD'
```

Run:

```bash
mvn compile exec:java
```

Maven downloads MySQL Connector/J. No credentials are hard-coded into the source. If your MySQL account has no password, set `AIRPORT_DB_PASSWORD` to an empty string.

## 3. Suggested demo sequence

1. Choose `1` for KPI dashboard.
2. Choose `2` and search `JAI` or an airline flight number.
3. Choose `5` and use any PNR from `SELECT pnr FROM bookings LIMIT 10;` in Workbench.
4. Choose `6` to create a passenger and booking; the form collects passenger details (passport number is optional) and the transaction inserts passenger, booking, ticket and pending payment together. The newly saved passenger record is then displayed, with an option to edit it immediately.
5. Choose `4`, search by name/email/phone/passenger code/passport number, select a listed passenger ID to open their full details, and choose `1` to edit. Press Enter beside any field to keep its current value; type `NONE` to clear an optional passport number. Admin and Customer Service users can edit; Operations users can view.
6. Choose `7` to check in a confirmed PNR that is eligible.
7. Choose `8` to change a flight status; an event is written to `flight_events`.
8. Choose `9` for unresolved aircraft maintenance.
9. Choose `10` to export the schedule into an `exports/` CSV file.
10. Choose `11` to inspect the audit trail.



