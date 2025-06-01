
#Drawio plugin urls
from taiga_contrib_drawio.views import DrawioViewSet

urlpatterns += [
    path('api/v1/drawio/<int:attachment_id>/', DrawioViewSet.as_view({
        'get': 'retrieve',
        'post': 'create'
    }), name='drawio-detail'),

    path('api/v1/drawio/<int:attachment_id>/raw/', DrawioViewSet.as_view({
        'get': 'raw'
    }), name='drawio-raw'),

    path('api/v1/drawio/<int:attachment_id>/reset/', DrawioViewSet.as_view({
        'delete': 'reset'
    }), name='drawio-reset'),

    path('api/v1/drawio/<int:attachment_id>/generate/', DrawioViewSet.as_view({
        'post': 'generate_from_prompt'
    }), name='drawio-generate-from-prompt'),

    path('api/v1/drawio/oauth/', DrawioViewSet.as_view({
        'post': 'oauth_callback'
    }), name='drawio-oauth-bmstu'),
]