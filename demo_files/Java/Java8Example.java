// Java 8 Database Example
import java.sql.*;
import java.util.ArrayList;
import java.util.List;

public class Java8DatabaseExample {

    // Database URL, username, and password
    private static final String DB_URL = "jdbc:h2:mem:testdb"; // In-memory database
    private static final String USER = "sa";
    private static final String PASS = "";

    // SQL statements
    private static final String CREATE_TABLE_SQL = "CREATE TABLE users (" +
            "id INT AUTO_INCREMENT PRIMARY KEY," +
            "username VARCHAR(255) NOT NULL," +
            "email VARCHAR(255) NOT NULL," +
            "age INT NOT NULL" +
            ")";

    private static final String INSERT_USER_SQL = "INSERT INTO users (username, email, age) VALUES (?, ?, ?)";
    private static final String SELECT_ALL_USERS_SQL = "SELECT * FROM users";
    private static final String UPDATE_USER_SQL = "UPDATE users SET email = ?, age = ? WHERE username = ?";
    private static final String DELETE_USER_SQL = "DELETE FROM users WHERE username = ?";

    public static void main(String[] args) {
        // Load the H2 database driver
        try {
            Class.forName("org.h2.Driver");
        } catch (ClassNotFoundException e) {
            System.err.println("Failed to load H2 driver.");
            e.printStackTrace();
            return;
        }

        // Establish database connection
        try (Connection connection = DriverManager.getConnection(DB_URL, USER, PASS)) {
            // Disable auto-commit mode
            connection.setAutoCommit(false);

            // Create table
            createTable(connection);

            // Insert users
            insertUser(connection, "alice", "alice@example.com", 30);
            insertUser(connection, "bob", "bob@example.com", 25);
            insertUser(connection, "charlie", "charlie@example.com", 35);

            // Commit the transaction
            connection.commit();

            // Query users
            List<User> users = getAllUsers(connection);
            System.out.println("Users before update:");
            users.forEach(System.out::println);

            // Update user
            updateUser(connection, "bob", "bob.new@example.com", 26);

            // Commit the transaction
            connection.commit();

            // Query users after update
            users = getAllUsers(connection);
            System.out.println("Users after update:");
            users.forEach(System.out::println);

            // Delete user
            deleteUser(connection, "charlie");

            // Commit the transaction
            connection.commit();

            // Query users after deletion
            users = getAllUsers(connection);
            System.out.println("Users after deletion:");
            users.forEach(System.out::println);

        } catch (SQLException e) {
            System.err.println("Database error occurred.");
            e.printStackTrace();
        }
    }

    private static void createTable(Connection connection) throws SQLException {
        try (Statement stmt = connection.createStatement()) {
            stmt.execute(CREATE_TABLE_SQL);
            System.out.println("Table 'users' created successfully.");
        }
    }

    private static void insertUser(Connection connection, String username, String email, int age) throws SQLException {
        try (PreparedStatement pstmt = connection.prepareStatement(INSERT_USER_SQL)) {
            pstmt.setString(1, username);
            pstmt.setString(2, email);
            pstmt.setInt(3, age);
            int rowsAffected = pstmt.executeUpdate();
            System.out.println("Inserted " + rowsAffected + " user(s): " + username);
        }
    }

    private static List<User> getAllUsers(Connection connection) throws SQLException {
        List<User> users = new ArrayList<>();
        try (PreparedStatement pstmt = connection.prepareStatement(SELECT_ALL_USERS_SQL);
             ResultSet rs = pstmt.executeQuery()) {

            while (rs.next()) {
                String username = rs.getString("username");
                String email = rs.getString("email");
                int age = rs.getInt("age");
                users.add(new User(username, email, age));
            }
        }
        return users;
    }

    private static void updateUser(Connection connection, String username, String newEmail, int newAge) throws SQLException {
        try (PreparedStatement pstmt = connection.prepareStatement(UPDATE_USER_SQL)) {
            pstmt.setString(1, newEmail);
            pstmt.setInt(2, newAge);
            pstmt.setString(3, username);
            int rowsAffected = pstmt.executeUpdate();
            System.out.println("Updated " + rowsAffected + " user(s): " + username);
        }
    }

    private static void deleteUser(Connection connection, String username) throws SQLException {
        try (PreparedStatement pstmt = connection.prepareStatement(DELETE_USER_SQL)) {
            pstmt.setString(1, username);
            int rowsAffected = pstmt.executeUpdate();
            System.out.println("Deleted " + rowsAffected + " user(s): " + username);
        }
    }

    // User class
    public static class User {
        private final String username;
        private final String email;
        private final int age;

        public User(String username, String email, int age) {
            this.username = username;
            this.email = email;
            this.age = age;
        }

        public String getUsername() { return username; }
        public String getEmail() { return email; }
        public int getAge() { return age; }

        @Override
        public String toString() {
            return "User{" +
                   "username='" + username + '\'' +
                   ", email='" + email + '\'' +
                   ", age=" + age +
                   '}';
        }
    }
}
