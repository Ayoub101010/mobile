from django.shortcuts import render

# Create your views here.
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework import generics
from django.db import models as db_models
#from django.contrib.gis.db.models.functions import Transform
from .models import Login, UserRegion, UserPrefecture
from .serializers import LoginSerializer, PisteReadSerializer, PisteWriteSerializer
from .models import Piste
from .models import (
    ServicesSantes, AutresInfrastructures, Bacs, BatimentsAdministratifs,
    Buses, Dalots, Ecoles, InfrastructuresHydrauliques, Localites,
    Marches, PassagesSubmersibles, Ponts, CommuneRurale, Prefecture, Region, Chaussees,PointsCritiques,PointsCoupures,
    SiteEnquete, EnquetePolygone
)
from .serializers import (
    ServicesSantesSerializer, AutresInfrastructuresSerializer, BacsSerializer,
    BatimentsAdministratifsSerializer, BusesSerializer, DalotsSerializer,
    EcolesSerializer, InfrastructuresHydrauliquesSerializer, LocalitesSerializer,
    MarchesSerializer, PassagesSubmersiblesSerializer, PontsSerializer, CommuneRuraleSerializer,
      PrefectureSerializer, RegionSerializer,UserCreateSerializer, UserUpdateSerializer, ChausseesSerializer, PointsCoupuresSerializer,PointsCritiquesSerializer,
      SiteEnqueteSerializer, EnquetePolygoneSerializer
)
from .spatial_utils import GeoQueryHelper
from django.contrib.gis.geos import Point

