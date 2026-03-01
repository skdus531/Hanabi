# Build stage
FROM ghcr.io/cirruslabs/flutter:3.22.2 AS build

WORKDIR /app

COPY pubspec.yaml .
RUN flutter pub get

COPY . .

ARG SUPABASE_URL
ARG SUPABASE_PUBLISH_KEY
ARG SUPABASE_ANON_KEY

RUN test -n "$SUPABASE_URL" && (test -n "$SUPABASE_PUBLISH_KEY" || test -n "$SUPABASE_ANON_KEY")

RUN flutter build web --release \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_PUBLISH_KEY=$SUPABASE_PUBLISH_KEY \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY

# Runtime stage
FROM nginx:alpine

COPY nginx.conf /etc/nginx/templates/default.conf.template
COPY --from=build /app/build/web /usr/share/nginx/html

ENV PORT=8080
EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
