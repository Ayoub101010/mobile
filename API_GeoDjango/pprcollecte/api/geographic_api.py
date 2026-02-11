# api/geographic_api.py
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from django.contrib.gis.geos import Point
from django.contrib.gis.measure import Distance
from .models import Region, Prefecture, CommuneRurale
from .serializers import RegionSerializer, PrefectureSerializer, CommuneRuraleSerializer

class GeographyHierarchyAPIView(APIView):
    """
    API pour récupérer la hiérarchie géographique complète
    RÉgion > Préfecture > Commune avec données géométriques
    """
    
    def get(self, request):
        try:
            print("🌍 [Geographic API] Chargement hiérarchie complète...")
            
            # Récupérer toute la hiérarchie avec select_related pour optimiser
            regions = Region.objects.prefetch_related(
                'prefecture_set__communerurale_set'
            ).order_by('nom')
            
            hierarchy_data = []
            total_prefectures = 0
            total_communes = 0
            
            for region in regions:
                prefectures_data = []
                
                for prefecture in region.prefecture_set.all().order_by('nom'):
                    communes_data = []
                    total_prefectures += 1
                    
                    for commune in prefecture.communerurale_set.all().order_by('nom'):
                        communes_data.append({
                            'id': commune.id,
                            'nom': commune.nom,
                            'bounds': self._get_geometry_bounds(commune.geom) if commune.geom else None,
                            'center': self._get_geometry_center(commune.geom) if commune.geom else None
                        })
                        total_communes += 1
                    
                    prefectures_data.append({
                        'id': prefecture.id,
                        'nom': prefecture.nom,
                        'region_id': region.id,
                        'bounds': self._get_geometry_bounds(prefecture.geom) if prefecture.geom else None,
                        'center': self._get_geometry_center(prefecture.geom) if prefecture.geom else None,
                        'communes': communes_data
                    })
                
                hierarchy_data.append({
                    'id': region.id,
                    'nom': region.nom,
                    'bounds': self._get_geometry_bounds(region.geom) if region.geom else None,
                    'center': self._get_geometry_center(region.geom) if region.geom else None,
                    'prefectures': prefectures_data
                })
            
            print(f"✅ Hiérarchie chargée: {len(hierarchy_data)} régions, {total_prefectures} préfectures, {total_communes} communes")
            
            return Response({
                'success': True,
                'hierarchy': hierarchy_data,
                'total_regions': len(hierarchy_data),
                'total_prefectures': total_prefectures,
                'total_communes': total_communes
            })
            
        except Exception as e:
            print(f"❌ Erreur chargement hiérarchie: {e}")
            return Response({
                'success': False,
                'error': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def _get_geometry_bounds(self, geometry):
        """Calculer les bounds [minLng, minLat, maxLng, maxLat] pour zoom automatique"""
        if not geometry:
            return None
        
        try:
            extent = geometry.extent  # [minLng, minLat, maxLng, maxLat]
            return extent
        except:
            return None
    
    def _get_geometry_center(self, geometry):
        """Calculer le centre [lng, lat] pour zoom automatique"""
        if not geometry:
            return None
        
        try:
            centroid = geometry.centroid
            return [centroid.x, centroid.y]
        except:
            return None


class ZoomToLocationAPIView(APIView):
    """
    API pour obtenir les données de zoom pour une localisation spécifique
    """
    
    def get(self, request):
        location_type = request.GET.get('type')  # 'region', 'prefecture', 'commune'
        location_id = request.GET.get('id')
        
        if not location_type or not location_id:
            return Response({
                'success': False,
                'error': 'Paramètres type et id requis'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            location_id = int(location_id)
            
            if location_type == 'region':
                location = Region.objects.get(id=location_id)
            elif location_type == 'prefecture':
                location = Prefecture.objects.get(id=location_id)
            elif location_type == 'commune':
                location = CommuneRurale.objects.get(id=location_id)
            else:
                return Response({
                    'success': False,
                    'error': 'Type invalide. Utilisez: region, prefecture, commune'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            bounds = self._get_geometry_bounds(location.geom) if location.geom else None
            center = self._get_geometry_center(location.geom) if location.geom else None
            
            return Response({
                'success': True,
                'location': {
                    'id': location.id,
                    'nom': location.nom,
                    'type': location_type,
                    'bounds': bounds,
                    'center': center
                }
            })
            
        except (ValueError, TypeError):
            return Response({
                'success': False,
                'error': 'ID invalide'
            }, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            return Response({
                'success': False,
                'error': str(e)
            }, status=status.HTTP_404_NOT_FOUND)
    
    def _get_geometry_bounds(self, geometry):
        """Calculer les bounds pour zoom automatique"""
        if not geometry:
            return None
        
        try:
            extent = geometry.extent  # [minLng, minLat, maxLng, maxLat]
            return extent
        except:
            return None
    
    def _get_geometry_center(self, geometry):
        """Calculer le centre pour zoom automatique"""
        if not geometry:
            return None
        
        try:
            centroid = geometry.centroid
            return [centroid.x, centroid.y]
        except:
            return Nones