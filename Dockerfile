FROM node:18-alpine3.17

ENV NODE_ENV production

WORKDIR /quickchart

RUN apk add --upgrade apk-tools
RUN apk add --no-cache --virtual .build-deps yarn git build-base g++ python3
RUN apk add --no-cache --virtual .npm-deps cairo-dev pango-dev libjpeg-turbo-dev librsvg-dev
RUN apk add --no-cache --virtual .fonts libmount ttf-dejavu ttf-droid ttf-freefont ttf-liberation font-noto font-noto-emoji fontconfig
RUN apk add --no-cache --repository https://dl-cdn.alpinelinux.org/alpine/edge/community font-wqy-zenhei
RUN apk add --no-cache libimagequant-dev
RUN apk add --no-cache vips-dev
RUN apk add --no-cache --virtual .runtime-deps graphviz

COPY package*.json .
COPY yarn.lock .
RUN yarn install --production

# Atlas patch: the Chart.js 3/4 plugin builds `require('chart.js')`, which would
# resolve to the top-level v2 copy. Give each plugin a nested node_modules that
# points at the matching Chart.js version (same real path as the QuickChart alias).
RUN set -e; \
    for p in chartjs-plugin-annotation-v4 chartjs-plugin-datalabels-v4; do \
      mkdir -p node_modules/$p/node_modules && ln -s ../../chart.js-v4 node_modules/$p/node_modules/chart.js; done; \
    for p in chartjs-plugin-annotation-v3 chartjs-plugin-datalabels-v3; do \
      mkdir -p node_modules/$p/node_modules && ln -s ../../chart.js-v3 node_modules/$p/node_modules/chart.js; done; \
    node -e "for (const [p,v] of [['chartjs-plugin-annotation-v4','4'],['chartjs-plugin-datalabels-v4','4'],['chartjs-plugin-annotation-v3','3'],['chartjs-plugin-datalabels-v3','3']]) { const c=require(require.resolve('chart.js', {paths:['/quickchart/node_modules/'+p]})); const ver=(c.Chart||c).version; if(!ver.startsWith(v)) throw new Error(p+' sees chart.js '+ver); console.log(p,'-> chart.js',ver); }"

RUN apk update
RUN rm -rf /var/cache/apk/* && \
    rm -rf /tmp/*
RUN apk del .build-deps

COPY *.js ./
COPY lib/*.js lib/
COPY LICENSE .

EXPOSE 3400

ENTRYPOINT ["node", "--max-http-header-size=65536", "index.js"]
