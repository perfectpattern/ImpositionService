# build client
FROM node:current-alpine as client-builder

RUN apk add --no-cache git \
    && mkdir /work \
    && chown node:node /work

USER node

COPY --chown=node:node ["src/main/client", "/work/client"]
WORKDIR /work/client
RUN ls -l

RUN npm install
RUN npx ng version
RUN npx ng build --prod=true --outputPath=/work/static --optimization=true

# build application
FROM openjdk:8u201-jdk-alpine3.9 as java-builder

RUN apk add imagemagick git \
    && mkdir -p /work/src \
    && mkdir -p /work/gradle \
    && mkdir -p /work/.git

COPY .git /work/.git
COPY src /work/src
COPY gradle /work/gradle
COPY build.gradle settings.gradle gradlew /work/

RUN rm -rf /work/src/main/resources/static
COPY --from=client-builder /work/static /work/src/main/resources/static

WORKDIR /work
RUN ./gradlew -i build --no-daemon

# build final image
FROM openjdk:8u201-jre-alpine3.9

ENV SHEET_BLEED_MM=0
ENV HIDE_LABELS=false

RUN apk add imagemagick
RUN mkdir /data
COPY --from=java-builder /work/build/libs/*.jar /opt/ImpositionService.jar

HEALTHCHECK  --interval=10s --timeout=3s CMD wget --quiet --tries=1 --spider http://localhost:4200/status || exit 1

ENTRYPOINT ["java", "-Xmx6g", "-jar","/opt/ImpositionService.jar"]

