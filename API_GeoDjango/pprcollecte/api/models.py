from django.contrib.gis.db import models

class Login(models.Model):
    nom = models.TextField()
    prenom = models.TextField()
    mail = models.TextField(unique=True)
    mdp = models.TextField()
    role = models.TextField()
    
    # NOUVELLE LIGNE Ã€ AJOUTER :
    communes_rurales = models.ForeignKey(
    'CommuneRurale',
    on_delete=models.SET_NULL,
    null=True,
    blank=True,
    db_column='communes_rurales_id',
    related_name='utilisateurs'
)


    class Meta:
        db_table = 'login'
        managed = False

    def __str__(self):
        return f"{self.nom} {self.prenom} ({self.mail})"

    # NOUVELLES MÃ‰THODES Ã€ AJOUTER :
    @property
    def commune_complete(self):
        """Retourne les informations complÃ¨tes de localisation"""
        if not self.communes_rurales_id:
            return None
        
        commune = self.communes_rurales_id
        prefecture = commune.prefectures_id if commune.prefectures_id else None
        region = prefecture.regions_id if prefecture and prefecture.regions_id else None
        
        return {
            'commune': commune.nom,
            'commune_id': commune.id,
            'prefecture': prefecture.nom if prefecture else None,
            'prefecture_id': prefecture.id if prefecture else None,
            'region': region.nom if region else None,
            'region_id': region.id if region else None
        }


# ===== TABLES DE LIAISON UTILISATEUR ↔ TERRITOIRES =====

class UserRegion(models.Model):
    """Relation many-to-many : un BTGR peut avoir plusieurs régions"""
    login = models.ForeignKey(
        Login,
        on_delete=models.CASCADE,
        db_column='login_id',
        related_name='assigned_regions'
    )
    region = models.ForeignKey(
        'Region',
        on_delete=models.CASCADE,
        db_column='region_id',
        related_name='assigned_users'
    )
    created_at = models.DateTimeField(null=True, blank=True)
    created_by = models.IntegerField(null=True, blank=True)

    class Meta:
        db_table = 'user_regions'
        managed = False
        unique_together = ('login', 'region')

    def __str__(self):
        return f"{self.login} - Région {self.region_id}"


class UserPrefecture(models.Model):
    """Relation many-to-many : un SPGR peut avoir plusieurs préfectures"""
    login = models.ForeignKey(
        Login,
        on_delete=models.CASCADE,
        db_column='login_id',
        related_name='assigned_prefectures'
    )
    prefecture = models.ForeignKey(
        'Prefecture',
        on_delete=models.CASCADE,
        db_column='prefecture_id',
        related_name='assigned_users'
    )
    created_at = models.DateTimeField(null=True, blank=True)
    created_by = models.IntegerField(null=True, blank=True)

    class Meta:
        db_table = 'user_prefectures'
        managed = False
        unique_together = ('login', 'prefecture')

    def __str__(self):
        return f"{self.login} - Préfecture {self.prefecture_id}"

class Region(models.Model):
    nom = models.CharField(max_length=80, null=True, blank=True)
    geom = models.MultiPolygonField(srid=4326, null=True, blank=True)
    created_at = models.DateField(null=True, blank=True)
    updated_at = models.CharField(max_length=80, null=True, blank=True)

    class Meta:
        db_table = 'regions'
        managed = False

    def __str__(self):
        return self.nom


class Prefecture(models.Model):
    regions_id = models.ForeignKey(
        Region,
        db_column='regions_id',
        on_delete=models.CASCADE
    )    
    nom = models.CharField(max_length=80, null=True, blank=True)
    geom = models.MultiPolygonField(srid=4326, null=True, blank=True)
    created_at = models.DateField(null=True, blank=True)
    updated_at = models.CharField(max_length=80, null=True, blank=True)

    class Meta:
        db_table = 'prefectures'
        managed = False

    def __str__(self):
        return self.nom


