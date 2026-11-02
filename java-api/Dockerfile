# Stage 1: Build (Maven + JDK)
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn -B dependency:go-offline
COPY src ./src
RUN mvn -B package -DskipTests

# Stage 2: Run (smaller JRE image)
FROM eclipse-temurin:17-jre
WORKDIR /app
COPY --from=build /app/target/java-api-1.0.0.jar app.jar
EXPOSE 8080
CMD ["java", "-jar", "app.jar"]
