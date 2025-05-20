
INSTALLED_APPS += ["taiga_contrib_drawio.apps.TaigaContribDrawioConfig"]
TAIGA_PLUGINS = TAIGA_PLUGINS + ["taiga_contrib_drawio"] if "TAIGA_PLUGINS" in globals() else ["taiga_contrib_drawio"]
# INSTALLED_APPS += ["rest_framework"]

