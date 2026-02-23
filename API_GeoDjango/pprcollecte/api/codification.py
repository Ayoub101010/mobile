import re
import unicodedata
from .models import Piste, CommuneRurale, Prefecture, Region



# ATTENTION: Certaines préfectures ont un BTGR différent de leur région BD.
# Ex: Guéckédou est en région BD "N'Zérékoré" (id=8) mais BTGR "G" (pas "N")
# Ex: Gaoual est en région BD "Boké" (id=1) mais région naturelle "4" (pas "1")

PREFECTURE_MAPPING = {
    # --- BTGR de Boké (B) ---
    'boffa':          ('02', 'B', '1'),
    'boke':           ('03', 'B', '1'),
    'boké':           ('03', 'B', '1'),
    'fria':           ('11', 'B', '1'),
    'gaoual':         ('12', 'B', '4'),   # BTGR Boké, mais région Moyenne-Guinée !
    'koundara':       ('19', 'B', '4'),   # BTGR Boké, mais région Moyenne-Guinée !

    # --- BTGR de Kindia (D) ---
    'coyah':          ('04', 'D', '1'),
    'dubreka':        ('08', 'D', '1'),
    'dubréka':        ('08', 'D', '1'),
    'forecariah':     ('10', 'D', '1'),
    'forécariah':     ('10', 'D', '1'),
    'kindia':         ('16', 'D', '1'),
    'telimele':       ('31', 'D', '4'),   # BTGR Kindia, mais région Moyenne-Guinée !
    'télimélé':       ('31', 'D', '4'),

    # --- BTGR de Faranah (F) ---
    'dabola':         ('05', 'F', '3'),
    'dinguiraye':     ('07', 'F', '3'),
    'faranah':        ('09', 'F', '3'),
    'kissidougou':    ('17', 'F', '2'),   # BTGR Faranah, région Forestière

    # --- BTGR de Kankan (K) ---
    'kankan':         ('14', 'K', '3'),
    'kerouane':       ('15', 'K', '3'),
    'kérouane':       ('15', 'K', '3'),
    'kouroussa':      ('20', 'K', '3'),
    'mandiana':       ('27', 'K', '3'),
    'siguiri':        ('30', 'K', '3'),

    # --- BTGR de Labé (L) ---
    'koubia':         ('18', 'L', '4'),
    'labe':           ('21', 'L', '4'),
    'labé':           ('21', 'L', '4'),
    'lelouma':        ('22', 'L', '4'),
    'lélouma':        ('22', 'L', '4'),
    'mali':           ('25', 'L', '4'),
    'tougue':         ('32', 'L', '4'),
    'tougué':         ('32', 'L', '4'),

    # --- BTGR de Mamou (M) ---
    'dalaba':         ('06', 'M', '4'),
    'mamou':          ('26', 'M', '4'),
    'pita':           ('29', 'M', '4'),

    # --- BTGR de Nzérékoré (N) ---
    'beyla':          ('01', 'N', '2'),
    'lola':           ('23', 'N', '2'),
    'nzerekore':      ('28', 'N', '2'),
    'nzérékoré':      ('28', 'N', '2'),
    "n'zérékoré":     ('28', 'N', '2'),
    'yomou':          ('33', 'N', '2'),

    # --- BTGR de Guéckédou (G) ---
    'gueckedou':      ('13', 'G', '2'),
    'guéckédou':      ('13', 'G', '2'),
    'macenta':        ('24', 'G', '2'),   # BTGR Guéckédou (PAS N'Zérékoré !)
}


# =====================================================================
# SECTION 2 : FONCTIONS UTILITAIRES
# =====================================================================

def normalize_name(name):
    """Normalise un nom : supprime les accents et met en minuscule."""
    if not name:
        return ''
    nfkd = unicodedata.normalize('NFKD', name)
    ascii_str = ''.join(c for c in nfkd if not unicodedata.combining(c))
    return ascii_str.lower().strip()


