import java.util.ArrayList;
import java.util.List;

public class Java7Example {

    public static void main(String[] args) {
        // Using explicit type parameters in generics
        List<String> list = new ArrayList<String>();
        list.add("Java 7 Example");
        list.add("Generics in Java 7");

        // Looping over the list using for-each loop
        for (String item : list) {
            System.out.println(item);
        }

        // Example of a switch statement with Strings (introduced in Java 7)
        String language = "Java";
        switch (language) {
            case "Java":
                System.out.println("You're programming in Java!");
                break;
            case "Python":
                System.out.println("You're programming in Python!");
                break;
            default:
                System.out.println("Unknown language.");
                break;
        }

        // Try-with-resources (introduced in Java 7)
        try (AutoCloseableResource resource = new AutoCloseableResource()) {
            resource.doSomething();
        } catch (Exception e) {
            System.out.println("An exception occurred: " + e.getMessage());
        }
    }
}

// A simple resource that implements AutoCloseable (introduced in Java 7)
class AutoCloseableResource implements AutoCloseable {

    public void doSomething() {
        System.out.println("Resource is being used.");
    }

    @Override
    public void close() {
        System.out.println("Resource is being closed.");
    }
}
