package com.areen.airport;

import java.io.BufferedWriter;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.*;
import java.security.SecureRandom;
import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.PBEKeySpec;
import java.util.Base64;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Scanner;
import java.util.ArrayList;
import java.util.List;

/**
 * Airport Operations Pro - educational console application.
 * Demonstrates encapsulation, abstraction, inheritance, polymorphism, JDBC,
 * transactions, prepared statements, and file handling.
 * Synthetic demo data only; not an operational airport system.
 */
public class AirportOperationsSystem {
    private static final Scanner SC = new Scanner(System.in);
    private static final DateTimeFormatter TS = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm");
    private static Connection connection;
    private static String currentUser = "console-operator";
    private static String currentRole = "CUSTOMER_SERVICE";

    public static void main(String[] args) {
        String url = env("AIRPORT_DB_URL", "jdbc:mysql://localhost:3306/airport_operations_pro?useSSL=false&serverTimezone=Asia/Kolkata");
        String user = env("AIRPORT_DB_USER", "root");
        String password = env("AIRPORT_DB_PASSWORD", "");
        try {
            connection = DriverManager.getConnection(url, user, password);
            System.out.println("\n==============================================");
            System.out.println("       AIRPORT OPERATIONS PRO | JAIPUR");
            System.out.println("==============================================");
            System.out.println("Connected to MySQL. Dataset is synthetic.");
            if (authenticate()) {
                audit("APPLICATION_START", "system", null, "Application connected successfully");
                runMenu();
            }
        } catch (SQLException ex) {
            System.out.println("Database connection failed: " + ex.getMessage());
            System.out.println("Check MySQL is running, import the SQL file, and set AIRPORT_DB_USER / AIRPORT_DB_PASSWORD.");
        } finally {
            try { if (connection != null) connection.close(); } catch (SQLException ignored) { }
            SC.close();
        }
    }

    private static String env(String key, String fallback) {
        String value = System.getenv(key);
        return value == null ? fallback : value;
    }

