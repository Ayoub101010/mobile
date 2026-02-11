# spatial_views.py - Version améliorée avec filtrage géographique hiérarchique
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from django.utils import timezone
from django.views.decorators.gzip import gzip_page
from django.utils.decorators import method_decorator
import time
from .models import *

@method_decorator(gzip_page, name='dispatch')
class CollectesGeoAPIView(APIView):
    """
    API améliorée - Retourne les données avec filtrage géographique hiérarchique
    """
    
    def get(self, request):
        """Retourne les infrastructures en GeoJSON avec filtres géographiques"""
        
        start_time = time.time()
        
        # ✅ RÉCUPÉRER LES FILTRES GÉOGRAPHIQUES
        region_id = request.GET.get('region_id')
        prefecture_id = request.GET.get('prefecture_id')
        commune_id = request.GET.get('commune_id')
        types = request.GET.getlist('types', [])
        
        print(f"🌍 [CollectesGeoAPI] Filtres reçus - Region: {region_id}, Prefecture: {prefecture_id}, Commune: {commune_id}, Types: {types}")
        
        results = {
            'type': 'FeatureCollection',
            'features': [],
            'total': 0,
            'filters_applied': {
                'region_id': region_id,
                'prefecture_id': prefecture_id,
                'commune_id': commune_id,
                'types': types
            },
            'timestamp': timezone.now().isoformat()
        }
        
        try:
            # ✅ CALCULER LES COMMUNES À INCLURE selon la hiérarchie
            target_commune_ids = self._get_target_communes(region_id, prefecture_id, commune_id)
            
            if target_commune_ids is not None and len(target_commune_ids) == 0:
                # Aucune commune trouvée pour les filtres donnés
                print("⚠️ Aucune commune trouvée pour ces filtres")
                return Response(results)
            
            print(f"🎯 Communes ciblées: {len(target_commune_ids) if target_commune_ids else 'toutes'}")
            
            # Chargement des infrastructures avec filtrage
            self._load_point_infrastructures(results, target_commune_ids, types)
            self._load_linear_infrastructures(results, target_commune_ids, types)
            
            processing_time = time.time() - start_time
            results['total'] = len(results['features'])
            results['processing_time'] = f"{processing_time:.2f}s"
            
            print(f"✅ {results['total']} features retournées en {processing_time:.2f}s")
            
            return Response(results)
            
        except Exception as e:
            print(f"❌ Erreur dans CollectesGeoAPIView: {e}")
            import traceback
            traceback.print_exc()
            return Response({
                'error': str(e), 
                'type': type(e).__name__,
                'details': 'Erreur lors de la récupération des données spatiales'
            }, status=500)

    def _get_target_communes(self, region_id, prefecture_id, commune_id):
        """
        Calcule la liste des communes à inclure selon les filtres hiérarchiques
        Retourne None pour "toutes les communes" ou une liste d'IDs
        """
        try:
            if commune_id:
                # Filtre par commune spécifique
                return [int(commune_id)]
            
            elif prefecture_id:
                # Filtre par préfecture - toutes ses communes
                communes = CommuneRurale.objects.filter(prefectures_id_id=int(prefecture_id))
                return list(communes.values_list('id', flat=True))
            
            elif region_id:
                # Filtre par région - toutes les communes de ses préfectures
                communes = CommuneRurale.objects.filter(
                    prefectures_id__regions_id_id=int(region_id)
                )
                return list(communes.values_list('id', flat=True))
            
            else:
                # Aucun filtre géographique - toutes les communes
                return None
                
        except (ValueError, TypeError) as e:
            print(f"❌ Erreur calcul communes cibles: {e}")
            return []

    def _should_include_type(self, type_name, types_filter):
        """Vérifie si ce type doit être inclus selon les filtres"""
        if not types_filter:
            return True
        return type_name in types_filter

    def _load_point_infrastructures(self, results, target_commune_ids, types_filter):
        point_models = {
            'services_santes': ServicesSantes,
            'ponts': Ponts,
            'buses': Buses,
            'dalots': Dalots,
            'ecoles': Ecoles,
            'marches': Marches,
            'batiments_administratifs': BatimentsAdministratifs,
            'infrastructures_hydrauliques': InfrastructuresHydrauliques,
            'localites': Localites,
            'autres_infrastructures': AutresInfrastructures,
        }
        
        for type_name, model_class in point_models.items():
            if not self._should_include_type(type_name, types_filter):
                continue
                
            try:
                queryset = model_class.objects.filter(geom__isnull=False)
                
                if target_commune_ids is not None:
                    queryset = queryset.filter(commune_id__in=target_commune_ids)
                
                for item in queryset:
                    try:
                        if item.geom:
                            commune_id = item.commune_id.id if item.commune_id else None
                            
                            feature = {
                                'type': 'Feature',
                                'id': f"{type_name}_{item.fid}",
                                'geometry': {
                                    'type': 'Point',
                                    'coordinates': [float(item.geom.x), float(item.geom.y)]
                                },
                                'properties': {
                                    'fid': int(item.fid),
                                    'type': type_name,  
                                    'commune_id': commune_id
                                    
                                }
                            }
                            results['features'].append(feature)
                    except Exception as e:
                        continue
                        
            except Exception as e:
                print(f"Erreur chargement {type_name}: {e}")
                continue
                        
            except Exception as e:
                print(f"Erreur chargement {type_name}: {e}")
                continue

    def _load_linear_infrastructures(self, results, target_commune_ids, types_filter):
        """Charge les infrastructures linéaires avec filtrage géographique"""
        
        # CHARGEMENT DES BACS
        if self._should_include_type('bacs', types_filter):
            try:
                bacs_queryset = Bacs.objects.filter(geom__isnull=False)
                
                if target_commune_ids is not None:
                    bacs_queryset = bacs_queryset.filter(commune_id__in=target_commune_ids)
                    print(f"  Filtrage bacs: {bacs_queryset.count()} éléments dans les communes {target_commune_ids}")
                
                for bac in bacs_queryset:
                    try:
                        if bac.geom:
                            geom_type = bac.geom.geom_type
                            coordinates = None
                            
                            if geom_type == 'Point':
                                coordinates = [float(bac.geom.x), float(bac.geom.y)]
                            elif geom_type == 'LineString':
                                simplified_geom = bac.geom.simplify(0.01)
                                coordinates = list(simplified_geom.coords)
                            elif geom_type == 'MultiLineString':
                                simplified_geom = bac.geom.simplify(0.01)
                                coordinates = [list(line.coords) for line in simplified_geom]
                            
                            if coordinates:
                                feature = {
                                    'type': 'Feature', 
                                    'id': f"bac_{bac.fid}",
                                    'geometry': {
                                        'type': geom_type,
                                        'coordinates': coordinates
                                    },
                                    'properties': {
                                        'fid': int(bac.fid),
                                        'type': 'bacs',
                                        'commune_id': bac.commune_id.id if bac.commune_id else None,
                                        
                                    }
                                }
                                results['features'].append(feature)
                    except Exception as e:
                        print(f"Erreur processing bac {bac.fid}: {e}")
                        continue
                        
            except Exception as e:
                print(f"Erreur chargement bacs: {e}")
        
        # CHARGEMENT DES PISTES
        if self._should_include_type('pistes', types_filter):
            try:
                piste_queryset = Piste.objects.filter(geom__isnull=False)
                
                if target_commune_ids is not None:
                    piste_queryset = piste_queryset.filter(communes_rurales_id__in=target_commune_ids)
                    print(f"  Filtrage pistes: {piste_queryset.count()} éléments dans les communes {target_commune_ids}")
                
                for piste in piste_queryset:
                    try:
                        if piste.geom:
                            simplified_geom = piste.geom.simplify(0.001)
                            
                            if simplified_geom.empty:
                                continue
                            
                            geom_4326 = simplified_geom.transform(4326, clone=True)
                            
                            coordinates = None
                            if geom_4326.geom_type == 'LineString':
                                coordinates = list(geom_4326.coords)
                            elif geom_4326.geom_type == 'MultiLineString':
                                coordinates = []
                                for line in geom_4326:
                                    coordinates.append(list(line.coords))
                            
                            if coordinates:
                                feature = {
                                    'type': 'Feature',
                                    'id': f"piste_{piste.id}",
                                    'geometry': {
                                        'type': geom_4326.geom_type,
                                        'coordinates': coordinates
                                    },
                                    'properties': {
                                        'id': int(piste.id),
                                        'type': 'pistes',
                                        'commune_id': piste.communes_rurales_id.id if piste.communes_rurales_id else None,
                                        
                                    }
                                }
                                results['features'].append(feature)
                    except Exception as e:
                        print(f"Erreur processing piste {piste.id}: {e}")
                        continue
                
            except Exception as e:
                print(f"Erreur chargement pistes: {e}")
        # ✅ AJOUTER : PASSAGES_SUBMERSIBLES comme LineString
        if self._should_include_type('passages_submersibles', types_filter):
            try:
                queryset = PassagesSubmersibles.objects.filter(geom__isnull=False)
                
                if target_commune_ids is not None:
                    queryset = queryset.filter(commune_id__in=target_commune_ids)
                
                for passage in queryset:
                    try:
                        if passage.geom:
                            # Vérifier si c'est déjà en WGS84 (SRID 4326)
                            if passage.geom.srid == 4326:
                                geom_4326 = passage.geom
                            else:
                                geom_4326 = passage.geom.transform(4326, clone=True)
                            
                            # Extraire les coordonnées LineString
                            coordinates = list(geom_4326.coords)
                            
                            feature = {
                                'type': 'Feature',
                                'id': f"passages_submersibles_{passage.fid}",
                                'geometry': {
                                    'type': 'LineString',
                                    'coordinates': coordinates
                                },
                                'properties': {
                                    'fid': int(passage.fid),
                                    'type': 'passages_submersibles',
                                    'commune_id': passage.commune_id.id if passage.commune_id else None,
                                    
                                }
                            }
                            results['features'].append(feature)
                            
                    except Exception as e:
                        print(f"Erreur processing passage {passage.fid}: {e}")
                        continue
                        
            except Exception as e:
                print(f"Erreur chargement passages_submersibles: {e}")


