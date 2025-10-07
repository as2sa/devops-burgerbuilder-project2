# Stage 1: Build the application using a Node.js base image
FROM node:18-alpine AS build-stage
WORKDIR /app

# Copy package files and install dependencies
COPY frontend/package*.json ./
RUN npm install

# Copy application source code and build the final static assets
COPY frontend/. .
RUN npm run build

# Stage 2: Serve the application using a lightweight Nginx image
FROM nginx:stable-alpine as production-stage

# Remove default Nginx config
RUN rm /etc/nginx/conf.d/default.conf

# Copy custom Nginx configuration (assuming you have one, or use a basic one)
# Since we don't have a custom config, we'll rely on the default settings or define a simple server block.

# Copy the built application files from the build stage to Nginx's HTML directory
COPY --from=build-stage /app/build /usr/share/nginx/html

# Expose the default HTTP port
EXPOSE 80

# Command to start Nginx
CMD ["nginx", "-g", "daemon off;"]