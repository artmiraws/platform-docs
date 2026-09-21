# Build the static MkDocs site, then serve it with nginx.
FROM python:3.12-slim AS build

WORKDIR /docs
COPY requirements.txt mkdocs.yml ./
RUN pip install --no-cache-dir -r requirements.txt
COPY docs ./docs
RUN mkdocs build --strict

FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /docs/site /usr/share/nginx/html

EXPOSE 80
