FROM node:20-alpine
# Install Husky globally
RUN npm install -g husky

# RUN apt update && apt upgrade -y

# RUN wget https://fastdl.mongodb.org/tools/db/mongodb-database-tools-ubuntu2004-x86_64-100.9.1.deb && \
#     apt install ./mongodb-database-tools-*.deb && \
#     rm -f mongodb-database-tools-*.deb
ENV PORT=84
ENV MONGO_URI=mongodb://192.168.13.84:27017/store_app_live
ENV JWT_SECRET=change_this_to_a_long_random_secret
ENV JWT_EXPIRES=7d
ENV GOOGLE_CLIENT_ID=66417910817-0tp2pn046499v2c5b0rqhj3tocgs3e9i.apps.googleusercontent.com
ENV PROXY_ENABLED=false  

# minioconfig
ENV MINIO_ENDPOINT=localhost
ENV MINIO_PORT=9000
ENV MINIO_ACCESS_KEY=your_minio_access_key
ENV MINIO_SECRET_KEY=your_minio_secret_key
ENV MINIO_BUCKET=store-app

WORKDIR /app

RUN apk add --no-cache python3 make g++

COPY package.json /app/
RUN npm install -g @nestjs/cli
RUN npm install
RUN export NODE_OPTIONS="--max-old-space-size=15360"


# Skip Husky hooks installation during Docker build
ENV HUSKY_SKIP_INSTALL=true

COPY . /app/
# RUN npm run build
# COPY .docker.env /app/.env
CMD ["npm", "run","start:prod"]
EXPOSE ${PORT}


# docker build  --no-cache -t 192.168.13.72:5000/all_store_be_27032026 .      
# docker run -d --name all_store_be_27032026 -p 80:80 all_store_be_27032026_image

# docker tag all_store_be_31132025_image 192.168.13.72:5000/all_store_be_27032026
# docker push 192.168.13.72:5000/all_store_be_27032026
# docker pull 192.168.13.72:5000/all_store_be_27032026
# docker run -d --name all_store_be_27032026 -p 84:84 192.168.13.72:5000/all_store_be_27032026


# docker pull 192.168.13.72:5000/rrcomplaint_frontend
# docker run -d --name rrcomplaint_frontend -p 8003:80 192.168.13.72:5000/rrcomplaint_frontend