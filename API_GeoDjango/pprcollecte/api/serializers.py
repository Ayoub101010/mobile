from rest_framework import serializers
from rest_framework_gis.serializers import GeoFeatureModelSerializer
from .models import Login
from .models import Piste
from .models import (
    ServicesSantes, AutresInfrastructures, Bacs, BatimentsAdministratifs,
    Buses, Dalots, Ecoles, InfrastructuresHydrauliques, Localites,
    Marches, PassagesSubmersibles, Ponts, CommuneRurale, Prefecture, Region, Chaussees, PointsCoupures, PointsCritiques,
    SiteEnquete, EnquetePolygone
)
from django.contrib.gis.geos import Point
from rest_framework_gis.fields import GeometryField
from django.contrib.gis.geos import GEOSGeometry
from django.contrib.gis.geos import LineString, MultiLineString

class CommuneInfoMixin(serializers.Serializer):
    """Ajoute les noms region/prefecture/commune en lecture seule
       dans la reponse API (GET). Aucun changement PostgreSQL."""
    commune_name = serializers.SerializerMethodField()
    prefecture_name = serializers.SerializerMethodField()
    region_name = serializers.SerializerMethodField()

    def _get_commune_obj(self, obj):
        commune = None
        if hasattr(obj, 'communes_rurales_id') and obj.communes_rurales_id:
            commune = obj.communes_rurales_id
        elif hasattr(obj, 'commune_id') and obj.commune_id:
            commune = obj.commune_id
        return commune

    def get_commune_name(self, obj):
        c = self._get_commune_obj(obj)
        return c.nom if c else None

    def get_prefecture_name(self, obj):
        c = self._get_commune_obj(obj)
        if c and hasattr(c, 'prefectures_id') and c.prefectures_id:
            return c.prefectures_id.nom
        return None

    def get_region_name(self, obj):
        c = self._get_commune_obj(obj)
        if c and hasattr(c, 'prefectures_id') and c.prefectures_id:
            pref = c.prefectures_id
            if hasattr(pref, 'regions_id') and pref.regions_id:
                return pref.regions_id.nom
        return None
    
class EnqueteurInfoMixin(serializers.Serializer):
    """Ajoute enqueteur_name = 'Prénom Nom' depuis login_id."""
    enqueteur_name = serializers.SerializerMethodField()

    def get_enqueteur_name(self, obj):
        try:
            # CAS 1 : login_id est un FK → obj.login_id est un objet Login
            login_obj = getattr(obj, 'login_id', None)
            if login_obj is None:
                return None
            
            # Si c'est déjà un objet Login (FK)
            if hasattr(login_obj, 'prenom') and hasattr(login_obj, 'nom'):
                return f"{login_obj.prenom} {login_obj.nom}".strip()
            
            # CAS 2 : login_id est un simple entier → requête BD
            login_id_value = None
            if isinstance(login_obj, int):
                login_id_value = login_obj
            elif hasattr(login_obj, 'pk'):
                login_id_value = login_obj.pk
            
            if login_id_value:
                user = Login.objects.filter(id=login_id_value).values('prenom', 'nom').first()
                if user:
                    return f"{user['prenom']} {user['nom']}".strip()
            
            return None
        except Exception:
            return None
 
