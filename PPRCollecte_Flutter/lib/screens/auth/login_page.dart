import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:async';
import 'dart:io';
import '../home/home_page.dart';
import '../../data/local/database_helper.dart';
import '../../data/remote/api_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  static const Duration _probeTimeout = Duration(milliseconds: 900);
  static const Duration _loginTimeout = Duration(seconds: 5);
  bool rememberMe = false;
  bool _obscurePwd = true;
  bool _isLoading = false;
  Future<bool> _isApiReachable() async {
    try {
      final uri = Uri.parse(ApiService.baseUrl); // ex: http://10.0.2.2:8000
      final host = uri.host;
      final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
      final socket = await Socket.connect(host, port, timeout: _probeTimeout);
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadRememberedUser();
  }

  Future<void> _loadRememberedUser() async {
    final db = DatabaseHelper();
    final email = await db.getCurrentUserEmail(); // ➜ retourne NULL si non “remembered”

    if (email != null && email.isNotEmpty) {
      final user = await db.getCurrentUser();
      if (user != null) {
        setState(() {
          emailController.text = user['email'] ?? '';
          passwordController.text = user['password'] ?? '';
          rememberMe = true;
        });
      }
    } else {
      setState(() {
        rememberMe = false;
        emailController.clear();
        passwordController.clear();
      });
    }
  }

  Future<void> _loginOffline(String email, String password) async {
    final isValidLocal = await DatabaseHelper().validateUser(email, password);
    if (isValidLocal) {
      // ✅ Gérer la case "Se souvenir" même hors-ligne
      await DatabaseHelper().setCurrentUserEmail(email, remember: rememberMe);

      final fullName = await DatabaseHelper().getAgentFullName(email) ?? 'Utilisateur Local';

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(
            agentName: fullName,
            isOnline: false,
            onLogout: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
          ),
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Mode hors-ligne : identifiants introuvables localement.",
          ),
        ),
      );
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final email = emailController.text.trim();
    final password = passwordController.text;

    setState(() => _isLoading = true);

    try {
      // (A) Serveur disponible ? (réponse <1s). Sinon, OFFLINE direct.
      final apiUp = await _isApiReachable();
      if (!apiUp) {
        await _loginOffline(email, password);
        return;
      }

      // (B) API dispo → tente /login avec timeout court
      final userData = await ApiService.login(email, password).timeout(_loginTimeout);

      // (C) Gestion du "Se souvenir" et mise à jour de la session
      await DatabaseHelper().setCurrentUserEmail(email, remember: rememberMe);

      final existingUser = await DatabaseHelper().userExists(email);
      final nom = userData['nom'] ?? '';
      final prenom = userData['prenom'] ?? '';
      final fullName = '$prenom $nom';
      final communeId = userData['communes_rurales'];
      final prefectureId = userData['prefecture_id'];
      final regionId = userData['region_id'];
      final communeNom = userData['commune_nom'];
      final prefectureNom = userData['prefecture_nom'];
      final regionNom = userData['region_nom'];
      final int? apiId = ApiService.userId;

      if (existingUser) {
        await DatabaseHelper().updateUser(
          prenom,
          nom,
          email,
          password,
          communeId,
          prefectureId,
          regionId,
          prefectureNom,
          communeNom,
          regionNom,
          role: userData['role'],
          apiId: apiId,
        );
      } else {
        await DatabaseHelper().insertUser(
          prenom,
          nom,
          email,
          password,
          communeId,
          prefectureId,
          regionId,
          prefectureNom,
          communeNom,
          regionNom,
          role: userData['role'],
          apiId: apiId,
        );
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(
            agentName: fullName,
            isOnline: true,
            onLogout: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
          ),
        ),
      );
    } on TimeoutException catch (_) {
      // API lente/bloquée → OFFLINE immédiat
      await _loginOffline(email, password);
    } on SocketException catch (_) {
      // Pas de réseau / serveur coupé → OFFLINE immédiat
      await _loginOffline(email, password);
    } catch (e) {
      // Erreur API "réelle" (ex: 401 mauvais mdp) → on affiche l'erreur
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _inputDeco({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
      prefixIcon: Icon(icon, color: const Color(0xFF64748B)),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF1F5F9), // gris clair
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF2563EB),
                Color(0xFF10B981)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 420),
                        margin: const EdgeInsets.symmetric(vertical: 24),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Logo + titre
                              Container(
                                width: 84,
                                height: 84,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFE0F2FE),
                                      Color(0xFFCCFBF1)
                                    ],
                                  ),
                                ),
                                child: const GuineeLoginEmblem(),
                              ),
                              const SizedBox(height: 10),
                              const Text("GeoDNGR-Collecte", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A))),
                              const SizedBox(height: 14),
                              const Text(
                                "Connexion à GeoDNGR-Collecte",
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 20),

                              // Email
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text("Adresse e-mail", style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: _inputDeco(hint: "exemple@domaine.com", icon: Icons.email_rounded),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return "Entrez votre e-mail";
                                  final ok = RegExp(r"^[^@]+@[^@]+\.[^@]+").hasMatch(v.trim());
                                  if (!ok) return "E-mail invalide";
                                  return null;
                                },
                              ),

                              const SizedBox(height: 14),

                              // Mot de passe
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text("Mot de passe", style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: passwordController,
                                obscureText: _obscurePwd,
                                decoration: _inputDeco(
                                  hint: "••••••••",
                                  icon: Icons.lock_rounded,
                                  suffix: IconButton(
                                    icon: Icon(_obscurePwd ? Icons.visibility_off : Icons.visibility),
                                    onPressed: () => setState(() => _obscurePwd = !_obscurePwd),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return "Entrez votre mot de passe";
                                  if (v.length < 4) return "Mot de passe trop court";
                                  return null;
                                },
                              ),

                              const SizedBox(height: 10),

                              // Remember + Forgot
                              Row(
                                children: [
                                  SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: Checkbox(
                                      value: rememberMe,
                                      onChanged: (val) {
                                        setState(() {
                                          rememberMe = val ?? false;
                                          if (!rememberMe) {
                                            emailController.clear();
                                            passwordController.clear();
                                          }
                                        });
                                      },
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text("Se souvenir", style: TextStyle(color: Color(0xFF334155))),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () {}, // TODO
                                    child: const Text("Mot de passe oublié ?"),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // Bouton connexion
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF38BDF8),
                                    foregroundColor: const Color(0xFF0F172A),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Text("Se connecter", style: TextStyle(fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class GuineeLoginEmblem extends StatelessWidget {
  const GuineeLoginEmblem({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        "assets/GeoNDGR_Collecte_Logo_FINAL.png",
        width: 104,
        height: 104,
        fit: BoxFit.contain,
      ),
    );
  }
}
