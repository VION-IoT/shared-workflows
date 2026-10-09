# dotnet-aot-app.yml stages each Linux publish into publish/<arch>/ beside this file, and Buildx sets
# TARGETARCH per platform (amd64 / arm64). The proof never builds this image: push-linux-image runs
# only outside pull requests.
FROM mcr.microsoft.com/dotnet/runtime-deps:10.0-alpine

WORKDIR /app

ARG TARGETARCH
COPY publish/${TARGETARCH}/ .

# actions/upload-artifact does not keep the executable bit.
RUN chmod +x Vion.Fixture.AotApp

ENTRYPOINT ["./Vion.Fixture.AotApp"]
