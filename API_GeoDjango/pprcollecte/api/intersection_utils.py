from django.db import connection
import json


def compute_intersections_for_piste(piste_id):
    """
    Calcule toutes les intersections d'une piste donnée avec les autres pistes
    existantes dans la BDD, puis met à jour ses champs.
    Retourne la liste des IDs des pistes impactées (pour mise à jour en cascade).
    """
    with connection.cursor() as cursor:
        # 1) Trouver toutes les pistes qui intersectent cette piste
        #    (ST_Intersects = true ET ST_Touches = false → croisement réel, pas juste un contact)
        cursor.execute("""
            SELECT 
                b.id AS other_id,
                b.code_piste AS other_code,
                ROUND(ST_X(
                    CASE 
                        WHEN GeometryType(ST_Intersection(a.geom, b.geom)) = 'POINT' 
                            THEN ST_Intersection(a.geom, b.geom)
                        WHEN GeometryType(ST_Intersection(a.geom, b.geom)) = 'MULTIPOINT' 
                            THEN ST_GeometryN(ST_Intersection(a.geom, b.geom), 1)
                        WHEN GeometryType(ST_Intersection(a.geom, b.geom)) IN ('LINESTRING', 'MULTILINESTRING') 
                            THEN ST_ClosestPoint(a.geom, b.geom)
                        WHEN GeometryType(ST_Intersection(a.geom, b.geom)) = 'GEOMETRYCOLLECTION' 
                            THEN ST_ClosestPoint(a.geom, b.geom)
                        ELSE ST_Centroid(ST_Intersection(a.geom, b.geom))
                    END
                )::numeric, 6) AS x,
                ROUND(ST_Y(
                    CASE 
                        WHEN GeometryType(ST_Intersection(a.geom, b.geom)) = 'POINT' 
                            THEN ST_Intersection(a.geom, b.geom)
                        WHEN GeometryType(ST_Intersection(a.geom, b.geom)) = 'MULTIPOINT' 
                            THEN ST_GeometryN(ST_Intersection(a.geom, b.geom), 1)
                        WHEN GeometryType(ST_Intersection(a.geom, b.geom)) IN ('LINESTRING', 'MULTILINESTRING') 
                            THEN ST_ClosestPoint(a.geom, b.geom)
                        WHEN GeometryType(ST_Intersection(a.geom, b.geom)) = 'GEOMETRYCOLLECTION' 
                            THEN ST_ClosestPoint(a.geom, b.geom)
                        ELSE ST_Centroid(ST_Intersection(a.geom, b.geom))
                    END
                )::numeric, 6) AS y
            FROM pistes a
            JOIN pistes b 
                ON a.id != b.id 
               AND ST_Intersects(a.geom, b.geom)
               AND NOT ST_Touches(a.geom, b.geom)
            WHERE a.id = %s
              AND a.geom IS NOT NULL
              AND b.geom IS NOT NULL
            ORDER BY b.code_piste
        """, [piste_id])

        rows = cursor.fetchall()

    # 2) Construire le JSON et les compteurs
    intersections = []
    impacted_ids = []
    for row in rows:
        other_id, other_code, x, y = row
        intersections.append({
            'piste_id': other_id,
            'code_piste': other_code or '',
            'x': float(x) if x is not None else None,
            'y': float(y) if y is not None else None,
        })
        impacted_ids.append(other_id)

    nombre = len(intersections)
    existence = nombre > 0

    # 3) Mettre à jour la piste courante
    with connection.cursor() as cursor:
        cursor.execute("""
            UPDATE pistes
            SET existence_intersection = %s,
                nombre_intersections = %s,
                intersections_json = %s::jsonb
            WHERE id = %s
        """, [existence, nombre, json.dumps(intersections), piste_id])

    return impacted_ids


def update_intersections_for_pistes(piste_ids):
    """
    Met à jour les intersections pour une liste de pistes.
    
    Gère le cas de synchronisation multiple :
    - Calcule les intersections de chaque piste avec TOUTES les autres (y compris 
      celles synchronisées dans le même batch)
    - Met aussi à jour les pistes existantes impactées
    
    Args:
        piste_ids: Liste des IDs de pistes nouvellement créées/synchronisées
    """
    if not piste_ids:
        return

    # Ensemble de TOUTES les pistes à recalculer
    all_ids_to_update = set(piste_ids)

    # Phase 1 : Calculer les intersections des nouvelles pistes
    #           et collecter les IDs des pistes existantes impactées
    for pid in piste_ids:
        impacted = compute_intersections_for_piste(pid)
        all_ids_to_update.update(impacted)

    # Phase 2 : Recalculer les pistes existantes qui ont été impactées
    #           (car elles ont maintenant de nouvelles intersections)
    existing_impacted = all_ids_to_update - set(piste_ids)
    for pid in existing_impacted:
        compute_intersections_for_piste(pid)

    print(f"✅ Intersections calculées pour {len(piste_ids)} nouvelle(s) piste(s), "
          f"{len(existing_impacted)} piste(s) existante(s) mise(s) à jour")
    
    #  NOUVEAU: Retourner les IDs impactés 
    return list(existing_impacted)