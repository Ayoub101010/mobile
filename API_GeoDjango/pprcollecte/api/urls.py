# api/urls.py - Version corrigée sans doublons
from django.urls import path, include
from .views import (
    LoginAPIView, PisteListCreateAPIView,
    ServicesSantesListCreateAPIView, AutresInfrastructuresListCreateAPIView, BacsListCreateAPIView,
    BatimentsAdministratifsListCreateAPIView, BusesListCreateAPIView, DalotsListCreateAPIView,
    EcolesListCreateAPIView, InfrastructuresHydrauliquesListCreateAPIView, LocalitesListCreateAPIView,
    MarchesListCreateAPIView, PassagesSubmersiblesListCreateAPIView, PontsListCreateAPIView,
    CommunesRuralesListCreateAPIView, PrefecturesListCreateAPIView, RegionsListCreateAPIView,
    UserManagementAPIView,ChausseesListCreateAPIView,PointsCoupuresListCreateAPIView,PointsCritiquesListCreateAPIView,
    SiteEnqueteListCreateAPIView, EnquetePolygoneListCreateAPIView
)
from .temporal_views import TemporalAnalysisAPIView
from .geographic_api import GeographyHierarchyAPIView, ZoomToLocationAPIView

urlpatterns = [
    #  APIs principales
    path('api/login/', LoginAPIView.as_view(), name='api-login'),
    path('api/users/', UserManagementAPIView.as_view(), name='api-user-management'),
    path('api/users/<int:user_id>/', UserManagementAPIView.as_view(), name='api-user-detail'),

    #  APIs géographiques
    path('api/geography/hierarchy/', GeographyHierarchyAPIView.as_view(), name='api-geography-hierarchy'),
    path('api/geography/zoom/', ZoomToLocationAPIView.as_view(), name='api-geography-zoom'),

    #  APIs de données géographiques
    path('api/regions/', RegionsListCreateAPIView.as_view(), name='api-regions'),
    path('api/prefectures/', PrefecturesListCreateAPIView.as_view(), name='api-prefectures'),
    path('api/communes_rurales/', CommunesRuralesListCreateAPIView.as_view(), name='api-communes-rurales'),

    #  APIs d'infrastructures
    path('api/pistes/', PisteListCreateAPIView.as_view(), name='api-pistes'),
    path('api/services_santes/', ServicesSantesListCreateAPIView.as_view(), name='api-services-santes'),
    path('api/autres_infrastructures/', AutresInfrastructuresListCreateAPIView.as_view(), name='api-autres-infrastructures'),
    path('api/bacs/', BacsListCreateAPIView.as_view(), name='api-bacs'),
    path('api/batiments_administratifs/', BatimentsAdministratifsListCreateAPIView.as_view(), name='api-batiments-administratifs'),
    path('api/buses/', BusesListCreateAPIView.as_view(), name='api-buses'),
    path('api/dalots/', DalotsListCreateAPIView.as_view(), name='api-dalots'),
    path('api/ecoles/', EcolesListCreateAPIView.as_view(), name='api-ecoles'),
    path('api/infrastructures_hydrauliques/', InfrastructuresHydrauliquesListCreateAPIView.as_view(), name='api-infrastructures-hydrauliques'),
    path('api/localites/', LocalitesListCreateAPIView.as_view(), name='api-localites'),
    path('api/marches/', MarchesListCreateAPIView.as_view(), name='api-marches'),
    path('api/passages_submersibles/', PassagesSubmersiblesListCreateAPIView.as_view(), name='api-passages-submersibles'),
    path('api/ponts/', PontsListCreateAPIView.as_view(), name='api-ponts'),
    path('api/chaussees/', ChausseesListCreateAPIView.as_view(), name='api-chaussees'),
    path('api/points_coupures/', PointsCoupuresListCreateAPIView.as_view(), name='api-points-coupures'),
    path('api/points_critiques/', PointsCritiquesListCreateAPIView.as_view(), name='api-points-critiques'),
    path('api/site_enquete/', SiteEnqueteListCreateAPIView.as_view(), name='api-site-enquete'),
    path('api/enquete_polygone/', EnquetePolygoneListCreateAPIView.as_view(), name='api-enquete-polygone'),
    #  APIs d'analyse
    path('api/temporal-analysis/', TemporalAnalysisAPIView.as_view(), name='api-temporal-analysis'),
    
    #  URLs spatiales (sans doublon)
    path('', include('api.spatial_urls')),
]