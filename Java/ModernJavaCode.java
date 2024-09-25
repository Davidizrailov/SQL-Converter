import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class ModernJavaCode {
    public static void main(String[] args) {
        // Modern try-with-resources with AutoCloseable support
        try (Resource resource = new Resource()) {
            resource.process();
        } catch (Exception e) {
            e.printStackTrace();
        }

        // Enhanced for loop and type inference with var
        List<String> names = new ArrayList<>();
        names.add("John");
        names.add("Jane");
        names.add("Doe");

        for (String name : names) {
            System.out.println(name);
        }

        // Modern map initialization with type inference and concise lambda expressions
        Map<Integer, String> modernMap = new HashMap<>();
        modernMap.put(1, "one");
        modernMap.put(2, "two");

        modernMap.forEach((key, value) -> System.out.println("Key: " + key + ", Value: " + value));

        // Enhanced switch expression
        int day = 2;
        String dayName = switch (day) {
            case 1 -> "Monday";
            case 2 -> "Tuesday";
            case 3 -> "Wednesday";
            default -> "Invalid day";
        };
        System.out.println("Day name: " + dayName);
    }
}

// Modern resource class for try-with-resources demonstration
class Resource implements AutoCloseable {
    public void process() {
        System.out.println("Processing resource...");
    }

    @Override
    public void close() throws Exception {
        System.out.println("Closing resource...");
    }
}