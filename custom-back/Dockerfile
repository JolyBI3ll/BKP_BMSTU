FROM taigaio/taiga-back:latest

# RUN pip install "django>=3.2,<4.0" "djangorestframework>=3.12,<3.15"

# Insert custom configuration into the taiga configuration file
COPY config.append.py /taiga-back/settings
RUN cat /taiga-back/settings/config.append.py >> /taiga-back/settings/config.py && rm /taiga-back/settings/config.append.py

COPY urls.append.py /taiga-back/taiga/
RUN cat /taiga-back/taiga/urls.append.py >> /taiga-back/taiga/urls.py && rm /taiga-back/taiga/urls.append.py
