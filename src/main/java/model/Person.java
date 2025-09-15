package model;

import java.util.Objects;

public class Person {
    private String name;
    private String dni;
    private int age;

    public Person() {}

    public Person(String name, String dni, int age) {
        this.name = name;
        this.dni = dni;
        this.age = age;
    }

    // Getters y setters
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getDni() { return dni; }
    public void setDni(String dni) { this.dni = dni; }

    public int getAge() { return age; }
    public void setAge(int age) { this.age = age; }

    // Equals y hashCode basados en DNI
    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof Person)) return false;
        Person person = (Person) o;
        return Objects.equals(dni, person.dni);
    }

    @Override
    public int hashCode() {
        return Objects.hash(dni);
    }

    @Override
    public String toString() {
        return "Person{name='" + name + "', dni='" + dni + "', age=" + age + "}";
    }
}
