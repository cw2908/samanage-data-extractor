FROM ruby:2.6-alpine

# Install & create directories
RUN apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/main && \
  apk update && apk upgrade && \
  apk add build-base bash dcron && \
  apk upgrade --available && \
  rm -rf /var/cache/apk/* && \
  mkdir -p /swsd-data-extractor/exports/{log,errors}
RUN gem install bundler:2.1.4
RUN bundle config --jobs 4

# Copy app & bundle
WORKDIR /swsd-data-extractor
COPY . /swsd-data-extractor
RUN bundle

# Build cron jobs from config/schedule.rb
RUN bundle exec whenever -c && bundle exec whenever --update-crontab && touch /swsd-data-extractor/exports/log/cron.log

ENTRYPOINT crond -f && tail -f /swsd-data-extractor/exports/log/cron.log