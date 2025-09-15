import com.sun.net.httpserver.HttpServer;
import controller.PersonController;

import java.io.IOException;
import java.net.InetSocketAddress;

public class RestApiServer {
    public static void main(String[] args) throws IOException {
        HttpServer server = HttpServer.create(new InetSocketAddress(8080), 0);

        server.createContext("/people", new PersonController());

        server.setExecutor(null);
        server.start();
        System.out.println("🚀 Servidor REST corriendo en http://localhost:8080/people");
    }
}
