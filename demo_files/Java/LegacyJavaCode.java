// Code Java version 7.

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class LegacyJavaCode {
    public static void main(String[] args) {
        // Legacy-style try-with-resources (before auto-closeable support)
        Resource resource = null;
        try {
            resource = new Resource();
            resource.process();
        } catch (Exception e) {
            e.printStackTrace();
        } finally {
            if (resource != null) {
                try {
                    resource.close();
                } catch (Exception e) {
                    e.printStackTrace();
                }
            }
        }

        // Legacy loop style and lack of type inference
        List<String> names = new ArrayList<String>();
        names.add("John");
        names.add("Jane");
        names.add("Doe");

        for (int i = 0; i < names.size(); i++) {
            System.out.println(names.get(i));
        }

        // Legacy map initialization and lack of concise lambda expressions
        Map<Integer, String> legacyMap = new HashMap<Integer, String>();
        legacyMap.put(1, "one");
        legacyMap.put(2, "two");

        for (Map.Entry<Integer, String> entry : legacyMap.entrySet()) {
            System.out.println("Key: " + entry.getKey() + ", Value: " + entry.getValue());
        }

        // Verbose switch-case
        int day = 2;
        String dayName;
        switch (day) {
            case 1:
                dayName = "Monday";
                break;
            case 2:
                dayName = "Tuesday";
                break;
            case 3:
                dayName = "Wednesday";
                break;
            default:
                dayName = "Invalid day";
                break;
        }
        System.out.println("Day name: " + dayName);
    }
}

// Legacy resource class for try-with-resources demonstration
class Resource {
    public void process() {
        System.out.println("Processing resource...");
    }

    public void close() throws Exception {
        System.out.println("Closing resource...");
    }
}
