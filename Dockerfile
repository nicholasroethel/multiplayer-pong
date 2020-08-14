# Specify node version
FROM node:12

# Create app directory
WORKDIR /

# install depencies
COPY package*.json ./
RUN npm install

# Bundle app source
COPY . .

# Compile
RUN make compile

# Run the server
RUN make run-server