class AutoCommuneMixin:
    """Mixin pour attribuer automatiquement la commune via le GPS lors de perform_create
       + corriger le code_piste avec region_id/prefecture_id/commune_id"""
    
    def perform_create(self, serializer):
        geom = serializer.validated_data.get('geom')
        
        # Déterminer quel champ de commune utiliser
        model_class = serializer.Meta.model
        commune_field = None
        if hasattr(model_class, 'communes_rurales_id'):
            commune_field = 'communes_rurales_id'
        elif hasattr(model_class, 'commune_id'):
            commune_field = 'commune_id'
        elif hasattr(model_class, 'communes_rurales'):
            commune_field = 'communes_rurales'

        commune = None

        # Si geom présente et commune absente, on cherche spatialement
        if geom and commune_field and not serializer.validated_data.get(commune_field):
            point_to_check = None
            try:
                if geom.geom_type == 'Point':
                    point_to_check = geom
                elif geom.geom_type == 'LineString':
                    point_to_check = Point(geom[0], srid=geom.srid)
                elif geom.geom_type == 'MultiLineString':
                    point_to_check = Point(geom[0][0], srid=geom.srid)
                elif geom.geom_type == 'Polygon':
                    point_to_check = Point(geom[0][0], srid=geom.srid)
                elif geom.geom_type == 'MultiPolygon':
                    point_to_check = Point(geom[0][0][0], srid=geom.srid)
                
                if point_to_check:
                    commune = GeoQueryHelper.find_commune_by_point(point_to_check)
                    if commune:
                        print(f"📍 Attribution spatiale auto: {commune.nom} pour {model_class.__name__}")
                        serializer.validated_data[commune_field] = commune
            except Exception as e:
                print(f"❌ Erreur attribution auto commune: {e}")

        instance = serializer.save()

        # ===== CORRECTION DU CODE_PISTE =====
        self._fix_code_piste(instance, commune, model_class)

    def _fix_code_piste(self, instance, commune, model_class):
        """Remplace _0_0_0_ dans code_piste par _regionId_prefectureId_communeId_"""
        try:
            if not commune:
                # Essayer de récupérer la commune depuis l'instance sauvée
                if hasattr(instance, 'communes_rurales_id') and instance.communes_rurales_id:
                    commune = instance.communes_rurales_id
                elif hasattr(instance, 'commune_id') and instance.commune_id:
                    commune = instance.commune_id
                else:
                    return

            # Remonter la hiérarchie : commune → préfecture → région
            prefecture = commune.prefectures_id if commune.prefectures_id else None
            region = prefecture.regions_id if prefecture and prefecture.regions_id else None

            region_id = region.id if region else 0
            prefecture_id = prefecture.id if prefecture else 0
            commune_id = commune.id if commune else 0

            new_prefix = f"{region_id}_{prefecture_id}_{commune_id}"

            # --- CAS 1 : Piste (code_piste est un CharField) ---
            if model_class.__name__ == 'Piste' and hasattr(instance, 'code_piste'):
                old_code = instance.code_piste or ''
                if '_0_0_0_' in old_code:
                    new_code = old_code.replace('_0_0_0_', f'_{new_prefix}_', 1)
                    instance.code_piste = new_code
                    instance.save(update_fields=['code_piste'])
                    print(f"✅ Code piste corrigé: {old_code} → {new_code}")

           # --- CAS 2 : Autres entités (code_piste est un FK vers Piste) ---
            elif hasattr(instance, 'code_piste_id'):
                old_code = instance.code_piste_id or ''
                if '_0_0_0_' in old_code:
                    date_suffix = old_code.split('_0_0_0_')[-1]
                    
                    from .models import Piste
                    matching_piste = Piste.objects.filter(
                        code_piste__endswith=date_suffix
                    ).first()
                    
                    if matching_piste:
                        # Si la piste trouvée a encore _0_0_0_, la corriger d'abord
                        if '_0_0_0_' in (matching_piste.code_piste or ''):
                            piste_commune = matching_piste.communes_rurales_id
                            if piste_commune:
                                pref = piste_commune.prefectures_id
                                reg = pref.regions_id if pref else None
                                r_id = reg.id if reg else 0
                                p_id = pref.id if pref else 0
                                c_id = piste_commune.id
                                new_piste_code = matching_piste.code_piste.replace(
                                    '_0_0_0_', f'_{r_id}_{p_id}_{c_id}_', 1
                                )
                                matching_piste.code_piste = new_piste_code
                                matching_piste.save(update_fields=['code_piste'])
                                print(f"✅ Piste référencée corrigée aussi: → {new_piste_code}")
                        
                        # Maintenant mettre à jour le FK
                        instance.code_piste_id = matching_piste.code_piste
                        instance.save(update_fields=['code_piste_id'])
                        print(f"✅ FK code_piste corrigé: {old_code} → {matching_piste.code_piste}")
                    else:
                        print(f"⚠️ Aucune piste trouvée avec suffixe '{date_suffix}'")

           # --- CAS 3 : Autres entités avec code_piste CharField (non FK) ---
            elif hasattr(instance, 'code_piste'):
                field = model_class._meta.get_field('code_piste')
                if not field.is_relation:
                    old_code = instance.code_piste or ''
                    if '_0_0_0_' in old_code:
                        date_suffix = old_code.split('_0_0_0_')[-1]
                        
                        from .models import Piste
                        matching_piste = Piste.objects.filter(
                            code_piste__endswith=date_suffix
                        ).first()
                        
                        if matching_piste:
                            # Corriger la piste si nécessaire
                            if '_0_0_0_' in (matching_piste.code_piste or ''):
                                piste_commune = matching_piste.communes_rurales_id
                                if piste_commune:
                                    pref = piste_commune.prefectures_id
                                    reg = pref.regions_id if pref else None
                                    r_id = reg.id if reg else 0
                                    p_id = pref.id if pref else 0
                                    c_id = piste_commune.id
                                    new_piste_code = matching_piste.code_piste.replace(
                                        '_0_0_0_', f'_{r_id}_{p_id}_{c_id}_', 1
                                    )
                                    matching_piste.code_piste = new_piste_code
                                    matching_piste.save(update_fields=['code_piste'])
                                    print(f"✅ Piste référencée corrigée: → {new_piste_code}")
                            
                            instance.code_piste = matching_piste.code_piste
                            instance.save(update_fields=['code_piste'])
                            print(f"✅ Code piste corrigé: {old_code} → {matching_piste.code_piste}")
                        else:
                            print(f"⚠️ Aucune piste avec suffixe '{date_suffix}'")

        except Exception as e:
            print(f"⚠️ Erreur correction code_piste: {e}")