class CodePisteResolveMixin:
    """
    Mixin pour résoudre le code_piste temporaire du frontend
    vers le code officiel déjà corrigé en BD, avant validation FK.
    
    Utilise d'abord le mapping en mémoire (rapide, même session sync),
    puis fallback sur recherche BD par suffixe timestamp.
    """

    def to_internal_value(self, data):
        from .codification import is_temporary_code, resolve_temp_code

        code_piste = data.get('code_piste')
        is_geojson = False

        if not code_piste and 'properties' in data:
            code_piste = (data.get('properties') or {}).get('code_piste')
            is_geojson = True

        if code_piste and isinstance(code_piste, str) and is_temporary_code(code_piste):
            
            resolved_code = None

            #  ÉTAPE 1 : Chercher dans le mapping en mémoire (rapide)
            official_code = resolve_temp_code(code_piste)
            if official_code:
                from .models import Piste
                matching = Piste.objects.filter(code_piste=official_code).first()
                if matching:
                    resolved_code = matching.code_piste
                    print(f"🔄 Résolu via mapping mémoire: {code_piste} → {resolved_code}")

            #  ÉTAPE 2 : Fallback - recherche BD par suffixe (ancien comportement)
            if not resolved_code:
                date_suffix = code_piste.split('_')[-1] if '_' in code_piste else code_piste
                from .models import Piste
                matching = Piste.objects.filter(
                    code_piste__endswith=date_suffix
                ).first()
                if matching:
                    resolved_code = matching.code_piste
                    print(f"🔄 Résolu via suffixe BD: {code_piste} → {resolved_code}")
            
            #  ÉTAPE 3 : Fallback _0_0_0_ (compatibilité ancien format)
            if not resolved_code and '_0_0_0_' in code_piste:
                full_suffix = code_piste.split('_0_0_0_')[-1]
                from .models import Piste
                matching = Piste.objects.filter(
                    code_piste__endswith=full_suffix
                ).first()
                if matching:
                    resolved_code = matching.code_piste
                    print(f"🔄 Résolu via suffixe _0_0_0_: {code_piste} → {resolved_code}")

            # Appliquer la résolution
            if resolved_code:
                data = data.copy() if hasattr(data, 'copy') else dict(data)
                if is_geojson:
                    props = dict(data['properties'])
                    props['code_piste'] = resolved_code
                    data['properties'] = props
                else:
                    data['code_piste'] = resolved_code
            else:
                print(f"⚠️ Impossible de résoudre code_piste: {code_piste}")

        return super().to_internal_value(data)
    
class RegionSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = Region
        geo_field = "geom"
        fields = '__all__'

class PrefectureSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = Prefecture
        geo_field = "geom"
        fields = '__all__'

class CommuneRuraleSerializer(GeoFeatureModelSerializer):
    # Ajouter ces lignes pour afficher les infos hiérarchiques
    prefecture_nom = serializers.CharField(source='prefectures_id.nom', read_only=True)
    prefecture_id = serializers.IntegerField(source='prefectures_id.id', read_only=True)
    region_nom = serializers.CharField(source='prefectures_id.regions_id.nom', read_only=True)
    region_id = serializers.IntegerField(source='prefectures_id.regions_id.id', read_only=True)
    localisation_complete = serializers.SerializerMethodField()
    
    class Meta:
        model = CommuneRurale
        geo_field = "geom"
        fields = '__all__'
    
    def get_localisation_complete(self, obj):
        """Format: Commune, Préfecture, Région"""
        prefecture = obj.prefectures_id.nom if obj.prefectures_id else "N/A"
        region = obj.prefectures_id.regions_id.nom if obj.prefectures_id and obj.prefectures_id.regions_id else "N/A"
        return f"{obj.nom}, {prefecture}, {region}"


class SiteEnqueteSerializer(CodePisteResolveMixin, CommuneInfoMixin, EnqueteurInfoMixin, GeoFeatureModelSerializer):
    travaux_debut = serializers.DateField(
        required=False,
        allow_null=True,
        input_formats=['%Y-%m-%d', 'iso-8601'],
    )
    travaux_fin = serializers.DateField(
        required=False,
        allow_null=True,
        input_formats=['%Y-%m-%d', 'iso-8601'],
    )

    class Meta:
        model = SiteEnquete
        geo_field = "geom"
        fields = '__all__'
        extra_kwargs = {
            'fid': {'required': False},
            'sqlite_id': {'required': False, 'allow_null': True},
        }
    
    def to_internal_value(self, data):
        for field in ['travaux_debut', 'travaux_fin']:
            val = data.get(field)
            if val is not None:
                val = str(val).strip()
                if val == '' or val == 'null' or val == 'None':
                    data[field] = None
                elif 'T' in val:
                    data[field] = val.split('T')[0]
                elif len(val) == 4 and val.isdigit():
                    data[field] = f"{val}-01-01"

        if 'x_site' in data and 'y_site' in data:
            x = float(data['x_site'])
            y = float(data['y_site'])
            data['geom'] = Point(x, y, srid=4326)
        return super().to_internal_value(data)