class CommuneRurale(models.Model):
    prefectures_id = models.ForeignKey(
        Prefecture,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        db_column='prefectures_id'
    )
    nom = models.CharField(max_length=80, null=True, blank=True)
    geom = models.MultiPolygonField(srid=4326, null=True, blank=True)
    created_at = models.CharField(max_length=80, null=True, blank=True)
    updated_at = models.CharField(max_length=80, null=True, blank=True)

    class Meta:
        db_table = 'communes_rurales'
        managed = False

    def __str__(self):
        return self.nom
    
class Piste(models.Model):
    communes_rurales_id = models.ForeignKey(
        CommuneRurale, 
        on_delete=models.SET_NULL,
        null=True, 
        blank=True, 
        db_column='communes_rurales_id'
    )
    code_piste = models.CharField(max_length=50, unique=True, null=True, blank=True)  # texte
    geom = models.MultiLineStringField(srid=4326, null=True, blank=True)  # alignÃ© avec PostGIS
    heure_debut = models.TimeField(null=True, blank=True)  # time dans PostgreSQL
    heure_fin = models.TimeField(null=True, blank=True)
    nom_origine_piste = models.TextField(null=True, blank=True)
    x_origine = models.FloatField(null=True, blank=True)
    y_origine = models.FloatField(null=True, blank=True)
    nom_destination_piste = models.TextField(null=True, blank=True)
    x_destination = models.FloatField(null=True, blank=True)
    y_destination = models.FloatField(null=True, blank=True)
    existence_intersection = models.IntegerField(null=True, blank=True)
    x_intersection = models.FloatField(null=True, blank=True)
    y_intersection = models.FloatField(null=True, blank=True)
    type_occupation = models.TextField(null=True, blank=True)
    debut_occupation = models.DateTimeField(null=True, blank=True)
    fin_occupation = models.DateTimeField(null=True, blank=True)
    largeur_emprise = models.FloatField(null=True, blank=True)
    frequence_trafic = models.CharField(max_length=50, null=True, blank=True)  # texte
    type_trafic = models.TextField(null=True, blank=True)
    travaux_realises = models.TextField(null=True, blank=True)
    date_travaux = models.TextField(null=True, blank=True)
    entreprise = models.TextField(null=True, blank=True)
    
    # Nouveaux champs
    plateforme = models.TextField(null=True, blank=True)
    relief = models.TextField(null=True, blank=True)
    vegetation = models.TextField(null=True, blank=True)
    debut_travaux = models.TextField(null=True, blank=True)
    fin_travaux = models.TextField(null=True, blank=True)
    financement = models.TextField(null=True, blank=True)
    projet = models.TextField(null=True, blank=True)
    # Nouveaux champs (Calcul NG)
    niveau_service = models.FloatField(null=True, blank=True)
    fonctionnalite = models.FloatField(null=True, blank=True)
    interet_socio_administratif = models.FloatField(null=True, blank=True)
    population_desservie = models.FloatField(null=True, blank=True)
    potentiel_agricole = models.FloatField(null=True, blank=True)
    cout_investissement = models.FloatField(null=True, blank=True)
    protection_environnement = models.FloatField(null=True, blank=True)
    note_globale = models.FloatField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True, null=True)
    updated_at = models.DateTimeField(auto_now=True, null=True)
    login_id = models.ForeignKey(
        'Login', 
        on_delete=models.SET_NULL,
        null=True,
        blank=True, 
        db_column='login_id'
    )

    class Meta:
        db_table = 'pistes'
        managed = True

    def save(self, *args, **kwargs):
        # Calcul automatique de la Note Globale (NG)
        # NG = 0.05*NS + 0.05*FO + 0.15*ISA + 0.20*P + 0.30*PA + 0.20*CI + 0.05*PE
        ns = self.niveau_service or 0
        fo = self.fonctionnalite or 0
        isa = self.interet_socio_administratif or 0
        p = self.population_desservie or 0
        pa = self.potentiel_agricole or 0
        ci = self.cout_investissement or 0
        pe = self.protection_environnement or 0

        self.note_globale = (
            0.05 * ns +
            0.05 * fo +
            0.15 * isa +
            0.20 * p +
            0.30 * pa +
            0.20 * ci +
            0.05 * pe
        )
        super(Piste, self).save(*args, **kwargs)

    def __str__(self):
        return f"Piste {self.code_piste} - {self.nom_origine_piste} â†’ {self.nom_destination_piste}"