class RBACFilterMixin:
    """
    Mixin pour filtrer les données GET selon les communes accessibles de l'utilisateur.
    
    Utilisation : ajouter ce mixin à toute vue ListCreateAPIView.
    Le mobile envoie ?login_id=X, le serveur calcule les communes accessibles.
    Rétro-compatible : si ?commune_id=Y est envoyé, filtre par une seule commune.
    """
    # Sous-classes peuvent overrider ce champ si le nom diffère
    commune_field_name = 'commune_id'

    def filter_queryset_by_rbac(self, qs):
        """Filtre le queryset selon le rôle de l'utilisateur"""

        # ===== NOUVEAU : Filtre par login_id (RBAC) =====
        login_id = self.request.query_params.get('login_id')
        if login_id:
            try:
                user = Login.objects.get(id=login_id)

                # Super_admin / Admin → tout voir
                if user.role in ('Super_admin', 'Admin'):
                    return qs

                # BTGR → communes des régions assignées
                if user.role == 'BTGR':
                    region_ids = UserRegion.objects.filter(
                        login_id=login_id
                    ).values_list('region_id', flat=True)

                    pref_ids = Prefecture.objects.filter(
                        regions_id__in=region_ids
                    ).values_list('id', flat=True)

                    commune_ids = CommuneRurale.objects.filter(
                        prefectures_id__in=pref_ids
                    ).values_list('id', flat=True)

                    return qs.filter(**{f'{self.commune_field_name}__in': commune_ids})

                # SPGR → communes des préfectures assignées
                if user.role == 'SPGR':
                    pref_ids = UserPrefecture.objects.filter(
                        login_id=login_id
                    ).values_list('prefecture_id', flat=True)

                    commune_ids = CommuneRurale.objects.filter(
                        prefectures_id__in=pref_ids
                    ).values_list('id', flat=True)

                    return qs.filter(**{f'{self.commune_field_name}__in': commune_ids})

                # Rôle inconnu → rien
                return qs.none()

            except Login.DoesNotExist:
                print(f"❌ RBAC: login_id={login_id} non trouvé")
                return qs.none()

        # ===== FALLBACK : Ancien filtre par commune_id unique =====
        commune_id = self.request.query_params.get(self.commune_field_name)
        if not commune_id:
            # Essayer aussi le nom générique 'commune_id'
            commune_id = self.request.query_params.get('commune_id')
        if commune_id:
            return qs.filter(**{self.commune_field_name: commune_id})

        return qs
    

class RegionsListCreateAPIView(generics.ListCreateAPIView):
    queryset = Region.objects.all()
    serializer_class = RegionSerializer

class PrefecturesListCreateAPIView(generics.ListCreateAPIView):
    queryset = Prefecture.objects.all()
    serializer_class = PrefectureSerializer

class CommunesRuralesListCreateAPIView(generics.ListCreateAPIView):
    serializer_class = CommuneRuraleSerializer
    
    def get_queryset(self):
        queryset = CommuneRurale.objects.select_related(
            'prefectures_id',
            'prefectures_id__regions_id'
        )
        
        # Ajouter le filtre de recherche
        search = self.request.GET.get('q', '')
        if search:
            queryset = queryset.filter(nom__icontains=search)
        
        return queryset.order_by('nom')

# Modifiez toutes vos vues pour qu'elles ressemblent à ceci :
class ChausseesListCreateAPIView(RBACFilterMixin, AutoCommuneMixin, generics.ListCreateAPIView):
    serializer_class = ChausseesSerializer
    commune_field_name = 'communes_rurales_id'

    def get_queryset(self):
        qs = Chaussees.objects.all()
        qs = self.filter_queryset_by_rbac(qs)

        # filtre supplémentaire par code_piste (garder)
        code_piste = self.request.query_params.get('code_piste')
        if code_piste:
            qs = qs.filter(code_piste_id=code_piste)

        return qs


class PointsCoupuresListCreateAPIView(RBACFilterMixin, AutoCommuneMixin, generics.ListCreateAPIView):
    serializer_class = PointsCoupuresSerializer
    commune_field_name = 'commune_id'

    def get_queryset(self):
        qs = PointsCoupures.objects.all()
        qs = self.filter_queryset_by_rbac(qs)

        # filtre supplémentaire par chaussée (garder)
        chaussee_id = self.request.query_params.get('chaussee_id')
        if chaussee_id:
            qs = qs.filter(chaussee_id=chaussee_id)

        return qs