class EnquetePolygoneSerializer(CodePisteResolveMixin, CommuneInfoMixin, EnqueteurInfoMixin, GeoFeatureModelSerializer):
    class Meta:
        model = EnquetePolygone
        geo_field = "geom"
        fields = '__all__'
        extra_kwargs = {
            'id': {'required': False},
            'sqlite_id': {'required': False, 'allow_null': True},
        }

    def to_internal_value(self, data):
        """Convertir Polygon → MultiPolygon si nécessaire"""
        geom_data = data.get('geom')
        if geom_data and isinstance(geom_data, dict):
            if geom_data.get('type') == 'Polygon':
                # Convertir Polygon en MultiPolygon
                from django.contrib.gis.geos import GEOSGeometry, MultiPolygon
                import json
                polygon = GEOSGeometry(json.dumps(geom_data))
                data['geom'] = MultiPolygon(polygon, srid=4326)
            elif geom_data.get('type') == 'MultiPolygon':
                from django.contrib.gis.geos import GEOSGeometry
                import json
                data['geom'] = GEOSGeometry(json.dumps(geom_data))
        return super().to_internal_value(data)
    
class PointsCoupuresSerializer(CodePisteResolveMixin, CommuneInfoMixin, EnqueteurInfoMixin, GeoFeatureModelSerializer):
    class Meta:
        model = PointsCoupures
        geo_field = "geom"
        fields = '__all__'
        extra_kwargs = {
            'fid': {'required': False},         # auto-généré
            'sqlite_id': {'required': False, 'allow_null': True},
        }

    def to_internal_value(self, data):
        """
        Si le mobile envoie x_point_co / y_point_co,
        on génère automatiquement la géométrie.
        """
        if 'x_point_co' in data and 'y_point_co' in data and not data.get('geom'):
            x = float(data['x_point_co'])
            y = float(data['y_point_co'])
            data['geom'] = Point(x, y, srid=4326)
        return super().to_internal_value(data)


class PointsCritiquesSerializer(CodePisteResolveMixin, CommuneInfoMixin, EnqueteurInfoMixin, GeoFeatureModelSerializer):
    class Meta:
        model = PointsCritiques
        geo_field = "geom"
        fields = '__all__'
        extra_kwargs = {
            'fid': {'required': False},
            'sqlite_id': {'required': False, 'allow_null': True},
        }

    def to_internal_value(self, data):
        """
        Si le mobile envoie x_point_cr / y_point_cr,
        on génère automatiquement la géométrie.
        """
        if 'x_point_cr' in data and 'y_point_cr' in data and not data.get('geom'):
            x = float(data['x_point_cr'])
            y = float(data['y_point_cr'])
            data['geom'] = Point(x, y, srid=4326)
        return super().to_internal_value(data)



class ServicesSantesSerializer(CodePisteResolveMixin, CommuneInfoMixin, EnqueteurInfoMixin, GeoFeatureModelSerializer):
    class Meta:
        model = ServicesSantes
        geo_field = "geom"
        fields = '__all__'
        extra_kwargs = {
            'fid': {'required': False},      # Auto-généré
            'sqlite_id': {'required': False, 'allow_null': True},
        }
    
    def to_internal_value(self, data):
        # Conversion x_sante, y_sante → geom
        if 'x_sante' in data and 'y_sante' in data:
            x = float(data['x_sante'])
            y = float(data['y_sante'])
            data['geom'] = Point(x, y, srid=4326)
        return super().to_internal_value(data)