def get_prefecture_info(prefecture_obj):
    """
    Retourne (code_rapport, btgr_lettre, region_naturelle_chiffre)
    à partir d'un objet Prefecture Django.
    Cherche d'abord par nom exact, puis par nom normalisé.
    """
    if not prefecture_obj or not prefecture_obj.nom:
        return None

    nom = prefecture_obj.nom.strip().lower()

    # 1) Recherche directe
    if nom in PREFECTURE_MAPPING:
        return PREFECTURE_MAPPING[nom]

    # 2) Recherche normalisée (sans accents)
    nom_norm = normalize_name(prefecture_obj.nom)
    for key, value in PREFECTURE_MAPPING.items():
        if normalize_name(key) == nom_norm:
            return value

    # 3) Recherche partielle (contient / est contenu)
    for key, value in PREFECTURE_MAPPING.items():
        key_norm = normalize_name(key)
        if key_norm in nom_norm or nom_norm in key_norm:
            return value

    print(f"⚠️ Préfecture '{prefecture_obj.nom}' (id={prefecture_obj.id}) non trouvée dans PREFECTURE_MAPPING")
    return None


def get_commune_code(commune_obj):
    """
    Calcule le code CR (2 chiffres) de la commune dans sa préfecture.
    Les communes sont classées par ordre alphabétique dans leur préfecture.
    Retourne le rang alphabétique formaté sur 2 chiffres.
    """
    if not commune_obj or not commune_obj.prefectures_id:
        return None

    # Récupérer toutes les communes de la même préfecture, triées alphabetiquement
    communes_in_pref = CommuneRurale.objects.filter(
        prefectures_id=commune_obj.prefectures_id
    ).order_by('nom')

    # Trouver le rang de la commune actuelle
    for i, c in enumerate(communes_in_pref, start=1):
        if c.id == commune_obj.id:
            return f'{i:02d}'

    print(f"⚠️ Commune '{commune_obj.nom}' (id={commune_obj.id}) non trouvée dans sa préfecture")
    return None


def get_next_piste_number(commune_obj):
    """
    Calcule le prochain numéro de piste (P{xx}) dans une commune.
    Compte les pistes existantes dans cette commune et incrémente de 1.
    """
    if not commune_obj:
        return '01'

    # Compter les pistes existantes dans cette commune
    existing_count = Piste.objects.filter(
        communes_rurales_id=commune_obj
    ).count()

    next_num = existing_count + 1
    return f'{next_num:02d}'


# =====================================================================
# SECTION 3 : FONCTION PRINCIPALE DE GÉNÉRATION
# =====================================================================

def generate_official_code_piste(commune_obj, piste_instance=None):
    """
    Génère le code piste officiel au format du rapport de codification.
    Format: {RegionNaturelle}{BTGR}-{CodePrefecture}CR{CodeCommune}P{NumeroPiste}
    Exemple: 1B-02CR03P01

    Args:
        commune_obj: Instance de CommuneRurale
        piste_instance: (optionnel) Instance de Piste existante (pour réutiliser son numéro)

    Returns:
        str: Le code piste officiel, ou None si données insuffisantes
    """
    if not commune_obj:
        print('❌ generate_official_code_piste: commune_obj est None')
        return None

    prefecture = commune_obj.prefectures_id
    if not prefecture:
        print(f'❌ Commune {commune_obj.nom} (id={commune_obj.id}) n\'a pas de préfecture')
        return None

    # 1) Obtenir les infos de la préfecture (code, btgr, region naturelle)
    pref_info = get_prefecture_info(prefecture)
    if not pref_info:
        print(f'❌ Préfecture {prefecture.nom} non trouvée dans le mapping')
        return None

    code_prefecture, btgr_lettre, region_naturelle = pref_info

    # 2) Obtenir le code commune (rang alphabétique dans la préfecture)
    code_commune = get_commune_code(commune_obj)
    if not code_commune:
        print(f'❌ Impossible de calculer le code commune pour {commune_obj.nom}')
        return None

    # 3) Calculer le numéro de piste
    if piste_instance:
        # Vérifier si cette piste a déjà un numéro officiel
        old_code = piste_instance.code_piste or ''
        if is_official_code(old_code):
            # Extraire le numéro existant (ex: "1B-02CR03P05" -> "05")
            try:
                p_idx = old_code.rindex('P')
                existing_num = old_code[p_idx + 1:]
                if existing_num.isdigit():
                    numero_piste = f'{int(existing_num):02d}'
                else:
                    numero_piste = get_next_piste_number(commune_obj)
            except (ValueError, IndexError):
                numero_piste = get_next_piste_number(commune_obj)
        else:
            numero_piste = get_next_piste_number(commune_obj)
    else:
        numero_piste = get_next_piste_number(commune_obj)

    # 4) Assembler le code final
    official_code = f'{region_naturelle}{btgr_lettre}-{code_prefecture}CR{code_commune}P{numero_piste}'

    print(f'✅ Code officiel généré: {official_code} '
          f'(Commune={commune_obj.nom}, Préfecture={prefecture.nom})')

    return official_code