class Chaussees(models.Model):
    fid = models.BigAutoField(primary_key=True, db_column='fid')
    geom = models.MultiLineStringField(srid=4326, null=True, blank=True)
    id = models.BigIntegerField(null=True, blank=True, db_column='id')

    x_debut_ch = models.FloatField(null=True, blank=True)
    y_fin_chau = models.FloatField(null=True, blank=True)
    type_chaus = models.CharField(max_length=254, null=True, blank=True)
    etat_piste = models.CharField(max_length=254, null=True, blank=True)
    created_at = models.CharField(max_length=50, null=True, blank=True)
    updated_at = models.CharField(max_length=50, null=True, blank=True)
    code_gps = models.CharField(max_length=254, null=True, blank=True)
    endroit = models.CharField(max_length=32, null=True, blank=True)

    
    code_piste = models.ForeignKey(
        'Piste',
        to_field='code_piste',
        db_column='code_piste',
        on_delete=models.CASCADE,
        related_name='chaussees'
    )

    login_id = models.ForeignKey(
        'Login',
        db_column='login_id',
        on_delete=models.SET_NULL,
        null=True, blank=True,
        related_name='chaussees'
    )

    y_debut_ch = models.FloatField(null=True, blank=True)
    x_fin_ch = models.FloatField(null=True, blank=True)

    communes_rurales_id = models.ForeignKey(
        'CommuneRurale',
        db_column='communes_rurales_id',
        on_delete=models.SET_NULL,
        null=True, blank=True,
        related_name='chaussees'
    )

    class Meta:
        db_table = 'chaussees'   
        managed = False          

    def __str__(self):
        return f"Chaussée {self.fid} ({self.code_piste_id})"




class PointsCoupures(models.Model):
    fid = models.BigAutoField(primary_key=True, db_column='fid')
    geom = models.PointField(srid=4326, null=True, blank=True)
    sqlite_id = models.BigIntegerField(null=True, blank=True, db_column='id')

    cause_coup = models.CharField(max_length=50, null=True, blank=True)
    x_point_co = models.FloatField(null=True, blank=True)
    y_point_co = models.FloatField(null=True, blank=True)

    chaussee_id = models.BigIntegerField(null=True, blank=True, db_column='chaussee_id')

    created_at = models.CharField(max_length=24, null=True, blank=True)
    updated_at = models.CharField(max_length=24, null=True, blank=True)
    code_gps = models.CharField(max_length=254, null=True, blank=True)

    commune_id = models.ForeignKey(
        'CommuneRurale',
        db_column='commune_id',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='points_coupures'
    )

    
    login_id = models.ForeignKey(
        'Login',
        db_column='login_id',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='points_coupures'
    )

    class Meta:
        db_table = 'points_coupures'
        managed = False

    def __str__(self):
        return f"Point coupure {self.fid}"