class AutresInfrastructuresSerializer(CodePisteResolveMixin, CommuneInfoMixin, EnqueteurInfoMixin, GeoFeatureModelSerializer):
    class Meta:
        model = AutresInfrastructures
        geo_field = "geom"
        fields = '__all__'
        extra_kwargs = {
            'fid': {'required': False},      # Auto-généré
            'sqlite_id': {'required': False, 'allow_null': True},
        }
    
    def to_internal_value(self, data):
        if 'x_autre_in' in data and 'y_autre_in' in data:
            x = float(data['x_autre_in'])
            y = float(data['y_autre_in'])
            data['geom'] = Point(x, y, srid=4326)
        return super().to_internal_value(data)

class BacsSerializer(CodePisteResolveMixin, CommuneInfoMixin, EnqueteurInfoMixin, GeoFeatureModelSerializer):
    class Meta:
        model = Bacs
        geo_field = "geom"
        fields = '__all__'
        extra_kwargs = {
            'fid': {'required': False},      # Auto-généré
            'sqlite_id': {'required': False, 'allow_null': True},
        }
    
    def to_internal_value(self, data):
    # Modifier cette partie dans BacsSerializer
        if ('x_debut_tr' in data and 'y_debut_tr' in data and 
            'x_fin_trav' in data and 'y_fin_trav' in data):
            
            x_debut = float(data['x_debut_tr'])
            y_debut = float(data['y_debut_tr'])
            x_fin = float(data['x_fin_trav'])
            y_fin = float(data['y_fin_trav'])
            
            # Créer une LineString au lieu d'un Point
            from django.contrib.gis.geos import LineString
            data['geom'] = LineString((x_debut, y_debut), (x_fin, y_fin), srid=4326)
            
        return super().to_internal_value(data)

class BatimentsAdministratifsSerializer(CodePisteResolveMixin, CommuneInfoMixin, EnqueteurInfoMixin, GeoFeatureModelSerializer):
    class Meta:
        model = BatimentsAdministratifs
        geo_field = "geom"
        fields = '__all__'
        extra_kwargs = {
            'fid': {'required': False},      # Auto-généré
            'sqlite_id': {'required': False, 'allow_null': True},
        }
    
    def to_internal_value(self, data):
        if 'x_batiment' in data and 'y_batiment' in data:
            x = float(data['x_batiment'])
            y = float(data['y_batiment'])
            data['geom'] = Point(x, y, srid=4326)
        return super().to_internal_value(data)

class BusesSerializer(CodePisteResolveMixin, CommuneInfoMixin, EnqueteurInfoMixin, GeoFeatureModelSerializer):
    class Meta:
        model = Buses
        geo_field = "geom"
        fields = '__all__'
        extra_kwargs = {
            'fid': {'required': False},      # Auto-généré
            'sqlite_id': {'required': False, 'allow_null': True},
        }
    
    def to_internal_value(self, data):
        if 'x_buse' in data and 'y_buse' in data:
            x = float(data['x_buse'])
            y = float(data['y_buse'])
            data['geom'] = Point(x, y, srid=4326)
        return super().to_internal_value(data)

class DalotsSerializer(CodePisteResolveMixin, CommuneInfoMixin, EnqueteurInfoMixin, GeoFeatureModelSerializer):
    class Meta:
        model = Dalots
        geo_field = "geom"
        fields = '__all__'
        extra_kwargs = {
            'fid': {'required': False},      # Auto-généré
            'sqlite_id': {'required': False, 'allow_null': True},
        }
    
    def to_internal_value(self, data):
        if 'x_dalot' in data and 'y_dalot' in data:
            x = float(data['x_dalot'])
            y = float(data['y_dalot'])
            data['geom'] = Point(x, y, srid=4326)
        return super().to_internal_value(data)

