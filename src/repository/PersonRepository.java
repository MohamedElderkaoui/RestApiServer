package repository;

import model.Person;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

public class PersonRepository {
    // thread-safe map
    private final Map<String, Person> store = new ConcurrentHashMap<>();

    public List<Person> findAll() {
        return new ArrayList<>(store.values());
    }

    public Person findByDni(String dni) {
        if (dni == null) return null;
        return store.get(dni);
    }

    public Person save(Person person) {
        Objects.requireNonNull(person, "person must not be null");
        Objects.requireNonNull(person.getDni(), "dni must not be null");
        store.put(person.getDni(), person);
        return person;
    }

    public boolean delete(String dni) {
        if (dni == null) return false;
        return store.remove(dni) != null;
    }
}