class PointsCritiques(models.Model):
    fid = models.BigAutoField(primary_key=True, db_column='fid')
    geom = models.PointField(srid=4326, null=True, blank=True)
    sqlite_id = models.BigIntegerField(null=True, blank=True, db_column='id')

    type_point = models.CharField(max_length=50, null=True, blank=True)
    x_point_cr = models.FloatField(null=True, blank=True)
    y_point_cr = models.FloatField(null=True, blank=True)

    chaussee_id = models.BigIntegerField(null=True, blank=True, db_column='chaussee_id')

    created_at = models.CharField(max_length=24, null=True, blank=True)
    updated_at = models.CharField(max_length=24, null=True, blank=True)
    code_gps = models.CharField(max_length=254, null=True, blank=True)

    commune_id = models.ForeignKey(
        'CommuneRurale',
        db_column='commune_id',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='points_critiques'
    )

    
    login_id = models.ForeignKey(
        'Login',
        db_column='login_id',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='points_critiques'
    )

    class Meta:
        db_table = 'points_critiques'
        managed = False

    def __str__(self):
        return f"Point critique {self.fid}"



class ServicesSantes(models.Model):
    fid = models.BigAutoField(primary_key=True)
    geom = models.PointField(srid=4326)
    sqlite_id = models.IntegerField(null=True, blank=True, db_column='id')
    x_sante = models.FloatField(null=True, blank=True)
    y_sante = models.FloatField(null=True, blank=True)
    nom = models.CharField(max_length=254, null=True, blank=True)
    type = models.CharField(max_length=254, null=True, blank=True)
    date_creat = models.DateField(null=True, blank=True)
    created_at = models.CharField(max_length=24, null=True, blank=True)
    updated_at = models.CharField(max_length=24, null=True, blank=True)
    code_gps = models.CharField(max_length=254, null=True, blank=True)
    code_piste = models.ForeignKey(
    Piste,
    to_field='code_piste',
    on_delete=models.SET_NULL,
    null=True,
    blank=True,
    db_column='code_piste'
)

    login_id = models.ForeignKey(
    Login,
    on_delete=models.SET_NULL,
    null=True,
    blank=True,
    db_column='login_id'
)
    commune_id = models.ForeignKey(
        CommuneRurale,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        db_column='commune_id',
        related_name='services_santes'
    )



    class Meta:
        db_table = 'services_santes'
        managed = False

    def __str__(self):
        return f"{self.nom} ({self.fid})"


class AutresInfrastructures(models.Model):
    fid = models.BigAutoField(primary_key=True)
    geom = models.PointField(srid=4326)
    sqlite_id = models.IntegerField(null=True, blank=True, db_column='id')
    x_autre_in = models.FloatField(null=True, blank=True)
    y_autre_in = models.FloatField(null=True, blank=True)
    type = models.CharField(max_length=254, null=True, blank=True)
    date_creat = models.DateField(null=True, blank=True)
    created_at = models.CharField(max_length=24, null=True, blank=True)
    updated_at = models.CharField(max_length=24, null=True, blank=True)
    code_gps = models.CharField(max_length=254, null=True, blank=True)
    code_piste = models.ForeignKey(
    Piste,
    to_field='code_piste',
    on_delete=models.SET_NULL,
    null=True,
    blank=True,
    db_column='code_piste'
)

    login_id = models.ForeignKey(
    Login,
    on_delete=models.SET_NULL,
    null=True,
    blank=True,
    db_column='login_id'
)
    commune_id = models.ForeignKey(
        CommuneRurale,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        db_column='commune_id',
        related_name='autres_infrastructures'
    )



    class Meta:
        db_table = 'autres_infrastructures'
        managed = False

    def __str__(self):
        return f"Autre infrastructure ({self.fid})"