class EcolesSerializer(CodePisteResolveMixin, CommuneInfoMixin, EnqueteurInfoMixin, GeoFeatureModelSerializer):
    class Meta:
        model = Ecoles
        geo_field = "geom"
        fields = '__all__'
        extra_kwargs = {
            'fid': {'required': False},      # Auto-généré
            'sqlite_id': {'required': False, 'allow_null': True},
        }
    
    def to_internal_value(self, data):
        if 'x_ecole' in data and 'y_ecole' in data:
            x = float(data['x_ecole'])
            y = float(data['y_ecole'])
            data['geom'] = Point(x, y, srid=4326)
        return super().to_internal_value(data)

class InfrastructuresHydrauliquesSerializer(CodePisteResolveMixin, CommuneInfoMixin, EnqueteurInfoMixin, GeoFeatureModelSerializer):
    class Meta:
        model = InfrastructuresHydrauliques
        geo_field = "geom"
        fields = '__all__'
        extra_kwargs = {
            'fid': {'required': False},      # Auto-généré
            'sqlite_id': {'required': False, 'allow_null': True},
        }
    
    def to_internal_value(self, data):
        if 'x_infrastr' in data and 'y_infrastr' in data:
            x = float(data['x_infrastr'])
            y = float(data['y_infrastr'])
            data['geom'] = Point(x, y, srid=4326)
        return super().to_internal_value(data)

class LocalitesSerializer(CodePisteResolveMixin, CommuneInfoMixin, EnqueteurInfoMixin, GeoFeatureModelSerializer):
    class Meta:
        model = Localites
        geo_field = "geom"
        fields = '__all__'
        extra_kwargs = {
            'fid': {'required': False},      # Auto-généré
            'sqlite_id': {'required': False, 'allow_null': True},
        }
    
    def to_internal_value(self, data):
        
        if 'x_localite' in data and 'y_localite' in data:
            x = float(data['x_localite'])
            y = float(data['y_localite'])
            # Créer le Point géométrique
            data['geom'] = Point(x, y, srid=4326)
        
        return super().to_internal_value(data)

class MarchesSerializer(CodePisteResolveMixin, CommuneInfoMixin, EnqueteurInfoMixin, GeoFeatureModelSerializer):
    class Meta:
        model = Marches
        geo_field = "geom"
        fields = '__all__'
        extra_kwargs = {
            'fid': {'required': False},      # Auto-généré
            'sqlite_id': {'required': False, 'allow_null': True},
        }
    
    def to_internal_value(self, data):
        if 'x_marche' in data and 'y_marche' in data:
            x = float(data['x_marche'])
            y = float(data['y_marche'])
            data['geom'] = Point(x, y, srid=4326)
        return super().to_internal_value(data)

class PassagesSubmersiblesSerializer(CodePisteResolveMixin, CommuneInfoMixin, EnqueteurInfoMixin, GeoFeatureModelSerializer):
    class Meta:
        model = PassagesSubmersibles
        geo_field = "geom"
        fields = "__all__"
        extra_kwargs = {
            "fid": {"required": False},  # Auto-généré
            "sqlite_id": {"required": False, "allow_null": True},
        }

    def to_internal_value(self, data):
        if all(k in data for k in ("x_debut_pa", "y_debut_pa", "x_fin_pass", "y_fin_pass")):
            x_debut = float(data["x_debut_pa"])
            y_debut = float(data["y_debut_pa"])
            x_fin = float(data["x_fin_pass"])
            y_fin = float(data["y_fin_pass"])

            from django.contrib.gis.geos import LineString
            # ⚠️ ordre (lon, lat) → (y, x)
            data["geom"] = LineString((x_debut, y_debut), (x_fin, y_fin), srid=4326)

        return super().to_internal_value(data)

    
    

