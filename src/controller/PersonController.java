package controller;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;
import model.Person;
import service.PersonService;

import jakarta.json.*;
import java.io.*;
import java.util.List;

public class PersonController implements HttpHandler {
    private final PersonService service = new PersonService();

    @Override
    public void handle(HttpExchange exchange) throws IOException {
        String method = exchange.getRequestMethod();
        String path = exchange.getRequestURI().getPath();
        String[] parts = path.split("/");

        // Add CORS headers (development friendly)
        String origin = exchange.getRequestHeaders().getFirst("Origin");
        if (origin == null) {
            origin = "*"; // fallback
        }
        exchange.getResponseHeaders().set("Access-Control-Allow-Origin", origin);
        exchange.getResponseHeaders().set("Vary", "Origin");
        exchange.getResponseHeaders().set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
        exchange.getResponseHeaders().set("Access-Control-Allow-Headers", "Content-Type, Accept");
        exchange.getResponseHeaders().set("Access-Control-Max-Age", "600");

        // Handle preflight OPTIONS request
        if ("OPTIONS".equalsIgnoreCase(method)) {
            exchange.sendResponseHeaders(204, -1);
            exchange.close();
            return;
        }

        try {
            if ("GET".equalsIgnoreCase(method) && parts.length == 2) {
                handleGetAll(exchange);
            } else if ("GET".equalsIgnoreCase(method) && parts.length == 3) {
                handleGetOne(exchange, parts[2]);
            } else if ("POST".equalsIgnoreCase(method) && parts.length == 2) {
                handlePost(exchange);
            } else if ("PUT".equalsIgnoreCase(method) && parts.length == 3) {
                handlePut(exchange, parts[2]);
            } else if ("DELETE".equalsIgnoreCase(method) && parts.length == 3) {
                handleDelete(exchange, parts[2]);
            } else {
                sendResponse(exchange, 404, jsonError("Not Found"));
            }
        } catch (Exception e) {
            sendResponse(exchange, 500, jsonError("Internal Server Error: " + e.getMessage()));
        }
    }

    private void handleGetAll(HttpExchange exchange) throws IOException {
        List<Person> people = service.getAll();
        JsonArrayBuilder arrayBuilder = Json.createArrayBuilder();
        for (Person p : people) {
            arrayBuilder.add(toJson(p));
        }
        sendResponse(exchange, 200, arrayBuilder.build().toString());
    }

    private void handleGetOne(HttpExchange exchange, String dni) throws IOException {
        Person person = service.getByDni(dni);
        if (person != null) {
            sendResponse(exchange, 200, toJson(person).toString());
        } else {
            sendResponse(exchange, 404, jsonError("Person not found"));
        }
    }

    private void handlePost(HttpExchange exchange) throws IOException {
        try {
            Person newPerson = fromJson(exchange.getRequestBody());
            if (newPerson == null) {
                sendResponse(exchange, 400, jsonError("Invalid JSON input"));
                return;
            }
            Person createdPerson = service.create(newPerson);
            sendResponse(exchange, 201, toJson(createdPerson).toString());
        } catch (Exception e) {
            sendResponse(exchange, 400, jsonError("Invalid JSON input: " + e.getMessage()));
        }
    }

    private void handlePut(HttpExchange exchange, String dni) throws IOException {
        try {
            Person updatedPerson = fromJson(exchange.getRequestBody());
            if (updatedPerson == null) {
                sendResponse(exchange, 400, jsonError("Invalid JSON input"));
                return;
            }
            Person result = service.update(dni, updatedPerson);
            if (result != null) {
                sendResponse(exchange, 200, toJson(result).toString());
            } else {
                sendResponse(exchange, 404, jsonError("Person not found"));
            }
        } catch (Exception e) {
            sendResponse(exchange, 400, jsonError("Invalid JSON input: " + e.getMessage()));
        }
    }

    private void handleDelete(HttpExchange exchange, String dni) throws IOException {
        if (service.delete(dni)) {
            sendResponse(exchange, 200, "{\"message\":\"Deleted\"}");
        } else {
            sendResponse(exchange, 404, jsonError("Person not found"));
        }
    }

    // ---------------- Utilidades ----------------

    private JsonObject toJson(Person p) {
        return Json.createObjectBuilder()
                .add("name", p.getName())
                .add("dni", p.getDni())
                .add("age", p.getAge())
                .build();
    }

    private Person fromJson(InputStream body) throws IOException {
        // Try to read the stream as UTF-8 text first
        try (InputStreamReader isr = new InputStreamReader(body, java.nio.charset.StandardCharsets.UTF_8);
             JsonReader reader = Json.createReader(isr)) {
            JsonObject obj = reader.readObject();
            return new Person(
                    obj.getString("name", ""),
                    obj.getString("dni", ""),
                    obj.getInt("age", 0)
            );
        } catch (JsonException e) {
            throw new IOException("Failed to parse JSON", e);
        }
    }

    private String jsonError(String message) {
        return Json.createObjectBuilder()
                .add("error", message)
                .build()
                .toString();
    }

    private void sendResponse(HttpExchange exchange, int status, String response) throws IOException {
        exchange.getResponseHeaders().set("Content-Type", "application/json");
        exchange.sendResponseHeaders(status, response.getBytes().length);
        try (OutputStream os = exchange.getResponseBody()) {
            os.write(response.getBytes());
        }
    }
}