class Bacs(models.Model):
    fid = models.BigAutoField(primary_key=True)
    geom = models.GeometryField(srid=4326)
    sqlite_id = models.IntegerField(null=True, blank=True, db_column='id')
    x_debut_tr = models.FloatField(null=True, blank=True)
    y_debut_tr = models.FloatField(null=True, blank=True)
    x_fin_trav = models.FloatField(null=True, blank=True)
    y_fin_trav = models.FloatField(null=True, blank=True)
    type_bac = models.CharField(max_length=254, null=True, blank=True)
    nom_cours = models.CharField(max_length=254, null=True, blank=True, db_column='nom_cours_')
    created_at = models.CharField(max_length=24, null=True, blank=True)
    updated_at = models.CharField(max_length=24, null=True, blank=True)
    code_gps = models.CharField(max_length=254, null=True, blank=True)
    endroit = models.CharField(max_length=254, null=True, blank=True)
    code_piste = models.ForeignKey(
    Piste,
    to_field='code_piste',
    on_delete=models.SET_NULL,
    null=True,
    blank=True,
    db_column='code_piste'
)

    login_id = models.ForeignKey(
    Login,
    on_delete=models.SET_NULL,
    null=True,
    blank=True,
    db_column='login_id'
)
    commune_id = models.ForeignKey(
        CommuneRurale,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        db_column='commune_id',
        related_name='bacs'
    )



    class Meta:
        db_table = 'bacs'
        managed = False

    def __str__(self):
        return f"Bac {self.fid}"


class BatimentsAdministratifs(models.Model):
    fid = models.BigAutoField(primary_key=True)
    geom = models.PointField(srid=4326)
    sqlite_id = models.IntegerField(null=True, blank=True, db_column='id')
    x_batiment = models.FloatField(null=True, blank=True)
    y_batiment = models.FloatField(null=True, blank=True)
    nom = models.CharField(max_length=254, null=True, blank=True)
    type = models.CharField(max_length=254, null=True, blank=True)
    date_creat = models.DateField(null=True, blank=True)
    created_at = models.CharField(max_length=24, null=True, blank=True)
    updated_at = models.CharField(max_length=24, null=True, blank=True)
    code_gps = models.CharField(max_length=254, null=True, blank=True)
    code_piste = models.ForeignKey(
    Piste,
    to_field='code_piste',
    on_delete=models.SET_NULL,
    null=True,
    blank=True,
    db_column='code_piste'
)

    login_id = models.ForeignKey(
    Login,
    on_delete=models.SET_NULL,
    null=True,
    blank=True,
    db_column='login_id'
)
    commune_id = models.ForeignKey(
        CommuneRurale,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        db_column='commune_id',
        related_name='batiments_administratifs'
    )



    class Meta:
        db_table = 'batiments_administratifs'
        managed = False

    def __str__(self):
        return f"{self.nom} ({self.fid})"


class Buses(models.Model):
    fid = models.BigAutoField(primary_key=True)
    geom = models.PointField(srid=4326)
    sqlite_id = models.IntegerField(null=True, blank=True, db_column='id')
    x_buse = models.FloatField(null=True, blank=True)
    y_buse = models.FloatField(null=True, blank=True)
    created_at = models.CharField(max_length=24, null=True, blank=True)
    updated_at = models.CharField(max_length=24, null=True, blank=True)
    code_gps = models.CharField(max_length=254, null=True, blank=True)
    code_piste = models.ForeignKey(
    Piste,
    to_field='code_piste',
    on_delete=models.SET_NULL,
    null=True,
    blank=True,
    db_column='code_piste'
)

    login_id = models.ForeignKey(
    Login,
    on_delete=models.SET_NULL,
    null=True,
    blank=True,
    db_column='login_id'
)
    commune_id = models.ForeignKey(
        CommuneRurale,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        db_column='commune_id',
        related_name='buses'
    )



    class Meta:
        db_table = 'buses'
        managed = False

    def __str__(self):
        return f"Buse {self.fid}"