class PointsCritiquesListCreateAPIView(RBACFilterMixin, AutoCommuneMixin, generics.ListCreateAPIView):
    serializer_class = PointsCritiquesSerializer
    commune_field_name = 'commune_id'

    def get_queryset(self):
        qs = PointsCritiques.objects.all()
        qs = self.filter_queryset_by_rbac(qs)

        chaussee_id = self.request.query_params.get('chaussee_id')
        if chaussee_id:
            qs = qs.filter(chaussee_id=chaussee_id)

        return qs



class ServicesSantesListCreateAPIView(RBACFilterMixin, AutoCommuneMixin, generics.ListCreateAPIView):
    serializer_class = ServicesSantesSerializer
    commune_field_name = 'commune_id'

    def get_queryset(self):
        return self.filter_queryset_by_rbac(ServicesSantes.objects.all())

class AutresInfrastructuresListCreateAPIView(RBACFilterMixin, AutoCommuneMixin, generics.ListCreateAPIView):
    serializer_class = AutresInfrastructuresSerializer
    commune_field_name = 'commune_id'

    def get_queryset(self):
        return self.filter_queryset_by_rbac(AutresInfrastructures.objects.all())

class BacsListCreateAPIView(RBACFilterMixin, AutoCommuneMixin, generics.ListCreateAPIView):
    serializer_class = BacsSerializer
    commune_field_name = 'commune_id'

    def get_queryset(self):
        return self.filter_queryset_by_rbac(Bacs.objects.all())

class BatimentsAdministratifsListCreateAPIView(RBACFilterMixin, AutoCommuneMixin, generics.ListCreateAPIView):
    serializer_class = BatimentsAdministratifsSerializer
    commune_field_name = 'commune_id'

    def get_queryset(self):
        return self.filter_queryset_by_rbac(BatimentsAdministratifs.objects.all())

class BusesListCreateAPIView(RBACFilterMixin, AutoCommuneMixin, generics.ListCreateAPIView):
    serializer_class = BusesSerializer
    commune_field_name = 'commune_id'

    def get_queryset(self):
        return self.filter_queryset_by_rbac(Buses.objects.all())

class DalotsListCreateAPIView(RBACFilterMixin, AutoCommuneMixin, generics.ListCreateAPIView):
    serializer_class = DalotsSerializer
    commune_field_name = 'commune_id'

    def get_queryset(self):
        return self.filter_queryset_by_rbac(Dalots.objects.all())

class EcolesListCreateAPIView(RBACFilterMixin, AutoCommuneMixin, generics.ListCreateAPIView):
    serializer_class = EcolesSerializer
    commune_field_name = 'commune_id'

    def get_queryset(self):
        return self.filter_queryset_by_rbac(Ecoles.objects.all())

class InfrastructuresHydrauliquesListCreateAPIView(RBACFilterMixin, AutoCommuneMixin, generics.ListCreateAPIView):
    serializer_class = InfrastructuresHydrauliquesSerializer
    commune_field_name = 'commune_id'

    def get_queryset(self):
        return self.filter_queryset_by_rbac(InfrastructuresHydrauliques.objects.all())

class LocalitesListCreateAPIView(RBACFilterMixin, AutoCommuneMixin, generics.ListCreateAPIView):
    serializer_class = LocalitesSerializer
    commune_field_name = 'commune_id'

    def get_queryset(self):
        return self.filter_queryset_by_rbac(Localites.objects.all())

class MarchesListCreateAPIView(RBACFilterMixin, AutoCommuneMixin, generics.ListCreateAPIView):
    serializer_class = MarchesSerializer
    commune_field_name = 'commune_id'

    def get_queryset(self):
        return self.filter_queryset_by_rbac(Marches.objects.all())

class PassagesSubmersiblesListCreateAPIView(RBACFilterMixin, AutoCommuneMixin, generics.ListCreateAPIView):
    serializer_class = PassagesSubmersiblesSerializer
    commune_field_name = 'commune_id'

    def get_queryset(self):
        return self.filter_queryset_by_rbac(PassagesSubmersibles.objects.all())

