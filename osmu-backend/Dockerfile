FROM eclipse-temurin:17-jdk-jammy AS build

WORKDIR /workspace

COPY gradlew settings.gradle build.gradle ./
COPY gradle ./gradle
COPY src ./src

RUN chmod +x ./gradlew
RUN ./gradlew bootJar --no-daemon

FROM eclipse-temurin:17-jre-jammy

WORKDIR /app

RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends wget \
    && groupadd --system --gid 10001 osmu \
    && useradd --system --uid 10001 --gid osmu --home-dir /home/osmu --create-home --shell /usr/sbin/nologin osmu \
    && chown -R osmu:osmu /app /home/osmu \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build --chown=osmu:osmu /workspace/build/libs/*.jar app.jar

ENV HOME=/home/osmu

USER 10001

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
