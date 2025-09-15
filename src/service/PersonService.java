package service;

import model.Person;
import repository.PersonRepository;
import java.util.List;

public class PersonService {
    private final PersonRepository repository = new PersonRepository();

    public List<Person> getAll() {
        return repository.findAll();
    }

    public Person getByDni(String dni) {
        return repository.findByDni(dni);
    }
    public Person create(Person person) {
        if (person == null || person.getDni() == null) {
            throw new IllegalArgumentException("person and dni required");
        }
        if (repository.findByDni(person.getDni()) != null) {
            // caller should translate to HTTP 409 Conflict
            return null;
        }
        return repository.save(person);
    }


    public Person update(String dni, Person updated) {
        Person existing = repository.findByDni(dni);
        if (existing != null) {
            existing.setName(updated.getName());
            existing.setAge(updated.getAge());
            repository.save(existing);
            return existing;
        }
        return null;
    }

    public boolean delete(String dni) {
        return repository.delete(dni);
    }
}