class PontsListCreateAPIView(RBACFilterMixin, AutoCommuneMixin, generics.ListCreateAPIView):
    serializer_class = PontsSerializer
    commune_field_name = 'commune_id'

    def get_queryset(self):
        return self.filter_queryset_by_rbac(Ponts.objects.all())

class SiteEnqueteListCreateAPIView(RBACFilterMixin, AutoCommuneMixin, generics.ListCreateAPIView):
    serializer_class = SiteEnqueteSerializer
    commune_field_name = 'commune_id'

    def get_queryset(self):
        return self.filter_queryset_by_rbac(SiteEnquete.objects.all())

class EnquetePolygoneListCreateAPIView(RBACFilterMixin, AutoCommuneMixin, generics.ListCreateAPIView):
    serializer_class = EnquetePolygoneSerializer
    commune_field_name = 'communes_rurales_id'

    def get_queryset(self):
        return self.filter_queryset_by_rbac(EnquetePolygone.objects.all())




class LoginAPIView(APIView):
    # GET pour récupérer tous les utilisateurs
    def get(self, request):
        users = Login.objects.all()
        serializer = LoginSerializer(users, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)

    def post(self, request):
        mail = request.data.get('mail')
        mdp = request.data.get('mdp')

        if not mail or not mdp:
            return Response({"error": "Mail et mot de passe requis"}, status=status.HTTP_400_BAD_REQUEST)

        try:
            user = Login.objects.get(mail=mail)
        except Login.DoesNotExist:
            return Response({"error": "Utilisateur non trouvé"}, status=status.HTTP_404_NOT_FOUND)

        if user.mdp != mdp:
            return Response({"error": "Mot de passe incorrect"}, status=status.HTTP_401_UNAUTHORIZED)

        # Données de base (existant)
        data = LoginSerializer(user).data

        # ===== NOUVEAU : Régions assignées (pour BTGR) =====
        assigned_regions = []
        for ur in UserRegion.objects.filter(login=user).select_related('region'):
            assigned_regions.append({
                'region_id': ur.region_id,
                'region_nom': ur.region.nom if ur.region else None
            })
        data['assigned_regions'] = assigned_regions

        # ===== NOUVEAU : Préfectures assignées (pour SPGR) =====
        assigned_prefectures = []
        for up in UserPrefecture.objects.filter(login=user).select_related('prefecture'):
            assigned_prefectures.append({
                'prefecture_id': up.prefecture_id,
                'prefecture_nom': up.prefecture.nom if up.prefecture else None
            })
        data['assigned_prefectures'] = assigned_prefectures

        # ===== NOUVEAU : Communes accessibles selon le rôle =====
        data['accessible_commune_ids'] = self._get_accessible_commune_ids(
            user, assigned_regions, assigned_prefectures
        )

        print(f" Login {user.nom} {user.prenom} | role={user.role} | "
              f"regions={len(assigned_regions)} | prefectures={len(assigned_prefectures)} | "
              f"communes={len(data['accessible_commune_ids'])}")

        return Response(data, status=status.HTTP_200_OK)

    def _get_accessible_commune_ids(self, user, assigned_regions, assigned_prefectures):
        """Calcule la liste des commune_ids accessibles selon le rôle RBAC"""

        # Super_admin / Admin → TOUTES les communes
        if user.role in ('Super_admin', 'Admin'):
            return list(CommuneRurale.objects.values_list('id', flat=True))

        # BTGR → communes des régions assignées
        if user.role == 'BTGR' and assigned_regions:
            region_ids = [r['region_id'] for r in assigned_regions]
            pref_ids = Prefecture.objects.filter(
                regions_id__in=region_ids
            ).values_list('id', flat=True)
            return list(CommuneRurale.objects.filter(
                prefectures_id__in=pref_ids
            ).values_list('id', flat=True))

        # SPGR → communes des préfectures assignées
        if user.role == 'SPGR' and assigned_prefectures:
            pref_ids = [p['prefecture_id'] for p in assigned_prefectures]
            return list(CommuneRurale.objects.filter(
                prefectures_id__in=pref_ids
            ).values_list('id', flat=True))

        return []


