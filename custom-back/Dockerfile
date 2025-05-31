FROM taigaio/taiga-back:latest

# Insert custom configuration into the taiga configuration file
COPY config.append.py /taiga-back/settings
RUN cat /taiga-back/settings/config.append.py >> /taiga-back/settings/config.py && rm /taiga-back/settings/config.append.py

COPY urls.append.py /taiga-back/taiga/
RUN cat /taiga-back/taiga/urls.append.py >> /taiga-back/taiga/urls.py && rm /taiga-back/taiga/urls.append.py

RUN apt-get update && apt-get install -y --no-install-recommends curl && \
    curl -k "https://gu-st.ru/content/Other/doc/russian_trusted_root_ca.cer" >> $(python -m certifi) && \
    apt-get remove -y curl && \
    rm -rf /var/lib/apt/lists/*

RUN pip install lxml