# =====================================================================
# SECTION 4 : FONCTIONS DE DÉTECTION DU TYPE DE CODE
# =====================================================================

def is_temporary_code(code_piste):
    """Vérifie si un code_piste est temporaire (venant du frontend)."""
    if not code_piste:
        return True
    return (
        code_piste.startswith('Piste_')
        or code_piste.startswith('TEMP_')
        or '_0_0_0_' in code_piste
    )


def is_official_code(code_piste):
    """
    Vérifie si un code_piste est déjà au format officiel.
    Exemples valides: 1B-02CR03P01, 2N-28CR05P10, 4D-31CR14P03
    """
    if not code_piste or len(code_piste) < 10:
        return False
    pattern = r'^[1-4][BDFGKLMN]-\d{2}CR\d{2}P\d{2,3}$'
    return bool(re.match(pattern, code_piste))


# =====================================================================
# SECTION 5 : MAPPING EN MÉMOIRE (ancien code temporaire → code officiel)
# =====================================================================
# Quand la piste est transformée de "Piste_0_0_0_20260223164931291" 
# vers "2N-28CR04P28", le timestamp disparaît du code.
# Ce dictionnaire garde la trace pour que les entités dépendantes
# (localités, ponts, buses...) puissent retrouver la piste.

_TEMP_TO_OFFICIAL = {}


def register_code_mapping(old_temp_code, new_official_code):
    """
    Enregistre le mapping ancien_code → nouveau_code.
    Appelé par _fix_code_piste() après la transformation.
    """
    if not old_temp_code or not new_official_code:
        return
    
    # Stocker avec le code complet
    _TEMP_TO_OFFICIAL[old_temp_code] = new_official_code
    
    # Stocker aussi avec le suffixe timestamp seul (pour recherche rapide)
    if '_' in old_temp_code:
        suffix = old_temp_code.split('_')[-1]
        _TEMP_TO_OFFICIAL[suffix] = new_official_code
    
    # Stocker aussi le suffixe après _0_0_0_ (ancien format)
    if '_0_0_0_' in old_temp_code:
        suffix_full = old_temp_code.split('_0_0_0_')[-1]
        _TEMP_TO_OFFICIAL[suffix_full] = new_official_code
    
    print(f"📝 Mapping enregistré: {old_temp_code} → {new_official_code}")


def resolve_temp_code(temp_code):
    """
    Cherche le code officiel à partir d'un code temporaire.
    Retourne le code officiel ou None.
    """
    if not temp_code:
        return None
    
    # 1) Recherche directe par code complet
    if temp_code in _TEMP_TO_OFFICIAL:
        return _TEMP_TO_OFFICIAL[temp_code]
    
    # 2) Recherche par suffixe timestamp
    if '_' in temp_code:
        suffix = temp_code.split('_')[-1]
        if suffix in _TEMP_TO_OFFICIAL:
            return _TEMP_TO_OFFICIAL[suffix]
    
    # 3) Recherche par suffixe après _0_0_0_
    if '_0_0_0_' in temp_code:
        suffix_full = temp_code.split('_0_0_0_')[-1]
        if suffix_full in _TEMP_TO_OFFICIAL:
            return _TEMP_TO_OFFICIAL[suffix_full]
    
    return None