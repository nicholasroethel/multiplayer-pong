FROM node:12

# Create app directory
WORKDIR /

# install depencies
COPY package*.json ./

RUN npm install

# Bundle app source
COPY . .

CMD [ "node", "server/pong-server.js" ]
