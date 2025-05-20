
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
]