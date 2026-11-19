package com.demo;

import com.sun.net.httpserver.HttpServer;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.sql.*;
import java.util.concurrent.*;

public class App {
    private static volatile String message = "Waiting for database";
    private static volatile boolean dbReady = false;
    private static final String HOST = System.getenv("DB_HOST");
    private static String env(String key, String fallback) {
        return System.getenv().getOrDefault(key, fallback);
    }
    private static void readDatabase() {
        String url = "jdbc:postgresql://" + HOST + ":5432/" + env("DB_NAME", "training")
            + "?sslmode=require&connectTimeout=5&socketTimeout=5";
        try (Connection conn = DriverManager.getConnection(url, env("DB_USER", "trainingadmin"), System.getenv("DB_PASSWORD"));
             Statement query = conn.createStatement()) {
            query.execute("CREATE TABLE IF NOT EXISTS training_messages (id integer PRIMARY KEY, message text NOT NULL)");
            query.execute("INSERT INTO training_messages (id,message) VALUES (1,'Hello from RDS PostgreSQL') ON CONFLICT (id) DO NOTHING");
            try (ResultSet rows = query.executeQuery("SELECT message FROM training_messages WHERE id=1")) {
                if (rows.next()) { message = rows.getString(1); dbReady = true;
                    System.out.println("[DB] Java API read: " + message); }
                else { dbReady = false; message = "No sample row"; }
            }
        } catch (SQLException e) {
            dbReady = false; message = "Database unavailable";
            System.err.println("[DB] Java retry; SQLState=" + e.getSQLState());
        }
    }
    private static String json(String value) {
        return value.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t");
    }
    public static void main(String[] args) throws Exception {
        if (HOST != null && !HOST.isBlank()) {
            Executors.newSingleThreadScheduledExecutor().scheduleWithFixedDelay(App::readDatabase, 0, 15, TimeUnit.SECONDS);
        } else { message = "Java API running (local, no DB configured)"; dbReady = true; }
        HttpServer server = HttpServer.create(new InetSocketAddress(8080), 0);
        server.createContext("/", exchange -> {
            boolean healthy = dbReady;
            byte[] response = ("{\"app\":\"java\",\"message\":\"" + json(message) + "\",\"ready\":" + healthy + "}").getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().set("Content-Type", "application/json");
            exchange.sendResponseHeaders(healthy ? 200 : 503, response.length);
            try (var output = exchange.getResponseBody()) { output.write(response); }
        });
        server.start();
        System.out.println("Java API listening on 8080");
    }
}