    private static boolean authenticate() throws SQLException {
        while (true) {
            System.out.println("\n----------- SECURE ACCESS -----------");
            System.out.println("1. Sign in");
            System.out.println("2. Register customer-service account");
            System.out.println("3. Bootstrap admin account (requires configured secret)");
            System.out.println("0. Exit");
            int choice = readInt("Choose: ");
            if (choice == 0) return false;
            if (choice == 1) {
                String username = readLine("Username: ").trim();
                String password = readLine("Password: ");
                try (PreparedStatement ps = connection.prepareStatement("SELECT password_hash, role, active FROM system_users WHERE username=?")) {
                    ps.setString(1, username);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (rs.next() && rs.getBoolean("active") && verifyPassword(password, rs.getString("password_hash"))) {
                            currentUser = username;
                            currentRole = rs.getString("role");
                            System.out.println("Signed in as " + currentUser + " (" + currentRole + ").");
                            return true;
                        }
                    }
                }
                System.out.println("Invalid credentials or inactive account.");
            } else if (choice == 2) {
                registerAccount(false);
            } else if (choice == 3) {
                registerAccount(true);
            } else {
                System.out.println("Invalid option.");
            }
        }
    }

    private static void registerAccount(boolean adminBootstrap) throws SQLException {
        String username = readLine("New username (3-40 characters): ").trim();
        if (!username.matches("[A-Za-z0-9_.-]{3,40}")) { System.out.println("Use 3-40 letters, numbers, dot, underscore or hyphen."); return; }
        String password = readLine("New password (minimum 10 characters): ");
        if (password.length() < 10) { System.out.println("Password must contain at least 10 characters."); return; }
        String role = "CUSTOMER_SERVICE";
        if (adminBootstrap) {
            String expected = System.getenv("AIRPORT_ADMIN_BOOTSTRAP_KEY");
            if (expected == null || expected.isBlank()) {
                System.out.println("Admin bootstrap is disabled. Set AIRPORT_ADMIN_BOOTSTRAP_KEY in your environment first."); return;
            }
            String supplied = readLine("Admin bootstrap key: ");
            if (!constantTimeEquals(expected, supplied)) { System.out.println("Bootstrap key did not match."); return; }
            role = "ADMIN";
        }
        try (PreparedStatement ps = connection.prepareStatement("INSERT INTO system_users(username,password_hash,role,active) VALUES(?,?,?,TRUE)")) {
            ps.setString(1, username); ps.setString(2, hashPassword(password)); ps.setString(3, role); ps.executeUpdate();
            System.out.println("Account created with role " + role + ". You can now sign in.");
            audit("REGISTER_ACCOUNT", "system_users", username, "Created role=" + role);
        } catch (SQLException ex) {
            if (ex.getErrorCode() == 1062) System.out.println("That username already exists.");
            else throw ex;
        }
    }

    private static String hashPassword(String password) {
        try {
            int iterations = 120000;
            byte[] salt = new byte[16]; new SecureRandom().nextBytes(salt);
            PBEKeySpec spec = new PBEKeySpec(password.toCharArray(), salt, iterations, 256);
            byte[] hash = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).getEncoded();
            spec.clearPassword();
            return "pbkdf2$" + iterations + "$" + Base64.getEncoder().encodeToString(salt) + "$" + Base64.getEncoder().encodeToString(hash);
        } catch (Exception ex) { throw new IllegalStateException("Password hashing unavailable", ex); }
    }

    private static boolean verifyPassword(String password, String encoded) {
        try {
            String[] parts = encoded.split("\\$");
            if (parts.length != 4 || !parts[0].equals("pbkdf2")) return false;
            int iterations = Integer.parseInt(parts[1]);
            byte[] salt = Base64.getDecoder().decode(parts[2]);
            byte[] expected = Base64.getDecoder().decode(parts[3]);
            PBEKeySpec spec = new PBEKeySpec(password.toCharArray(), salt, iterations, expected.length * 8);
            byte[] actual = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).getEncoded();
            spec.clearPassword();
            if (actual.length != expected.length) return false;
            int diff = 0; for (int i=0;i<actual.length;i++) diff |= actual[i] ^ expected[i];
            return diff == 0;
        } catch (Exception ex) { return false; }
    }
    private static boolean constantTimeEquals(String a, String b) {
        if (b == null || a.isEmpty() || b.isEmpty()) return a.equals(b);
        int diff = a.length() ^ b.length(); int max = Math.max(a.length(), b.length());
        for (int i=0;i<max;i++) diff |= a.charAt(i % a.length()) ^ b.charAt(i % b.length());
        return diff == 0;
    }

    private static void runMenu() {
        boolean running = true;
        while (running) {
            System.out.println("\n--------------- MAIN MENU ---------------");
            System.out.println("1. Operations dashboard / KPIs");
            System.out.println("2. Search flights by route or flight number");
            System.out.println("3. Today's departures and arrivals");
            System.out.println("4. Passenger details (search / view / edit)");
            System.out.println("5. Look up booking by PNR");
            System.out.println("6. Create passenger + booking (transaction)");
            System.out.println("7. Check in passenger by PNR");
            if (currentRole.equals("ADMIN") || currentRole.equals("OPERATIONS")) {
                System.out.println("8. Update flight status (operations/admin)");
                System.out.println("9. Aircraft maintenance overview");
            }
            if (currentRole.equals("ADMIN")) {
                System.out.println("10. Export flight schedule to CSV");
                System.out.println("11. Show recent audit log");
            }
            System.out.println("0. Exit");
            int choice = readInt("Choose: ");
            try {
                switch (choice) {
                    case 1 -> dashboard();
                    case 2 -> searchFlights();
                    case 3 -> todayOperations();
                    case 4 -> searchPassenger();
                    case 5 -> lookupBooking();
                    case 6 -> createPassengerAndBooking();
                    case 7 -> checkIn();
                    case 8 -> { requireRole("ADMIN", "OPERATIONS"); updateFlightStatus(); }
                    case 9 -> { requireRole("ADMIN", "OPERATIONS"); maintenanceOverview(); }
                    case 10 -> { requireRole("ADMIN"); exportFlightsCsv(); }
                    case 11 -> { requireRole("ADMIN"); recentAudit(); }
                    case 0 -> running = false;
                    default -> System.out.println("Invalid option.");
                }
            } catch (SQLException ex) {
                System.out.println("Database operation failed: " + ex.getMessage());
                audit("DATABASE_ERROR", "system", null, ex.getMessage());
            } catch (RuntimeException ex) {
                System.out.println("Operation could not be completed: " + ex.getMessage());
                audit("APPLICATION_ERROR", "system", null, ex.getMessage());
            }
        }
        audit("APPLICATION_EXIT", "system", null, "Application closed");
        System.out.println("Goodbye.");
    }

    // Abstraction + polymorphism: each flight scope produces its own display description.
    private abstract static class FlightCategory {
        private final String origin;
        private final String destination;
        protected FlightCategory(String origin, String destination) {
            this.origin = origin; this.destination = destination;
        }
        public String route() { return origin + " -> " + destination; }
        public abstract String serviceDescription();
    }
    private static final class DomesticFlight extends FlightCategory {
        DomesticFlight(String o, String d) { super(o, d); }
        public String serviceDescription() { return "Domestic service"; }
    }
    private static final class RegionalFlight extends FlightCategory {
        RegionalFlight(String o, String d) { super(o, d); }
        public String serviceDescription() { return "Regional connectivity"; }
    }
    private static final class InternationalFlight extends FlightCategory {
        InternationalFlight(String o, String d) { super(o, d); }
        public String serviceDescription() { return "International service"; }
    }
    private static FlightCategory category(String scope, String origin, String destination) {
        return switch (scope) {
            case "REGIONAL" -> new RegionalFlight(origin, destination);
            case "INTERNATIONAL" -> new InternationalFlight(origin, destination);
            default -> new DomesticFlight(origin, destination);
        };
    }

    private static void requireRole(String... allowed) {
        for (String role : allowed) if (role.equals(currentRole)) return;
        throw new IllegalStateException("Access denied for role " + currentRole + ".");
    }

    private static void dashboard() throws SQLException {
        System.out.println("\n========== AIRPORT KPI DASHBOARD ==========");
        String[] queries = {
            "SELECT COUNT(*) FROM flights WHERE DATE(scheduled_departure)=CURDATE()",
            "SELECT COUNT(*) FROM flights WHERE DATE(scheduled_departure)=CURDATE() AND status='DELAYED'",
            "SELECT COUNT(*) FROM flights WHERE DATE(scheduled_departure)=CURDATE() AND status='CANCELLED'",
            "SELECT COUNT(*) FROM bookings WHERE booking_status='CONFIRMED'",
            "SELECT COUNT(*) FROM passengers",
            "SELECT COUNT(*) FROM aircraft WHERE status='MAINTENANCE'",
            "SELECT COALESCE(SUM(amount),0) FROM payments WHERE payment_status='SUCCESS' AND paid_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)"
        };
        String[] labels = {"Flights scheduled today", "Delayed flights today", "Cancelled flights today", "Confirmed bookings", "Registered passengers", "Aircraft under maintenance", "Successful payments (last 30 days, ₹)"};
        for (int i = 0; i < queries.length; i++) {
            try (Statement st = connection.createStatement(); ResultSet rs = st.executeQuery(queries[i])) {
                rs.next(); System.out.printf("%-42s %s%n", labels[i] + ":", rs.getString(1));
            }
        }
        System.out.println("\nFlight status distribution:");
        try (Statement st = connection.createStatement(); ResultSet rs = st.executeQuery("SELECT status, COUNT(*) AS total FROM flights GROUP BY status ORDER BY total DESC")) {
            while (rs.next()) System.out.printf("  %-15s %d%n", rs.getString("status"), rs.getInt("total"));
        }
        audit("VIEW_DASHBOARD", "dashboard", null, "Viewed operations KPIs");
    }

    private static void searchFlights() throws SQLException {
        String route = readLine("Route/flight search (e.g. JAI, DEL or 6E1234): ").trim().toUpperCase();
        String sql = "SELECT flight_id, flight_number, airline_name, origin_code, destination_code, flight_scope, scheduled_departure, scheduled_arrival, status, terminal_name, gate_code " +
                "FROM v_flight_operations WHERE flight_number LIKE ? OR origin_code LIKE ? OR destination_code LIKE ? ORDER BY scheduled_departure LIMIT 80";
        try (PreparedStatement ps = connection.prepareStatement(sql)) {
            String like = "%" + route + "%";
            ps.setString(1, like); ps.setString(2, like); ps.setString(3, like);
            try (ResultSet rs = ps.executeQuery()) {
                int count = 0;
                while (rs.next()) { printFlight(rs); count++; }
                System.out.println("Rows shown: " + count + (count == 80 ? " (limit reached)" : ""));
            }
        }
        audit("SEARCH_FLIGHTS", "flights", null, "Search term=" + route);
    }

    private static void todayOperations() throws SQLException {
        String sql = "SELECT flight_id, flight_number, airline_name, origin_code, destination_code, flight_scope, scheduled_departure, scheduled_arrival, status, terminal_name, gate_code " +
                "FROM v_flight_operations WHERE DATE(scheduled_departure)=CURDATE() ORDER BY scheduled_departure";
        try (Statement st = connection.createStatement(); ResultSet rs = st.executeQuery(sql)) {
            int count = 0;
            while (rs.next()) { printFlight(rs); count++; }
            if (count == 0) System.out.println("No synthetic flights are scheduled for today's date. Try option 2 to search the full sample schedule.");
            else System.out.println("Total shown: " + count);
        }
        audit("VIEW_TODAY_OPERATIONS", "flights", null, "Viewed today's flights");
    }

    private static void printFlight(ResultSet rs) throws SQLException {
        FlightCategory c = category(rs.getString("flight_scope"), rs.getString("origin_code"), rs.getString("destination_code"));
        System.out.printf("#%-5d %-8s %-22s %-13s %-15s %-16s %-10s %s %s%n",
                rs.getLong("flight_id"), rs.getString("flight_number"), trim(rs.getString("airline_name"),22), c.route(),
                c.serviceDescription(), rs.getTimestamp("scheduled_departure").toLocalDateTime().format(TS),
                rs.getString("status"), safe(rs.getString("terminal_name")), safe(rs.getString("gate_code")));
    }

    private static void searchPassenger() throws SQLException {
        String term = readLine("Passenger name, email, phone, passport or passenger code: ").trim();
        if (term.isEmpty()) {
            System.out.println("Enter a search term first.");
            return;
        }

        String sql = "SELECT passenger_id, passenger_code, first_name, last_name, email, phone, nationality " +
                "FROM passengers WHERE passenger_code LIKE ? OR email LIKE ? OR phone LIKE ? " +
                "OR first_name LIKE ? OR last_name LIKE ? OR passport_no LIKE ? ORDER BY passenger_id LIMIT 50";
        List<Long> matchedIds = new ArrayList<>();
        try (PreparedStatement ps = connection.prepareStatement(sql)) {
            String like = "%" + term + "%";
            for (int i = 1; i <= 6; i++) ps.setString(i, like);
            try (ResultSet rs = ps.executeQuery()) {
                System.out.println("\n================ PASSENGER SEARCH RESULTS ================");
                System.out.printf("%-7s %-20s %-28s %-30s %-16s %-18s%n", "ID", "CODE", "NAME", "EMAIL", "PHONE", "NATIONALITY");
                while (rs.next()) {
                    long id = rs.getLong("passenger_id");
                    matchedIds.add(id);
                    String fullName = rs.getString("first_name") + " " + rs.getString("last_name");
                    System.out.printf("%-7d %-20s %-28s %-30s %-16s %-18s%n",
                            id, rs.getString("passenger_code"), trim(fullName, 28), trim(rs.getString("email"), 30),
                            trim(rs.getString("phone"), 16), trim(rs.getString("nationality"), 18));
                }
            }
        }

        if (matchedIds.isEmpty()) {
            System.out.println("No passenger matched.");
        } else {
            System.out.println("\nEnter a passenger ID from the results above to open the full record.");
            System.out.println("Enter 0 to return to the main menu.");
            long selectedId = readLong("Passenger ID: ");
            if (selectedId == 0) return;
            if (!matchedIds.contains(selectedId)) {
                System.out.println("That ID is not in the search results. Search again and select a listed ID.");
                return;
            }
            showPassengerDetails(selectedId);
        }
        audit("SEARCH_PASSENGER", "passengers", null, "Search term=" + term);
    }

    private static void showPassengerDetails(long passengerId) throws SQLException {
        String sql = "SELECT passenger_id, passenger_code, first_name, last_name, email, phone, nationality, " +
                "date_of_birth, passport_no, created_at FROM passengers WHERE passenger_id=?";
        try (PreparedStatement ps = connection.prepareStatement(sql)) {
            ps.setLong(1, passengerId);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) {
                    System.out.println("Passenger record not found.");
                    return;
                }
                System.out.println("\n================ PASSENGER DETAILS ================");
                System.out.println("Passenger ID : " + rs.getLong("passenger_id"));
                System.out.println("Passenger code: " + rs.getString("passenger_code"));
                System.out.println("Full name    : " + rs.getString("first_name") + " " + rs.getString("last_name"));
                System.out.println("Email        : " + rs.getString("email"));
                System.out.println("Phone        : " + rs.getString("phone"));
                System.out.println("Nationality  : " + rs.getString("nationality"));
                System.out.println("Date of birth: " + rs.getString("date_of_birth"));
                System.out.println("Passport no. : " + safe(rs.getString("passport_no")));
                System.out.println("Created at   : " + rs.getTimestamp("created_at"));
            }
        }

        audit("VIEW_PASSENGER_DETAILS", "passengers", String.valueOf(passengerId), "Viewed passenger record");
        if (currentRole.equals("ADMIN") || currentRole.equals("CUSTOMER_SERVICE")) {
            System.out.println("\n1. Edit passenger details");
            System.out.println("0. Return to main menu");
            int choice = readInt("Choose: ");
            if (choice == 1) editPassengerDetails(passengerId);
            else if (choice != 0) System.out.println("Invalid option. Returning to passenger search.");
        } else {
            System.out.println("\nYour role can view passenger details but cannot edit them.");
        }
    }

    private static void editPassengerDetails(long passengerId) throws SQLException {
        requireRole("ADMIN", "CUSTOMER_SERVICE");
        String selectSql = "SELECT first_name, last_name, email, phone, nationality, date_of_birth, passport_no " +
                "FROM passengers WHERE passenger_id=?";
        String firstName;
        String lastName;
        String email;
        String phone;
        String nationality;
        String dob;
        String passport;
        try (PreparedStatement ps = connection.prepareStatement(selectSql)) {
            ps.setLong(1, passengerId);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) {
                    System.out.println("Passenger record not found; nothing was changed.");
                    return;
                }
                firstName = rs.getString("first_name");
                lastName = rs.getString("last_name");
                email = rs.getString("email");
                phone = rs.getString("phone");
                nationality = rs.getString("nationality");
                dob = rs.getString("date_of_birth");
                passport = rs.getString("passport_no");
            }
        }

        System.out.println("\nEDIT PASSENGER — press Enter to keep the current value.");
        String newFirstName = promptKeepCurrent("First name", firstName);
        String newLastName = promptKeepCurrent("Last name", lastName);
        String newEmail = promptKeepCurrent("Email", email).toLowerCase();
        String newPhone = promptKeepCurrent("Phone", phone);
        String newNationality = promptKeepCurrent("Nationality", nationality);
        String newDob = promptKeepCurrent("Date of birth (YYYY-MM-DD)", dob);
        String passportPrompt = "Passport number [" + safe(passport) + "] (Enter=keep, type NONE=clear): ";
        String passportInput = readLine(passportPrompt).trim();
        String newPassport = passportInput.isEmpty() ? passport : (passportInput.equalsIgnoreCase("NONE") ? null : passportInput);

        if (newFirstName.isBlank() || newLastName.isBlank() || newEmail.isBlank() ||
                newPhone.isBlank() || newNationality.isBlank()) {
            System.out.println("Required fields cannot be empty. No changes were saved.");
            return;
        }
        if (newFirstName.length() > 60 || newLastName.length() > 60 || newEmail.length() > 120 ||
                newPhone.length() > 20 || newNationality.length() > 60 ||
                (newPassport != null && newPassport.length() > 20)) {
            System.out.println("One or more fields exceed the database length limit. No changes were saved.");
            return;
        }

        final Date sqlDob;
        try {
            sqlDob = Date.valueOf(dobOrThrow(newDob));
        } catch (IllegalArgumentException ex) {
            System.out.println("Invalid date. Use YYYY-MM-DD (for example, 2004-08-21). No changes were saved.");
            return;
        }

        if (newFirstName.equals(firstName) && newLastName.equals(lastName) && newEmail.equals(email) &&
                newPhone.equals(phone) && newNationality.equals(nationality) && newDob.equals(dob) &&
                java.util.Objects.equals(newPassport, passport)) {
            System.out.println("No changes entered.");
            return;
        }

        String updateSql = "UPDATE passengers SET first_name=?, last_name=?, email=?, phone=?, nationality=?, " +
                "date_of_birth=?, passport_no=? WHERE passenger_id=?";
        try (PreparedStatement ps = connection.prepareStatement(updateSql)) {
            ps.setString(1, newFirstName);
            ps.setString(2, newLastName);
            ps.setString(3, newEmail);
            ps.setString(4, newPhone);
            ps.setString(5, newNationality);
            ps.setDate(6, sqlDob);
            if (newPassport == null || newPassport.isBlank()) ps.setNull(7, Types.VARCHAR);
            else ps.setString(7, newPassport);
            ps.setLong(8, passengerId);
            int updated = ps.executeUpdate();
            if (updated == 1) {
                System.out.println("Passenger details updated successfully.");
                audit("UPDATE_PASSENGER_DETAILS", "passengers", String.valueOf(passengerId), "Updated passenger profile fields");
                showPassengerDetailsAfterEdit(passengerId);
            } else {
                System.out.println("No passenger record was updated.");
            }
        } catch (SQLException ex) {
            if (ex.getErrorCode() == 1062) {
                System.out.println("Email or passport number is already assigned to another passenger. No changes were saved.");
            } else {
                throw ex;
            }
        }
    }

    private static String promptKeepCurrent(String label, String currentValue) {
        String input = readLine(label + " [" + currentValue + "] (Enter to keep): ").trim();
        return input.isEmpty() ? currentValue : input;
    }

    private static String dobOrThrow(String value) {
        if (value == null || !value.matches("\\d{4}-\\d{2}-\\d{2}")) {
            throw new IllegalArgumentException("Date must be YYYY-MM-DD");
        }
        return value;
    }

    private static void showPassengerDetailsAfterEdit(long passengerId) throws SQLException {
        String sql = "SELECT passenger_id, passenger_code, first_name, last_name, email, phone, nationality, " +
                "date_of_birth, passport_no, created_at FROM passengers WHERE passenger_id=?";
        try (PreparedStatement ps = connection.prepareStatement(sql)) {
            ps.setLong(1, passengerId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    System.out.println("\n---------- UPDATED PASSENGER DETAILS ----------");
                    System.out.println("Passenger ID : " + rs.getLong("passenger_id"));
                    System.out.println("Passenger code: " + rs.getString("passenger_code"));
                    System.out.println("Full name    : " + rs.getString("first_name") + " " + rs.getString("last_name"));
                    System.out.println("Email        : " + rs.getString("email"));
                    System.out.println("Phone        : " + rs.getString("phone"));
                    System.out.println("Nationality  : " + rs.getString("nationality"));
                    System.out.println("Date of birth: " + rs.getString("date_of_birth"));
                    System.out.println("Passport no. : " + safe(rs.getString("passport_no")));
                    System.out.println("Created at   : " + rs.getTimestamp("created_at"));
                }
            }
        }
    }

    private static void lookupBooking() throws SQLException {
        String pnr = readLine("Enter PNR: ").trim().toUpperCase();
        String sql = "SELECT * FROM v_booking_manifest WHERE pnr=?";
        try (PreparedStatement ps = connection.prepareStatement(sql)) {
            ps.setString(1, pnr);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) { System.out.println("Booking not found."); return; }
                do {
                    System.out.printf("PNR: %s | Passenger: %s (%s) | Flight: %s %s->%s | Depart: %s | Cabin: %s | Booking: %s | Ticket: %s | Seat: %s | Check-in: %s | Payment: %s | Fare: ₹%.2f%n",
                            rs.getString("pnr"), rs.getString("passenger_name"), rs.getString("passenger_code"), rs.getString("flight_number"), rs.getString("origin_code"), rs.getString("destination_code"), rs.getTimestamp("scheduled_departure"), rs.getString("cabin_class"), rs.getString("booking_status"), rs.getString("ticket_number"), safe(rs.getString("seat_number")), rs.getString("check_in_status"), rs.getString("payment_status"), rs.getBigDecimal("total_fare"));
                } while (rs.next());
            }
        }
        audit("LOOKUP_BOOKING", "bookings", pnr, "Booking lookup");
    }

    private static void createPassengerAndBooking() throws SQLException {
        System.out.println("Create a synthetic demo booking. Flight ID can be found from option 2.");
        String first = readLine("First name: ").trim();
        String last = readLine("Last name: ").trim();
        String email = readLine("Email (must be unique): ").trim().toLowerCase();
        String phone = readLine("Phone: ").trim();
        String nationality = readLine("Nationality: ").trim();
        String dob = readLine("DOB YYYY-MM-DD: ").trim();
        String passportNo = readLine("Passport number (optional; press Enter if not applicable): ").trim();
        if (passportNo.isEmpty()) passportNo = null;
        long flightId = readLong("Flight ID: ");
        String cabin = readLine("Cabin (ECONOMY/PREMIUM_ECONOMY/BUSINESS/FIRST): ").trim().toUpperCase();
        if (!cabin.matches("ECONOMY|PREMIUM_ECONOMY|BUSINESS|FIRST")) { System.out.println("Invalid cabin."); return; }
        long createdPassengerId = -1;
        connection.setAutoCommit(false);
        try {
            long passengerId;
            String passengerCode = "JAI-" + System.currentTimeMillis();
            try (PreparedStatement ps = connection.prepareStatement("INSERT INTO passengers(passenger_code,first_name,last_name,email,phone,nationality,date_of_birth,passport_no) VALUES(?,?,?,?,?,?,?,?)", Statement.RETURN_GENERATED_KEYS)) {
                ps.setString(1, passengerCode); ps.setString(2, first); ps.setString(3, last); ps.setString(4, email); ps.setString(5, phone); ps.setString(6, nationality); ps.setDate(7, Date.valueOf(dob));
                if (passportNo == null) ps.setNull(8, Types.VARCHAR); else ps.setString(8, passportNo);
                ps.executeUpdate();
                try (ResultSet keys = ps.getGeneratedKeys()) { keys.next(); passengerId = keys.getLong(1); }
            }
            BigDecimalHolder fare = getFare(flightId);
            String pnr = generatePnr();
            long bookingId;
            try (PreparedStatement ps = connection.prepareStatement("INSERT INTO bookings(pnr,passenger_id,flight_id,cabin_class,booking_status,total_fare) VALUES(?,?,?,?,'CONFIRMED',?)", Statement.RETURN_GENERATED_KEYS)) {
                ps.setString(1,pnr); ps.setLong(2,passengerId); ps.setLong(3,flightId); ps.setString(4,cabin); ps.setBigDecimal(5,fare.value); ps.executeUpdate();
                try (ResultSet keys=ps.getGeneratedKeys()) { keys.next(); bookingId=keys.getLong(1); }
            }
            try (PreparedStatement ps=connection.prepareStatement("INSERT INTO tickets(booking_id,ticket_number,seat_number,check_in_status,baggage_kg) VALUES(?,?,NULL,'NOT_CHECKED_IN',0)")) {
                ps.setLong(1,bookingId); ps.setString(2,"JAI"+String.format("%010d",bookingId)); ps.executeUpdate();
            }
            try (PreparedStatement ps=connection.prepareStatement("INSERT INTO payments(booking_id,transaction_ref,payment_method,amount,payment_status,paid_at) VALUES(?,?, 'UPI',?,'PENDING',NULL)")) {
                ps.setLong(1,bookingId); ps.setString(2,"TXN-NEW-"+bookingId); ps.setBigDecimal(3,fare.value); ps.executeUpdate();
            }
            connection.commit();
            createdPassengerId = passengerId;
            System.out.println("Booking created. Passenger code: " + passengerCode + " | PNR: " + pnr + " | Booking ID: " + bookingId + " | Fare: ₹" + fare.value + " | Payment status: PENDING");
            audit("CREATE_BOOKING", "bookings", String.valueOf(bookingId), "Created PNR="+pnr+", passenger="+passengerCode);
        } catch (SQLException | IllegalArgumentException ex) {
            connection.rollback();
            System.out.println("Booking rolled back: " + ex.getMessage());
        } finally {
            connection.setAutoCommit(true);
        }
        if (createdPassengerId > 0) {
            System.out.println("\nThe passenger record has been saved. Review it below; you can edit it now or later using option 4.");
            showPassengerDetails(createdPassengerId);
        }
    }

    private static class BigDecimalHolder { java.math.BigDecimal value; BigDecimalHolder(java.math.BigDecimal v) { value=v; } }
    private static BigDecimalHolder getFare(long flightId) throws SQLException {
        try (PreparedStatement ps=connection.prepareStatement("SELECT fare_base FROM flights WHERE flight_id=? AND status <> 'CANCELLED'")) {
            ps.setLong(1,flightId); try (ResultSet rs=ps.executeQuery()) { if (!rs.next()) throw new SQLException("Flight ID does not exist or is cancelled."); return new BigDecimalHolder(rs.getBigDecimal(1)); }
        }
    }
    private static String generatePnr() {
        String alphabet="ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
        StringBuilder b=new StringBuilder();
        for(int i=0;i<6;i++) b.append(alphabet.charAt((int)(Math.random()*alphabet.length())));
        return b.toString();
    }

    private static void checkIn() throws SQLException {
        String pnr=readLine("PNR to check in: ").trim().toUpperCase();
        String sql="UPDATE tickets tk JOIN bookings b ON b.booking_id=tk.booking_id JOIN flights f ON f.flight_id=b.flight_id " +
                "SET tk.check_in_status='CHECKED_IN', tk.checked_in_at=NOW() " +
                "WHERE b.pnr=? AND b.booking_status='CONFIRMED' AND tk.check_in_status='NOT_CHECKED_IN' AND f.status NOT IN ('CANCELLED','ARRIVED')";
        try (PreparedStatement ps=connection.prepareStatement(sql)) {
            ps.setString(1,pnr); int updated=ps.executeUpdate();
            System.out.println(updated==1 ? "Check-in completed for PNR " + pnr : "Check-in not completed. Verify PNR, booking status, flight status, and existing check-in.");
            audit("CHECK_IN", "bookings", pnr, "Rows updated="+updated);
        }
    }

    private static void updateFlightStatus() throws SQLException {
        long id=readLong("Flight ID: ");
        String status=readLine("New status (SCHEDULED/BOARDING/DEPARTED/ARRIVED/DELAYED/CANCELLED/DIVERTED): ").trim().toUpperCase();
        if (!status.matches("SCHEDULED|BOARDING|DEPARTED|ARRIVED|DELAYED|CANCELLED|DIVERTED")) { System.out.println("Invalid status."); return; }
        String sql="UPDATE flights SET status=?, actual_departure=CASE WHEN ?='DEPARTED' AND actual_departure IS NULL THEN NOW() ELSE actual_departure END, actual_arrival=CASE WHEN ?='ARRIVED' AND actual_arrival IS NULL THEN NOW() ELSE actual_arrival END WHERE flight_id=?";
        try (PreparedStatement ps=connection.prepareStatement(sql)) {
            ps.setString(1,status); ps.setString(2,status); ps.setString(3,status); ps.setLong(4,id);
            int rows=ps.executeUpdate();
            if (rows==1) {
                try (PreparedStatement ev=connection.prepareStatement("INSERT INTO flight_events(flight_id,event_type,event_note) VALUES(?,?,?)")) {
                    String event = status.equals("DEPARTED") ? "DEPARTED" : status.equals("ARRIVED") ? "ARRIVED" : status.equals("CANCELLED") ? "CANCELLED" : status.equals("DELAYED") ? "DELAYED" : "STATUS_UPDATED";
                    ev.setLong(1,id); ev.setString(2,event); ev.setString(3,"Status changed to "+status+" by "+currentUser); ev.executeUpdate();
                }
                System.out.println("Flight status updated.");
            } else System.out.println("Flight ID not found.");
            audit("UPDATE_FLIGHT_STATUS", "flights", String.valueOf(id), "New status="+status);
        }
    }

    private static void maintenanceOverview() throws SQLException {
        String sql="SELECT m.maintenance_id,a.registration_no,al.airline_name,m.reported_at,m.issue_description,m.severity,m.maintenance_status " +
                "FROM maintenance_logs m JOIN aircraft a ON a.aircraft_id=m.aircraft_id JOIN airlines al ON al.airline_id=a.airline_id " +
                "WHERE m.maintenance_status <> 'RESOLVED' ORDER BY FIELD(m.severity,'CRITICAL','HIGH','MEDIUM','LOW'),m.reported_at DESC LIMIT 100";
        try (Statement st=connection.createStatement(); ResultSet rs=st.executeQuery(sql)) {
            int count=0;
            while(rs.next()) { System.out.printf("#%d | %s | %s | %s | %s | %s | %s%n",rs.getLong("maintenance_id"),rs.getString("registration_no"),rs.getString("airline_name"),rs.getTimestamp("reported_at"),rs.getString("severity"),rs.getString("maintenance_status"),rs.getString("issue_description")); count++; }
            System.out.println("Open/in-progress maintenance records shown: "+count);
        }
        audit("VIEW_MAINTENANCE", "maintenance_logs", null, "Viewed unresolved maintenance");
    }

    private static void exportFlightsCsv() throws SQLException {
        Path output=Path.of("exports");
        try { Files.createDirectories(output); } catch(IOException ex) { System.out.println("Cannot create exports directory: "+ex.getMessage()); return; }
        Path file=output.resolve("flight_schedule_"+LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMdd_HHmmss"))+".csv");
        String sql="SELECT flight_number,airline_name,origin_code,destination_code,flight_scope,scheduled_departure,scheduled_arrival,status,terminal_name,gate_code FROM v_flight_operations ORDER BY scheduled_departure";
        try (Statement st=connection.createStatement(); ResultSet rs=st.executeQuery(sql);
             BufferedWriter writer=Files.newBufferedWriter(file, StandardCharsets.UTF_8)) {
            writer.write("flight_number,airline,origin,destination,scope,scheduled_departure,scheduled_arrival,status,terminal,gate\n");
            while(rs.next()) {
                writer.write(csv(rs.getString("flight_number"))+","+csv(rs.getString("airline_name"))+","+csv(rs.getString("origin_code"))+","+csv(rs.getString("destination_code"))+","+csv(rs.getString("flight_scope"))+","+csv(String.valueOf(rs.getTimestamp("scheduled_departure")))+","+csv(String.valueOf(rs.getTimestamp("scheduled_arrival")))+","+csv(rs.getString("status"))+","+csv(rs.getString("terminal_name"))+","+csv(rs.getString("gate_code"))+"\n");
            }
            System.out.println("CSV exported: "+file.toAbsolutePath());
            audit("EXPORT_FLIGHTS_CSV", "flights", null, file.toString());
        } catch(IOException ex) { System.out.println("CSV export failed: "+ex.getMessage()); }
    }
    private static String csv(String value) { if(value==null) return "\"\""; return "\""+value.replace("\"","\"\"")+"\""; }

    private static void recentAudit() throws SQLException {
        try (Statement st=connection.createStatement(); ResultSet rs=st.executeQuery("SELECT audit_id,username,action_name,entity_name,entity_id,details,created_at FROM audit_log ORDER BY audit_id DESC LIMIT 30")) {
            while(rs.next()) System.out.printf("#%d | %s | %s | %s:%s | %s | %s%n",rs.getLong("audit_id"),rs.getString("username"),rs.getString("action_name"),rs.getString("entity_name"),safe(rs.getString("entity_id")),safe(rs.getString("details")),rs.getTimestamp("created_at"));
        }
    }

    private static void audit(String action, String entity, String id, String details) {
        if (connection == null) return;
        try (PreparedStatement ps=connection.prepareStatement("INSERT INTO audit_log(username,action_name,entity_name,entity_id,details) VALUES(?,?,?,?,?)")) {
            ps.setString(1,currentUser); ps.setString(2,action); ps.setString(3,entity); ps.setString(4,id); ps.setString(5,details==null?null:trim(details,490)); ps.executeUpdate();
        } catch(SQLException ignored) { /* logging must not crash the primary operation */ }
    }
    private static int readInt(String prompt) { while(true) { try { System.out.print(prompt); return Integer.parseInt(SC.nextLine().trim()); } catch(NumberFormatException ex) { System.out.println("Enter a whole number."); } } }
    private static long readLong(String prompt) { while(true) { try { System.out.print(prompt); return Long.parseLong(SC.nextLine().trim()); } catch(NumberFormatException ex) { System.out.println("Enter a valid numeric ID."); } } }
    private static String readLine(String prompt) { System.out.print(prompt); return SC.nextLine(); }
    private static String safe(String value) { return value==null ? "-" : value; }
    private static String trim(String value,int max) { if(value==null) return "-"; return value.length()<=max?value:value.substring(0,max-3)+"..."; }
}
