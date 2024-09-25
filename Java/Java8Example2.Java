// Java 8 code example
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

public class Java8Example {

    public interface Shape {
        double calculateArea();
    }

    public static class Circle implements Shape {
        private final double radius;

        public Circle(double radius) {
            this.radius = radius;
        }

        public double getRadius() { return radius; }

        @Override
        public double calculateArea() {
            return Math.PI * radius * radius;
        }

        @Override
        public boolean equals(Object o) {
            if (this == o) return true;
            if (!(o instanceof Circle)) return false;
            Circle circle = (Circle) o;
            return Double.compare(circle.radius, radius) == 0;
        }

        @Override
        public int hashCode() {
            return Objects.hash(radius);
        }

        @Override
        public String toString() {
            return "Circle{" +
                   "radius=" + radius +
                   '}';
        }
    }

    public static class Rectangle implements Shape {
        private final double width;
        private final double height;

        public Rectangle(double width, double height) {
            this.width = width;
            this.height = height;
        }

        public double getWidth() { return width; }
        public double getHeight() { return height; }

        @Override
        public double calculateArea() {
            return width * height;
        }

        // equals, hashCode, and toString methods omitted for brevity
    }

    public static class Triangle implements Shape {
        private final double base;
        private final double height;

        public Triangle(double base, double height) {
            this.base = base;
            this.height = height;
        }

        public double getBase() { return base; }
        public double getHeight() { return height; }

        @Override
        public double calculateArea() {
            return 0.5 * base * height;
        }

        // equals, hashCode, and toString methods omitted for brevity
    }

    public static void main(String[] args) {
        // Explicit type declarations
        List<Shape> shapes = new ArrayList<>();
        shapes.add(new Circle(5));
        shapes.add(new Rectangle(4, 6));
        shapes.add(new Triangle(3, 7));

        for (Shape shape : shapes) {
            double area = 0.0;

            // Traditional instanceof checks with casting
            if (shape instanceof Circle) {
                Circle c = (Circle) shape;
                area = c.calculateArea();
            } else if (shape instanceof Rectangle) {
                Rectangle r = (Rectangle) shape;
                area = r.calculateArea();
            } else if (shape instanceof Triangle) {
                Triangle t = (Triangle) shape;
                area = t.calculateArea();
            }

            // Multi-line string using concatenation
            String json = "{\n" +
                          "  \"type\": \"" + shape.getClass().getSimpleName() + "\",\n" +
                          "  \"area\": " + area + "\n" +
                          "}";

            System.out.println(json);
        }
    }
}
