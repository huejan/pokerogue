# syntax=docker/dockerfile:1

ARG GIT_TAG=${GIT_TAG:-main}
ARG NODE_VERSION=${NODE_VERSION:-20.13.1}
ARG OS=${OS:-alpine}
ARG VITE_BYPASS_LOGIN=${VITE_BYPASS_LOGIN:-1}
### These seem to still not work, hence the proxy and insertions below
ARG VITE_SERVER_URL=${VITE_SERVER_URL:-http://0.0.0.0:8001}
ARG VITE_API_BASE_URL=${VITE_API_BASE_URL:-http://0.0.0.0:8001}

######################################
FROM arm64v8/node:${NODE_VERSION}-alpine

ENV VITE_BYPASS_TUTORIAL=0 \
    NEXT_TELEMETRY_DISABLED=1

######################################
FROM base AS build

ARG GIT_TAG \
    VITE_BYPASS_LOGIN \
    VITE_SERVER_URL \
    VITE_API_BASE_URL

WORKDIR /app

ADD --keep-git-dir=false https://github.com/pagefaultgames/pokerogue.git#${GIT_TAG} /app

RUN --mount=type=cache,target=/root/.npm \
    npm ci

RUN sed -i 's|const serverUrl = .*|const serverUrl = `${window.location.origin}/api`;\n|' src/utils.ts
RUN sed -i 's|export const apiUrl = .*|export const apiUrl = isLocal ? serverUrl : serverUrl;|' src/utils.ts

RUN NODE_OPTIONS=--max-old-space-size=8192 node /usr/local/bin/npm run build

######################################
FROM base AS app

ENV NODE_ENV=production \
    PORT=${PORT:-8000}

RUN npm install --location=global vite

USER node

WORKDIR /app

COPY --from=build /app/dist/ .
COPY --from=build /app/package.json ./package.json

EXPOSE $PORT

CMD vite --host --port $PORT