class PontsSerializer(CodePisteResolveMixin, CommuneInfoMixin, EnqueteurInfoMixin, GeoFeatureModelSerializer):
    class Meta:
        model = Ponts
        geo_field = "geom"
        fields = '__all__'
        extra_kwargs = {
            'fid': {'required': False},  # Auto-généré
            
        }
    
    def to_internal_value(self, data):
        if 'x_pont' in data and 'y_pont' in data:
            x = float(data['x_pont'])
            y = float(data['y_pont'])
            data['geom'] = Point(x, y, srid=4326)
        return super().to_internal_value(data)

class LoginSerializer(serializers.ModelSerializer):
    commune_complete = serializers.ReadOnlyField()
    commune_nom = serializers.CharField(source='communes_rurales.nom', read_only=True)
    prefecture_nom = serializers.CharField(source='communes_rurales.prefectures_id.nom', read_only=True)
    prefecture_id = serializers.IntegerField(source='communes_rurales.prefectures_id.id', read_only=True)
    region_nom = serializers.CharField(source='communes_rurales.prefectures_id.regions_id.nom', read_only=True)
    region_id = serializers.IntegerField(source='communes_rurales.prefectures_id.regions_id.id', read_only=True)

    communes_rurales = serializers.PrimaryKeyRelatedField(read_only=True)

    class Meta:
        model = Login
        fields = [
            'id', 'nom', 'prenom', 'mail', 'role', 'communes_rurales',
            'commune_complete', 'commune_nom', 'prefecture_nom', 'prefecture_id',
            'region_nom', 'region_id'
        ]




class PisteWriteSerializer(CommuneInfoMixin, GeoFeatureModelSerializer):
    # ✅ Accepter les dates ISO envoyées par Flutter
    debut_travaux = serializers.DateField(
        required=False,
        allow_null=True,
        input_formats=['%Y-%m-%d', 'iso-8601'],
    )
    fin_travaux = serializers.DateField(
        required=False,
        allow_null=True,
        input_formats=['%Y-%m-%d', 'iso-8601'],
    )

    class Meta:
        model = Piste
        geo_field = "geom"
        fields = "__all__"

    def to_internal_value(self, data):
        #  Nettoyer les dates — chercher AUSSI dans properties (format GeoJSON)
        targets = [data]
        if 'properties' in data and isinstance(data['properties'], dict):
            targets.append(data['properties'])

        for target in targets:
            for field in ['debut_travaux', 'fin_travaux']:
                val = target.get(field)
                if val is not None and isinstance(val, str):
                    val = val.strip()
                    if val == '' or val == 'null':
                        target[field] = None
                    elif 'T' in val:
                        # "2024-06-15T00:00:00.000" → "2024-06-15"
                        target[field] = val.split('T')[0]
                    elif len(val) == 4 and val.isdigit():
                        # "2024" → "2024-01-01"
                        target[field] = f"{val}-01-01"

        if 'geom' in data and data['geom'] is not None:
            geom = GEOSGeometry(str(data['geom']))
            geom.srid = 4326
            data['geom'] = geom
        return super().to_internal_value(data)

class ChausseesSerializer(CodePisteResolveMixin, CommuneInfoMixin, EnqueteurInfoMixin, GeoFeatureModelSerializer):
    code_piste = serializers.SlugRelatedField(
        slug_field='code_piste',
        queryset=Piste.objects.all(),
        required=False,
        allow_null=True,
    )
    class Meta:
        model = Chaussees
        geo_field = "geom"
        fields = "__all__"
        extra_kwargs = {
            'fid': {'required': False},
        }

    def to_internal_value(self, data):
        """
        Si le client envoie les 4 coords (x_debut_ch, y_debut_ch, x_fin_ch, y_fin_chau),
        on construit une MultiLineString 4326. Sinon, on prend 'geom' tel quel (GeoJSON).
        """
        if all(k in data for k in ("x_debut_ch", "y_debut_ch", "x_fin_ch", "y_fin_chau")) and not data.get("geom"):
            x1 = float(data["x_debut_ch"])
            y1 = float(data["y_debut_ch"])
            x2 = float(data["x_fin_ch"])
            y2 = float(data["y_fin_chau"])

            ls = LineString((x1, y1), (x2, y2), srid=4326)
            mls = MultiLineString(ls, srid=4326)
            data["geom"] = mls

        return super().to_internal_value(data)