class Dalots(models.Model):
    fid = models.BigAutoField(primary_key=True)
    geom = models.PointField(srid=4326)
    sqlite_id = models.IntegerField(null=True, blank=True, db_column='id')
    x_dalot = models.FloatField(null=True, blank=True)
    y_dalot = models.FloatField(null=True, blank=True)
    situation = models.CharField(max_length=254, null=True, blank=True, db_column='situation_')
    created_at = models.CharField(max_length=24, null=True, blank=True)
    updated_at = models.CharField(max_length=24, null=True, blank=True)
    code_gps = models.CharField(max_length=254, null=True, blank=True)
    code_piste = models.ForeignKey(
    Piste,
    to_field='code_piste',
    on_delete=models.SET_NULL,
    null=True,
    blank=True,
    db_column='code_piste'
)

    login_id = models.ForeignKey(
    Login,
    on_delete=models.SET_NULL,
    null=True,
    blank=True,
    db_column='login_id'
)
    commune_id = models.ForeignKey(
        CommuneRurale,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        db_column='commune_id',
        related_name='dalots'
    )



    class Meta:
        db_table = 'dalots'
        managed = False

    def __str__(self):
        return f"Dalot {self.fid}"


class Ecoles(models.Model):
    fid = models.BigAutoField(primary_key=True)
    geom = models.PointField(srid=4326)
    sqlite_id = models.IntegerField(null=True, blank=True, db_column='id')
    x_ecole = models.FloatField(null=True, blank=True)
    y_ecole = models.FloatField(null=True, blank=True)
    nom = models.CharField(max_length=254, null=True, blank=True)
    type = models.CharField(max_length=254, null=True, blank=True)
    date_creat = models.DateField(null=True, blank=True)
    created_at = models.CharField(max_length=24, null=True, blank=True)
    updated_at = models.CharField(max_length=24, null=True, blank=True)
    code_gps = models.CharField(max_length=254, null=True, blank=True)
    code_piste = models.ForeignKey(
    Piste,
    to_field='code_piste',
    on_delete=models.SET_NULL,
    null=True,
    blank=True,
    db_column='code_piste'
)

    login_id = models.ForeignKey(
    Login,
    on_delete=models.SET_NULL,
    null=True,
    blank=True,
    db_column='login_id'
)
    commune_id = models.ForeignKey(
        CommuneRurale,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        db_column='commune_id',
        related_name='ecoles'
    )



    class Meta:
        db_table = 'ecoles'
        managed = False

    def __str__(self):
        return f"{self.nom} ({self.fid})"


class InfrastructuresHydrauliques(models.Model):
    fid = models.BigAutoField(primary_key=True)
    geom = models.PointField(srid=4326)
    sqlite_id = models.IntegerField(null=True, blank=True, db_column='id')
    x_infrastr = models.FloatField(null=True, blank=True)
    y_infrastr = models.FloatField(null=True, blank=True)
    nom = models.CharField(max_length=254, null=True, blank=True)
    type = models.CharField(max_length=254, null=True, blank=True)
    date_creat = models.DateField(null=True, blank=True)
    created_at = models.CharField(max_length=24, null=True, blank=True)
    updated_at = models.CharField(max_length=24, null=True, blank=True)
    code_gps = models.CharField(max_length=254, null=True, blank=True)
    code_piste = models.ForeignKey(
    Piste,
    to_field='code_piste',
    on_delete=models.SET_NULL,
    null=True,
    blank=True,
    db_column='code_piste'
)

    login_id = models.ForeignKey(
    Login,
    on_delete=models.SET_NULL,
    null=True,
    blank=True,
    db_column='login_id'
)
    commune_id = models.ForeignKey(
        CommuneRurale,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        db_column='commune_id',
        related_name='infrastructures_hydrauliques'
    )



    class Meta:
        db_table = 'infrastructures_hydrauliques'
        managed = False

    def __str__(self):
        return f"{self.nom} ({self.fid})"


