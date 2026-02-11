#  - Fonctions utilitaires pour GeoDjango

from django.contrib.gis.geos import GEOSGeometry
from django.contrib.gis.db.models.functions import Transform
from .models import CommuneRurale, Prefecture, Region

class GeoQueryHelper:
    """Classe utilitaire pour les requêtes géospatiales"""
    
    @staticmethod
    def get_commune_geometry(commune_id):
        """Récupérer la géométrie d'une commune rurale"""
        try:
            commune = CommuneRurale.objects.get(id=commune_id)
            return commune.geom
        except CommuneRurale.DoesNotExist:
            return None
    
    @staticmethod
    def transform_geometry(geom, target_srid=4326):
        """Transformer une géométrie vers un SRID cible"""
        if not geom:
            return None
        try:
            if geom.srid != target_srid:
                geom.transform(target_srid)
            return geom
        except Exception as e:
            print(f"Erreur transformation géométrie: {e}")
            return None

    @staticmethod
    def find_commune_by_point(point):
        """Trouver la commune rurale contenant un point"""
        if not point:
            return None
        try:
            # S'assurer que le point est en 4326 car les polygones le sont
            if point.srid != 4326:
                point = point.clone()
                point.transform(4326)
            
            return CommuneRurale.objects.filter(geom__contains=point).first()
        except Exception as e:
            print(f"Erreur recherche commune: {e}")
            return None

class InfrastructureTypeMapper:
    """Classe pour mapper les types d'infrastructures"""
    
    TYPE_ICONS = {
        'services_santes': 'hospital',
        'bacs': 'ship', 
        'ponts': 'bridge',
        'buses': 'bus',
        'dalots': 'water',
        'ecoles': 'graduation-cap',
        'marches': 'shopping-cart',
        'batiments_administratifs': 'building',
        'infrastructures_hydrauliques': 'tint',
        'localites': 'home',
        'passages_submersibles': 'water',
        'autres_infrastructures': 'map-pin',
        'pistes': 'road'
    }
    
    TYPE_COLORS = {
        'services_santes': '#E74C3C',
        'bacs': '#F39C12',
        'ponts': '#9B59B6', 
        'buses': '#E74C3C',
        'dalots': '#3498DB',
        'ecoles': '#27AE60',
        'marches': '#F1C40F',
        'batiments_administratifs': '#34495E',
        'infrastructures_hydrauliques': '#3498DB',
        'localites': '#E67E22',
        'passages_submersibles': '#1ABC9C',
        'autres_infrastructures': '#95A5A6',
        'pistes': '#2C3E50'
    }
    
    @classmethod
    def get_icon(cls, type_name):
        return cls.TYPE_ICONS.get(type_name, 'map-pin')
    
    @classmethod  
    def get_color(cls, type_name):
        return cls.TYPE_COLORS.get(type_name, '#95A5A6')

def validate_coordinates(x, y):
    """Valider des coordonnées géographiques"""
    try:
        x_float = float(x)
        y_float = float(y)
        
        # Vérifier les limites géographiques pour la Guinée
        if not (-16 <= x_float <= -6):
            return False, "Longitude hors limites Guinée"
        if not (6 <= y_float <= 14):
            return False, "Latitude hors limites Guinée"
            
        return True, None
    except (ValueError, TypeError):
        return False, "Coordonnées invalides"