# Use an official Eclipse Temurin image with JDK 17 and a lightweight Alpine Linux base
FROM eclipse-temurin:17-jdk-alpine

# Expose port 8080 to allow external access to the application
EXPOSE 8080

# Set an environment variable for the application home directory
ENV APP_HOME /usr/src/app

# Copy the compiled JAR file from the target directory to the application home directory
COPY target/*.jar $APP_HOME/app.jar

# Set the working directory inside the container to the application home
WORKDIR $APP_HOME

# Define the default command to run the JAR file when the container starts
CMD ["java", "-jar", "app.jar"]