class Localites(models.Model):
    fid = models.BigAutoField(primary_key=True)
    geom = models.PointField(srid=4326)
    sqlite_id = models.IntegerField(null=True, blank=True, db_column='id')
    x_localite = models.FloatField(null=True, blank=True)
    y_localite = models.FloatField(null=True, blank=True)
    nom = models.CharField(max_length=254, null=True, blank=True)
    type = models.CharField(max_length=254, null=True, blank=True)
    created_at = models.CharField(max_length=24, null=True, blank=True)
    updated_at = models.CharField(max_length=24, null=True, blank=True)
    code_gps = models.CharField(max_length=254, null=True, blank=True)
    code_piste = models.ForeignKey(
    Piste,
    to_field='code_piste',
    on_delete=models.SET_NULL,
    null=True,
    blank=True,
    db_column='code_piste'
)

    login_id = models.ForeignKey(
    Login,
    on_delete=models.SET_NULL,
    null=True,
    blank=True,
    db_column='login_id'
)
    commune_id = models.ForeignKey(
        CommuneRurale,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        db_column='commune_id',
        related_name='localites'
    )



    class Meta:
        db_table = 'localites'
        managed = False

    def __str__(self):
        return f"{self.nom} ({self.fid})"


class Marches(models.Model):
    fid = models.BigAutoField(primary_key=True)
    geom = models.PointField(srid=4326)
    sqlite_id = models.IntegerField(null=True, blank=True, db_column='id')
    x_marche = models.FloatField(null=True, blank=True)
    y_marche = models.FloatField(null=True, blank=True)
    nom = models.CharField(max_length=254, null=True, blank=True)
    type = models.CharField(max_length=254, null=True, blank=True)
    created_at = models.CharField(max_length=24, null=True, blank=True)
    updated_at = models.CharField(max_length=24, null=True, blank=True)
    code_gps = models.CharField(max_length=254, null=True, blank=True)
    code_piste = models.ForeignKey(
    Piste,
    to_field='code_piste',
    on_delete=models.SET_NULL,
    null=True,
    blank=True,
    db_column='code_piste'
)

    login_id = models.ForeignKey(
    Login,
    on_delete=models.SET_NULL,
    null=True,
    blank=True,
    db_column='login_id'
)
    commune_id = models.ForeignKey(
        CommuneRurale,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        db_column='commune_id',
        related_name='marches'
    )



    class Meta:
        db_table = 'marches'
        managed = False

    def __str__(self):
        return f"{self.nom} ({self.fid})"


class PassagesSubmersibles(models.Model):
    fid = models.BigAutoField(primary_key=True)
    geom = models.LineStringField(srid=4326)
    sqlite_id = models.IntegerField(null=True, blank=True, db_column='id')
    x_debut_pa = models.FloatField(null=True, blank=True)
    y_debut_pa = models.FloatField(null=True, blank=True)
    x_fin_pass = models.FloatField(null=True, blank=True)
    y_fin_pass = models.FloatField(null=True, blank=True)
    type_mater = models.CharField(max_length=254, null=True, blank=True)
    created_at = models.CharField(max_length=24, null=True, blank=True)
    updated_at = models.CharField(max_length=24, null=True, blank=True)
    code_gps = models.CharField(max_length=254, null=True, blank=True)
    endroit = models.CharField(max_length=32, null=True, blank=True)
    code_piste = models.ForeignKey(
    Piste,
    to_field='code_piste',
    on_delete=models.SET_NULL,
    null=True,
    blank=True,
    db_column='code_piste'
)

    login_id = models.ForeignKey(
    Login,
    on_delete=models.SET_NULL,
    null=True,
    blank=True,
    db_column='login_id'
)
    commune_id = models.ForeignKey(
        CommuneRurale,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        db_column='commune_id',
        related_name='passages_submersibles'
    )




    class Meta:
        db_table = 'passages_submersibles'
        managed = False

    def __str__(self):
        return f"Passage {self.fid}"