class PisteListCreateAPIView(RBACFilterMixin, AutoCommuneMixin, generics.ListCreateAPIView):
    commune_field_name = 'communes_rurales_id'

    def get_queryset(self):
        qs = Piste.objects.all()
        return self.filter_queryset_by_rbac(qs)

    def get_serializer_class(self):
        # GET => serializer lecture (expose geom_4326)
        if self.request.method == 'GET':
            return PisteReadSerializer
        
        return PisteWriteSerializer

    def perform_create(self, serializer):
        super().perform_create(serializer)

class UserManagementAPIView(APIView):
    """API dédiée à la gestion des utilisateurs par le super_admin"""
    
    def post(self, request):
        """Créer un nouvel utilisateur avec commune"""
        print(f"🔍 Données reçues pour création utilisateur:", request.data)  # Ajout debug
        
        serializer = UserCreateSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.save()
            response_serializer = LoginSerializer(user)
            return Response(response_serializer.data, status=status.HTTP_201_CREATED)
        else:
            print(f"❌ Erreurs de validation:", serializer.errors)  # Ajout debug
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
    def get(self, request, user_id=None):
        """Lister tous les utilisateurs ou récupérer un utilisateur spécifique"""
        if user_id:
            try:
                user = Login.objects.select_related(
                    'communes_rurales_id',
                    'communes_rurales_id__prefectures_id',
                    'communes_rurales_id__prefectures_id__regions_id'
                ).get(id=user_id)
                serializer = LoginSerializer(user)
                return Response(serializer.data, status=status.HTTP_200_OK)
            except Login.DoesNotExist:
                return Response({"error": "Utilisateur non trouvé"}, status=status.HTTP_404_NOT_FOUND)
        else:
            queryset = Login.objects.select_related(
                'communes_rurales_id',
                'communes_rurales_id__prefectures_id',
                'communes_rurales_id__prefectures_id__regions_id'
            )
            
            role = request.GET.get('role')
            region_id = request.GET.get('region_id')
            prefecture_id = request.GET.get('prefecture_id')
            commune_id = request.GET.get('commune_id')
            
            if role:
                queryset = queryset.filter(role=role)
            if region_id:
                queryset = queryset.filter(communes_rurales_id__prefectures_id__regions_id=region_id)
            if prefecture_id:
                queryset = queryset.filter(communes_rurales_id__prefectures_id=prefecture_id)
            if commune_id:
                queryset = queryset.filter(communes_rurales_id=commune_id)
            
            serializer = LoginSerializer(queryset, many=True)
            return Response({
                'users': serializer.data,
                'total': queryset.count()
            }, status=status.HTTP_200_OK)
    
    def put(self, request, user_id=None):
        """Modifier un utilisateur existant"""
        print(f"🔍 PUT /api/users/{user_id}/ - Données reçues:", request.data)
        
        if not user_id:
            return Response({"error": "ID utilisateur requis"}, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            user = Login.objects.get(id=user_id)
            print(f"✅ Utilisateur trouvé: {user.nom} {user.prenom}")
        except Login.DoesNotExist:
            print(f"❌ Utilisateur {user_id} non trouvé")
            return Response({"error": "Utilisateur non trouvé"}, status=status.HTTP_404_NOT_FOUND)
        
        serializer = UserUpdateSerializer(user, data=request.data, partial=True)
        if serializer.is_valid():
            print("✅ Serializer valide")
            serializer.save()
            user.refresh_from_db()
            response_serializer = LoginSerializer(user)
            return Response(response_serializer.data, status=status.HTTP_200_OK)
        else:
            print(f"❌ Erreurs de validation: {serializer.errors}")
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
    def delete(self, request, user_id=None):
        """Supprimer un utilisateur"""
        if not user_id:
            return Response({"error": "ID utilisateur requis"}, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            user = Login.objects.get(id=user_id)
            user_info = f"{user.nom} {user.prenom}"
            user.delete()
            return Response({
                "message": f"Utilisateur {user_info} supprimé avec succès"
            }, status=status.HTTP_200_OK)
        except Login.DoesNotExist:
            return Response({"error": "Utilisateur non trouvé"}, status=status.HTTP_404_NOT_FOUND)