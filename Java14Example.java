import java.util.ArrayList;
import java.util.List;

public class Java14Example {

    public static void main(String[] args) {
        // Using diamond operator in generics
        List<String> list = new ArrayList<>();
        list.add("Java 14 Example");
        list.add("Generics in Java 14");

        // Looping over the list using for-each loop
        for (String item : list) {
            System.out.println(item);
        }

        // Example of a switch statement with Strings (enhanced switch in Java 14)
        String language = "Java";
        switch (language) {
            case "Java" -> System.out.println("You're programming in Java!");
            case "Python" -> System.out.println("You're programming in Python!");
            default -> System.out.println("Unknown language.");
        }

        // Try-with-resources
        try (AutoCloseableResource resource = new AutoCloseableResource()) {
            resource.doSomething();
        } catch (Exception e) {
            System.out.println("An exception occurred: " + e.getMessage());
        }
    }
}

// A simple resource that implements AutoCloseable
class AutoCloseableResource implements AutoCloseable {

    public void doSomething() {
        System.out.println("Resource is being used.");
    }

    @Override
    public void close() {
        System.out.println("Resource is being closed.");
    }
}