# LECTURE : expose l'annotation 'geom_4326' comme géométrie principale
class PisteReadSerializer(CommuneInfoMixin,EnqueteurInfoMixin, GeoFeatureModelSerializer):
    class Meta:
        model = Piste
        geo_field = "geom"      # on expose directement geom (4326)
        fields = "__all__"      # pas besoin d'exclure geom


        
class UserCreateSerializer(serializers.ModelSerializer):
    """Serializer pour créer un nouvel utilisateur avec commune"""
    communes_rurales_id = serializers.PrimaryKeyRelatedField(
    queryset=CommuneRurale.objects.all(),
    required=False,
    allow_null=True
)

    
    class Meta:
        model = Login
        fields = ['nom', 'prenom', 'mail', 'mdp', 'role', 'communes_rurales_id']
    
    
    def validate_role(self, value):
        """Vérifier que le rôle est valide"""
        valid_roles = ['user', 'admin', 'super_admin']
        if value not in valid_roles:
            raise serializers.ValidationError(f"Rôle invalide. Valeurs autorisées : {valid_roles}")
        return value
    
    def validate_mail(self, value):
        """Vérifier que l'email est unique"""
        if Login.objects.filter(mail=value).exists():
            raise serializers.ValidationError("Cette adresse email est déjà utilisée.")
        return value

class UserUpdateSerializer(serializers.ModelSerializer):
    """Serializer pour modifier un utilisateur existant"""
    communes_rurales_id = serializers.IntegerField(required=False,allow_null=True)
    
    class Meta:
        model = Login
        fields = ['nom', 'prenom', 'mail', 'role', 'communes_rurales_id']
    
    def validate_communes_rurales_id(self, value):
        """Vérifier que la commune existe si fournie"""
        if value is not None:
            try:
                CommuneRurale.objects.get(id=value)
                return value
            except CommuneRurale.DoesNotExist:
                raise serializers.ValidationError("Cette commune n'existe pas.")
        return value
    
    def validate_mail(self, value):
        """Vérifier que l'email est unique lors de la modification"""
        # Récupérer l'instance en cours de modification
        instance = getattr(self, 'instance', None)
        
        # Si l'email est différent de l'actuel, vérifier l'unicité
        if instance and instance.mail != value:
            if Login.objects.filter(mail=value).exists():
                raise serializers.ValidationError("Cette adresse email est déjà utilisée.")
        
        return value
    
    def validate_role(self, value):
        """Vérifier que le rôle est valide"""
        valid_roles = ['user', 'admin', 'super_admin']
        if value and value not in valid_roles:
            raise serializers.ValidationError(f"Rôle invalide. Valeurs autorisées : {valid_roles}")
        return value

class CommuneSearchSerializer(serializers.ModelSerializer):
    """Serializer pour la recherche de communes avec infos complètes"""
    prefecture_nom = serializers.CharField(source='prefectures_id.nom', read_only=True)
    region_nom = serializers.CharField(source='prefectures_id.regions_id.nom', read_only=True)
    localisation_complete = serializers.SerializerMethodField()
    
    class Meta:
        model = CommuneRurale
        fields = ['id', 'nom', 'prefecture_nom', 'region_nom', 'localisation_complete']
    
    def get_localisation_complete(self, obj):
        """Format: Commune, Préfecture, Région"""
        prefecture = obj.prefectures_id.nom if obj.prefectures_id else "N/A"
        region = obj.prefectures_id.regions_id.nom if obj.prefectures_id and obj.prefectures_id.regions_id else "N/A"
        return f"{obj.nom}, {prefecture}, {region}"