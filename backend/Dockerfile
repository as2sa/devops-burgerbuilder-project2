# Stage 1: Build the application using a Maven base image
FROM maven:3.8.7-eclipse-temurin-17-alpine AS build
WORKDIR /app

# Copy project files and build the JAR
COPY pom.xml .
COPY src ./src

# Build the Spring Boot application (will create a JAR file in target/)
RUN mvn clean package -DskipTests

# Stage 2: Create the final, small runtime image
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# Copy the built JAR from the build stage
COPY --from=build /app/target/*.jar app.jar

# Define the default command to run the application
ENTRYPOINT ["java", "-jar", "app.jar"]

# Expose the default port for the application (assuming port 8080)
EXPOSE 8080