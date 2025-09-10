# Use lightweight Node image
FROM node:lts-alpine

# Set working directory
WORKDIR /usr/src/app

# Copy only package files for dependency install
COPY package.json package-lock.json ./

# Install dependencies
RUN npm ci --only=production

# Copy built files
COPY build/ ./build/

# Install simple HTTP server to serve static files
RUN npm install -g serve

# Expose port
EXPOSE 3000

# Command to run the app
CMD ["serve", "-s", "build", "-l", "3000"]
