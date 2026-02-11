from django.db.models import Count, Q, Min, Max
from django.db.models.functions import TruncDate, TruncMonth, TruncYear, TruncWeek
from rest_framework.views import APIView
from rest_framework.response import Response
from datetime import datetime, timedelta, date
from django.utils import timezone
from django.db import connection
from .models import *
import re

class TemporalAnalysisAPIView(APIView):
    """
    API pour analyses temporelles - Version finale sans erreur ValidationError
    """
    
    def get(self, request):
        period_type = request.GET.get('period_type', 'month')
        types_param = request.GET.getlist('types', [])
        
        # Paramètres optionnels
        days_back = int(request.GET.get('days_back', 365))
        date_from = request.GET.get('date_from', '')
        date_to = request.GET.get('date_to', '')
        specific_year = request.GET.get('year', '')
        specific_month = request.GET.get('month', '')
        specific_day = request.GET.get('day', '')
        
        print(f"\n🔍 === ANALYSE TEMPORELLE FINALE ===")
        print(f"📋 Paramètres: period_type={period_type}, types={types_param}")
        
        try:
            # Configuration des modèles avec types corrigés
            models_config = self._get_models_config()
            
            # Si aucun type spécifié, utiliser tous les types disponibles
            if not types_param:
                types_param = list(models_config.keys())
                print(f"✅ Types utilisés (tous): {types_param}")
            else:
                # Mapper les types frontend vers backend
                types_param = self._map_frontend_types(types_param)
                print(f"✅ Types mappés: {types_param}")
            
            # Déterminer la plage de dates
            start_date, end_date = self._calculate_date_range(
                period_type, days_back, specific_year, specific_month, 
                specific_day, date_from, date_to
            )
            
            print(f"📅 Période d'analyse: {start_date.strftime('%Y-%m-%d')} → {end_date.strftime('%Y-%m-%d')}")
            
            # Fonction de troncature selon la période
            trunc_functions = {
                'day': TruncDate,
                'week': TruncWeek,
                'month': TruncMonth,
                'year': TruncYear
            }
            trunc_func = trunc_functions.get(period_type, TruncMonth)
            
            results = {}
            total_by_period = {}
            debug_details = {}
            
            # Analyser chaque type demandé
            for type_name in types_param:
                if type_name not in models_config:
                    print(f"⚠️ Type {type_name} non trouvé dans la config")
                    continue
                
                config = models_config[type_name]
                print(f"\n🔧 Configuration pour {type_name}:")
                print(f"  Model: {config['model'].__name__}")
                print(f"  Date field: {config['date_field']}")
                print(f"  Is VARCHAR: {config['is_varchar_date']}")
                
                try:
                    if config['is_varchar_date']:
                        # Pour les champs VARCHAR, utiliser uniquement SQL direct
                        type_results, debug_info = self._process_varchar_dates_sql_only(
                            config, type_name, start_date, end_date, period_type, total_by_period
                        )
                    else:
                        # Pour les vrais DateTime, utiliser l'ORM normalement
                        type_results, debug_info = self._process_datetime_dates_enhanced(
                            config, type_name, start_date, end_date, period_type, 
                            total_by_period, trunc_func
                        )
                    
                    debug_details[type_name] = debug_info
                    
                    if type_results:
                        results[type_name] = type_results
                        print(f"✅ {type_name}: {len(type_results)} périodes trouvées")
                    else:
                        print(f"⚠️ {type_name}: aucune donnée dans la période")
                
                except Exception as model_error:
                    print(f"❌ Erreur {type_name}: {model_error}")
                    debug_details[type_name] = {'error': str(model_error)}
                    continue
            
            # Calculer métriques globales
            all_counts = list(total_by_period.values())
            total_collectes = sum(all_counts)
            
            metrics = {
                'total_collectes': total_collectes,
                'moyenne_periode': round(total_collectes / max(len(all_counts), 1), 1),
                'pic_maximum': max(all_counts) if all_counts else 0,
                'pic_minimum': min(all_counts) if all_counts else 0,
                'nb_periodes': len(all_counts),
                'tendance': self._calculate_trend(all_counts)
            }
            
            print(f"🎯 Résultats finaux: {len(results)} types, {total_collectes} collectes total")
            
            return Response({
                'success': True,
                'data': results,
                'total_by_period': total_by_period,
                'metrics': metrics,
                'period_info': {
                    'type': period_type,
                    'days_back': days_back,
                    'start_date': start_date.strftime('%Y-%m-%d'),
                    'end_date': end_date.strftime('%Y-%m-%d'),
                    'total_types': len(results),
                    'specific_filters': {
                        'year': specific_year,
                        'month': specific_month,
                        'day': specific_day,
                        'date_from': date_from,
                        'date_to': date_to
                    }
                },
                'debug_details': debug_details
            })
            
        except Exception as e:
            print(f"💥 Erreur globale: {e}")
            import traceback
            traceback.print_exc()
            return Response({
                'success': False,
                'error': str(e),
                'debug': 'Erreur dans TemporalAnalysisAPIView finale'
            }, status=500)
    
    def _process_varchar_dates_sql_only(self, config, type_name, start_date, end_date, 
                                      period_type, total_by_period):
        """Traitement UNIQUEMENT SQL pour éviter l'ORM Django"""
        
        print(f"\n📊 Analyse {type_name.upper()} - VARCHAR (SQL SEUL)")
        
        model = config['model']
        date_field = config['date_field']
        id_field = config['id_field']
        table_name = model._meta.db_table
        
        # Requête SQL pure - AUCUN ORM
        raw_records = []
        
        try:
            with connection.cursor() as cursor:
                # Requête SQL directe avec filtrage strict
                sql = f"""
                SELECT {id_field}, {date_field}
                FROM {table_name}
                WHERE {date_field} IS NOT NULL 
                  AND {date_field} != ''
                  AND {date_field} != 'null'
                  AND LENGTH(TRIM({date_field})) > 10
                  AND {date_field} LIKE '20%%/%%/%%'
                ORDER BY {id_field}
                LIMIT 1000
                """
                
                print(f"  🔍 SQL: {sql}")
                cursor.execute(sql)
                raw_records = cursor.fetchall()
                
        except Exception as sql_error:
            print(f"  ❌ Erreur SQL: {sql_error}")
            return [], {'total_records': 0, 'valid_dates': 0, 'in_range_dates': 0, 'sql_error': str(sql_error)}
        
        total_records = len(raw_records)
        print(f"  📊 Enregistrements récupérés: {total_records}")
        
        if total_records == 0:
            return [], {'total_records': 0, 'valid_dates': 0, 'in_range_dates': 0}
        
        # Afficher exemples pour debug
        print(f"  📋 Exemples de dates:")
        for i, record in enumerate(raw_records[:3]):
            print(f"    {i+1}. ID={record[0]}, Date='{record[1]}'")
        
        # Parser manuellement chaque date
        period_counts = {}
        valid_count = 0
        in_range_count = 0
        
        start_date_only = start_date.date()
        end_date_only = end_date.date()
        
        for record in raw_records:
            record_id = record[0]
            date_str = record[1]
            
            if not date_str:
                continue
                
            date_str_clean = str(date_str).strip()
            if not date_str_clean or date_str_clean.lower() in ['null', 'none', '']:
                continue
            
            try:
                # Parsing pour format YYYY/MM/DD HH:MM:SS.mmm
                parsed_date = self._parse_varchar_date_robust(date_str_clean)
                
                if parsed_date:
                    valid_count += 1
                    
                    # Vérifier si dans la période demandée
                    if start_date_only <= parsed_date <= end_date_only:
                        in_range_count += 1
                        
                        # Calculer la clé de période
                        period_key = self._get_period_key(parsed_date, period_type)
                        period_counts[period_key] = period_counts.get(period_key, 0) + 1
                
            except Exception as e:
                continue
        
        print(f"  ✅ Dates valides: {valid_count}/{total_records}")
        print(f"  📅 Dans la période: {in_range_count}")
        print(f"  📊 Périodes trouvées: {len(period_counts)}")
        
        # Convertir en format attendu
        results = []
        for period_date, count in sorted(period_counts.items()):
            period_str = self._format_period(period_date, period_type)
            
            results.append({
                'period': period_str,
                'date': period_date.isoformat(),
                'count': count
            })
            
            # Ajouter au total global
            if period_str not in total_by_period:
                total_by_period[period_str] = 0
            total_by_period[period_str] += count
        
        debug_info = {
            'total_records': total_records,
            'valid_dates': valid_count,
            'in_range_dates': in_range_count,
            'periods_found': len(period_counts)
        }
        
        return results, debug_info
    
    def _get_models_config(self):
        """Configuration corrigée avec types réels des champs"""
        return {
            'pistes': {
                'model': Piste,
                'date_field': 'created_at',
                'id_field': 'id',
                'is_varchar_date': False  # timestamp without time zone
            },
            'services_santes': {
                'model': ServicesSantes,
                'date_field': 'created_at',
                'id_field': 'fid',
                'is_varchar_date': True   # character varying(24)
            },
            'ponts': {
                'model': Ponts,
                'date_field': 'created_at',
                'id_field': 'fid',
                'is_varchar_date': True   # character varying(24)
            },
            'buses': {
                'model': Buses,
                'date_field': 'created_at',
                'id_field': 'fid',
                'is_varchar_date': True   # character varying(24)
            },
            'dalots': {
                'model': Dalots,
                'date_field': 'created_at',
                'id_field': 'fid',
                'is_varchar_date': True   # character varying(24)
            },
            'ecoles': {
                'model': Ecoles,
                'date_field': 'created_at',
                'id_field': 'fid',
                'is_varchar_date': True   # character varying(24)
            },
            'localites': {
                'model': Localites,
                'date_field': 'created_at',
                'id_field': 'fid',
                'is_varchar_date': True   # character varying(24)
            },
            'marches': {
                'model': Marches,
                'date_field': 'created_at',
                'id_field': 'fid',
                'is_varchar_date': True   # character varying(24)
            },
            'batiments_administratifs': {
                'model': BatimentsAdministratifs,
                'date_field': 'created_at',
                'id_field': 'fid',
                'is_varchar_date': True   # character varying(24)
            },
            'infrastructures_hydrauliques': {
                'model': InfrastructuresHydrauliques,
                'date_field': 'created_at',
                'id_field': 'fid',
                'is_varchar_date': True   # character varying(24)
            },
            'bacs': {
                'model': Bacs,
                'date_field': 'created_at',
                'id_field': 'fid',
                'is_varchar_date': True   # character varying(24)
            },
            'passages_submersibles': {
                'model': PassagesSubmersibles,
                'date_field': 'created_at',
                'id_field': 'fid',
                'is_varchar_date': True   # character varying(24)
            },
            'autres_infrastructures': {
                'model': AutresInfrastructures,
                'date_field': 'created_at',
                'id_field': 'fid',
                'is_varchar_date': True   # character varying(24)
            }
        }
    
    def _map_frontend_types(self, frontend_types):
        """Mapper les types frontend vers backend"""
        type_mapping = {
            'pistes': 'pistes',
            'sante': 'services_santes',
            'services_santes': 'services_santes',
            'ponts': 'ponts',
            'buses': 'buses',
            'dalots': 'dalots',
            'ecoles': 'ecoles',
            'localites': 'localites',
            'marches': 'marches',
            'administratifs': 'batiments_administratifs',
            'batiments_administratifs': 'batiments_administratifs',
            'hydrauliques': 'infrastructures_hydrauliques',
            'infrastructures_hydrauliques': 'infrastructures_hydrauliques',
            'bacs': 'bacs',
            'passages': 'passages_submersibles',
            'passages_submersibles': 'passages_submersibles',
            'autres': 'autres_infrastructures',
            'autres_infrastructures': 'autres_infrastructures'
        }
        
        mapped_types = []
        for frontend_type in frontend_types:
            backend_type = type_mapping.get(frontend_type, frontend_type)
            if backend_type not in mapped_types:
                mapped_types.append(backend_type)
        
        return mapped_types
    
    def _calculate_date_range(self, period_type, days_back, specific_year, 
                            specific_month, specific_day, date_from, date_to):
        """Calculer la plage de dates selon les paramètres"""
        
        # Priorité 1: Période personnalisée avec date_from et date_to
        if date_from and date_to:
            try:
                start_date = timezone.make_aware(datetime.strptime(date_from, '%Y-%m-%d'))
                end_date = timezone.make_aware(datetime.strptime(date_to, '%Y-%m-%d'))
                return start_date, end_date
            except ValueError:
                pass
        
        # Priorité 2: Filtres spécifiques (année, mois, jour)
        now = timezone.now()
        
        if specific_year:
            try:
                year = int(specific_year)
                if specific_month:
                    month = int(specific_month)
                    if specific_day:
                        # Jour spécifique
                        day = int(specific_day)
                        start_date = timezone.make_aware(datetime(year, month, day))
                        end_date = start_date + timedelta(days=1)
                    else:
                        # Mois spécifique
                        start_date = timezone.make_aware(datetime(year, month, 1))
                        if month == 12:
                            end_date = timezone.make_aware(datetime(year + 1, 1, 1))
                        else:
                            end_date = timezone.make_aware(datetime(year, month + 1, 1))
                else:
                    # Année spécifique
                    start_date = timezone.make_aware(datetime(year, 1, 1))
                    end_date = timezone.make_aware(datetime(year + 1, 1, 1))
                
                return start_date, end_date
            except ValueError:
                pass
        
        # Priorité 3: Période par défaut (days_back)
        end_date = now
        start_date = end_date - timedelta(days=days_back)
        
        return start_date, end_date
    
    def _process_datetime_dates_enhanced(self, config, type_name, start_date, end_date, 
                                       period_type, total_by_period, trunc_func):
        """Traitement pour les champs DateTime natifs (table pistes)"""
        
        print(f"\n📊 Analyse {type_name.upper()} - DATETIME")
        
        model = config['model']
        date_field = config['date_field']
        id_field = config['id_field']
        
        # Compter total
        total_records = model.objects.filter(**{f"{date_field}__isnull": False}).count()
        
        # Filtrage par période
        queryset = model.objects.filter(**{
            f"{date_field}__isnull": False,
            f"{date_field}__gte": start_date,
            f"{date_field}__lte": end_date
        })
        
        in_range_count = queryset.count()
        
        # Agrégation temporelle
        temporal_data = queryset.annotate(
            period_truncated=trunc_func(date_field)
        ).values('period_truncated').annotate(
            count=Count(id_field)
        ).order_by('period_truncated')
        
        print(f"  📊 Total enregistrements: {total_records}")
        print(f"  📅 Dans la période: {in_range_count}")
        print(f"  📊 Périodes trouvées: {len(temporal_data)}")
        
        # Formater les résultats avec tri correct
        results = []
        for item in temporal_data:
            if item['period_truncated']:
                period_str = self._format_period(item['period_truncated'], period_type)
                count = item['count']
                
                results.append({
                    'period': period_str,
                    'date': item['period_truncated'].isoformat(),
                    'count': count,
                    'sort_key': item['period_truncated'].isoformat()  # Clé de tri ISO
                })
                
                # Ajouter au total global
                if period_str not in total_by_period:
                    total_by_period[period_str] = 0
                total_by_period[period_str] += count
        
        debug_info = {
            'total_records': total_records,
            'in_range_dates': in_range_count,
            'periods_found': len(temporal_data)
        }
        
        return results, debug_info
    
    def _parse_varchar_date_robust(self, date_str):
        """Parser robuste spécialement conçu pour le format YYYY/MM/DD HH:MM:SS.mmm"""
        if not date_str or date_str.strip() == '':
            return None
        
        try:
            date_str_clean = str(date_str).strip()
            
            # Format principal: YYYY/MM/DD HH:MM:SS.mmm
            # Exemple: "2025/02/28 21:49:55.000"
            if '/' in date_str_clean and ' ' in date_str_clean:
                date_part = date_str_clean.split(' ')[0]  # Prendre seulement la partie date
                
                parts = date_part.split('/')
                if len(parts) == 3:
                    year, month, day = int(parts[0]), int(parts[1]), int(parts[2])
                    
                    # Validation stricte
                    if self._is_valid_date(year, month, day):
                        return date(year, month, day)
            
            # Format alternatif: YYYY/MM/DD sans heure
            elif '/' in date_str_clean:
                parts = date_str_clean.split('/')
                if len(parts) == 3:
                    year, month, day = int(parts[0]), int(parts[1]), int(parts[2])
                    
                    if self._is_valid_date(year, month, day):
                        return date(year, month, day)
            
        except (ValueError, IndexError, AttributeError) as e:
            pass
        
        return None
    
    def _is_valid_date(self, year, month, day):
        """Vérifier si une date est valide et cohérente"""
        try:
            if not (2020 <= year <= 2030):  # Plage réaliste pour le projet
                return False
            if not (1 <= month <= 12):
                return False
            if not (1 <= day <= 31):
                return False
            
            # Test de création de date pour vérifier la validité
            date(year, month, day)
            return True
        except ValueError:
            return False
    
    def _get_period_key(self, parsed_date, period_type):
        """Calculer la clé de période pour un objet date"""
        if period_type == 'month':
            return parsed_date.replace(day=1)
        elif period_type == 'year':
            return parsed_date.replace(month=1, day=1)
        elif period_type == 'day':
            return parsed_date
        elif period_type == 'week':
            return parsed_date - timedelta(days=parsed_date.weekday())
        else:
            return parsed_date
    
    def _format_period(self, date_obj, period_type):
        """Formater la période selon le type - CORRIGÉ pour tri chronologique"""
        if period_type == 'day':
            return date_obj.strftime('%Y-%m-%d')  # Format ISO pour tri correct
        elif period_type == 'week':
            return f"Sem {date_obj.strftime('%U/%Y')}"
        elif period_type == 'month':
            return date_obj.strftime('%Y-%m')  # Format YYYY-MM pour tri correct
        elif period_type == 'year':
            return date_obj.strftime('%Y')
        return str(date_obj)
    
    def _calculate_trend(self, counts):
        """Calculer la tendance (évolution)"""
        if len(counts) < 2:
            return 0
            
        mid_point = len(counts) // 2
        first_half = counts[:mid_point]
        second_half = counts[mid_point:]
        
        avg_first = sum(first_half) / len(first_half) if first_half else 0
        avg_second = sum(second_half) / len(second_half) if second_half else 0
        
        if avg_first == 0:
            return 100 if avg_second > 0 else 0
            
        trend = ((avg_second - avg_first) / avg_first) * 100
        return round(trend, 1)