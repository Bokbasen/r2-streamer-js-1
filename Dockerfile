FROM node:8-alpine
RUN apk add --update git && \
rm -rf /tmp/* /var/cache/apk/*
RUN mkdir -p /home/node/app
RUN chown node:node /home/node/app
WORKDIR /home/node/app
RUN npm update --global
USER node
COPY package.json /home/node/app
COPY package-lock.json /home/node/app
RUN npm install
RUN npm update
COPY . .
ENV NODE_ENV development
RUN npm run build:all
CMD ["npm", "run", "server-debug", "/home/node/app/misc/epubs"]
EXPOSE 8080
