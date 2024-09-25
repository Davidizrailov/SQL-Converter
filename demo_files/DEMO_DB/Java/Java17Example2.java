// Java 17 code example
import java.util.List;

public class Java17Example {

    public sealed interface Shape permits Circle, Rectangle, Triangle {
        double calculateArea();
    }

    public record Circle(double radius) implements Shape {
        @Override
        public double calculateArea() {
            return Math.PI * radius * radius;
        }
    }

    public record Rectangle(double width, double height) implements Shape {
        @Override
        public double calculateArea() {
            return width * height;
        }
    }

    public record Triangle(double base, double height) implements Shape {
        @Override
        public double calculateArea() {
            return 0.5 * base * height;
        }
    }

    public static void main(String[] args) {
        // Using 'var' for local-variable type inference
        var shapes = List.of(
            new Circle(5),
            new Rectangle(4, 6),
            new Triangle(3, 7)
        );

        for (var shape : shapes) {
            // Switch expression with pattern matching
            var area = switch (shape) {
                case Circle c -> c.calculateArea();
                case Rectangle r -> r.calculateArea();
                case Triangle t -> t.calculateArea();
            };

            // Using text blocks for multi-line strings
            var json = """
                {
                  "type": "%s",
                  "area": %.2f
                }
                """.formatted(shape.getClass().getSimpleName(), area);

            System.out.println(json);
        }
    }
}
