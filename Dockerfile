# Specify node version
FROM node:12

# Create app directory
WORKDIR /usr/src/app

# install depencies
COPY package*.json ./
RUN npm install

# Bundle app source
COPY . .



EXPOSE 8089

# Compile
RUN make compile


CMD ["npm start"]

# Run the server
RUN make run-server