class Ponts(models.Model):
    fid = models.BigAutoField(primary_key=True)
    geom = models.PointField(srid=4326)
    sqlite_id = models.IntegerField(null=True, blank=True, db_column='id')
    x_pont = models.FloatField(null=True, blank=True)
    y_pont = models.FloatField(null=True, blank=True)
    situation = models.CharField(max_length=254, null=True, blank=True, db_column='situation_')
    type_pont = models.CharField(max_length=254, null=True, blank=True)
    nom_cours = models.CharField(max_length=254, null=True, blank=True, db_column='nom_cours_')
    created_at = models.CharField(max_length=24, null=True, blank=True)
    updated_at = models.CharField(max_length=24, null=True, blank=True)
    code_gps = models.CharField(max_length=254, null=True, blank=True)
    code_piste = models.ForeignKey(
    Piste,
    to_field='code_piste',
    on_delete=models.SET_NULL,
    null=True,
    blank=True,
    db_column='code_piste'
)

    login_id = models.ForeignKey(
    Login,
    on_delete=models.SET_NULL,
    null=True,
    blank=True,
    db_column='login_id'
)
    commune_id = models.ForeignKey(
        CommuneRurale,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        db_column='commune_id',
        related_name='ponts'
    )



    class Meta:
        db_table = 'ponts'
        managed = False

    def __str__(self):
        return f"Pont {self.fid} - {self.nom_cours or ''}"


class SiteEnquete(models.Model):
    fid = models.BigAutoField(primary_key=True)
    geom = models.PointField(srid=4326)
    sqlite_id = models.IntegerField(null=True, blank=True, db_column='id')
    x_site = models.FloatField(null=True, blank=True)
    y_site = models.FloatField(null=True, blank=True)
    nom = models.CharField(max_length=254, null=True, blank=True)
    type = models.CharField(max_length=254, null=True, blank=True)
    created_at = models.CharField(max_length=24, null=True, blank=True)
    updated_at = models.CharField(max_length=24, null=True, blank=True)
    code_gps = models.CharField(max_length=254, null=True, blank=True)
    # 9 champs ex-ppr_itial
    amenage_ou_non_amenage = models.BooleanField(null=True, blank=True)
    entreprise = models.TextField(null=True, blank=True)
    financement = models.TextField(null=True, blank=True)
    projet = models.TextField(null=True, blank=True)
    superficie_digitalisee = models.FloatField(null=True, blank=True)
    superficie_estimee_lors_des_enquetes_ha = models.FloatField(null=True, blank=True)
    travaux_debut = models.TextField(null=True, blank=True)
    travaux_fin = models.IntegerField(null=True, blank=True)
    type_de_realisation = models.TextField(null=True, blank=True)
    code_piste = models.ForeignKey(
        'Piste',
        to_field='code_piste',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        db_column='code_piste'
    )
    login_id = models.ForeignKey(
        'Login',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        db_column='login_id'
    )
    commune_id = models.ForeignKey(
        'CommuneRurale',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        db_column='commune_id',
        related_name='site_enquetes'
    )

    class Meta:
        db_table = 'site_enquete'
        managed = False

    def __str__(self):
        return f"{self.nom or 'Site Enquête'} ({self.fid})"


class EnquetePolygone(models.Model):
    fid = models.BigAutoField(primary_key=True)
    geom = models.PolygonField(srid=4326)
    sqlite_id = models.IntegerField(null=True, blank=True, db_column='id')
    nom = models.CharField(max_length=254, null=True, blank=True)
    created_at = models.CharField(max_length=24, null=True, blank=True)
    updated_at = models.CharField(max_length=24, null=True, blank=True)
    code_piste = models.ForeignKey(
        'Piste',
        to_field='code_piste',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        db_column='code_piste'
    )
    login_id = models.ForeignKey(
        'Login',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        db_column='login_id'
    )
    commune_id = models.ForeignKey(
        'CommuneRurale',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        db_column='commune_id',
        related_name='enquete_polygones'
    )

    class Meta:
        db_table = 'enquete_polygone'
        managed = False

    def __str__(self):
        return f"Enquête Polygone {self.fid}"