# Classes existantes inchangées
class CommunesSearchAPIView(APIView):
    """API de recherche communes"""
    
    def get(self, request):
        query = request.GET.get('q', '').strip()
        
        if not query or len(query) < 2:
            return Response({
                'communes': [],
                'message': 'Tapez au moins 2 caractères'
            })
        
        try:
            communes = CommuneRurale.objects.filter(
                nom__icontains=query
            ).select_related('prefectures_id__regions_id').order_by('nom')[:20]
            
            results = []
            for commune in communes:
                prefecture_nom = commune.prefectures_id.nom if commune.prefectures_id else "N/A"
                region_nom = commune.prefectures_id.regions_id.nom if commune.prefectures_id and commune.prefectures_id.regions_id else "N/A"
                
                results.append({
                    'id': commune.id,
                    'nom': commune.nom,
                    'prefecture': prefecture_nom,
                    'region': region_nom,
                })
            
            return Response({
                'communes': results,
                'total': len(results)
            })
            
        except Exception as e:
            return Response({
                'error': str(e),
                'communes': []
            }, status=500)


class TypesInfrastructuresAPIView(APIView):
    """API pour les types d'infrastructures"""
    
    def get(self, request):
        types_config = {
            'pistes': {'label': 'Pistes', 'icon': 'road', 'color': '#2C3E50'},
            'chaussees': {'label': 'Chaussées', 'icon': 'road', 'color': '#8e44ad'},
            'ponts': {'label': 'Ponts', 'icon': 'bridge', 'color': '#9B59B6'},
            'buses': {'label': 'Buses', 'icon': 'bus', 'color': '#E74C3C'},
            'dalots': {'label': 'Dalots', 'icon': 'water', 'color': '#3498DB'},
            'bacs': {'label': 'Bacs', 'icon': 'ship', 'color': '#F39C12'},
            'passages_submersibles': {'label': 'Passages submersibles', 'icon': 'water', 'color': '#1ABC9C'},
            'localites': {'label': 'Localités', 'icon': 'home', 'color': '#E67E22'},
            'ecoles': {'label': 'Écoles', 'icon': 'graduation-cap', 'color': '#27AE60'},
            'services_santes': {'label': 'Services de santé', 'icon': 'hospital', 'color': '#E74C3C'},
            'marches': {'label': 'Marchés', 'icon': 'shopping-cart', 'color': '#F1C40F'},
            'batiments_administratifs': {'label': 'Bâtiments administratifs', 'icon': 'building', 'color': '#34495E'},
            'infrastructures_hydrauliques': {'label': 'Infrastructures hydrauliques', 'icon': 'tint', 'color': '#3498DB'},
            'autres_infrastructures': {'label': 'Autres infrastructures', 'icon': 'map-pin', 'color': '#95A5A6'}
        }
        
        return Response({
            'types': types_config,
            'total': len(types_config)
        })