import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Clé globale pour valider le formulaire
  final _formKey = GlobalKey<FormState>();
  
  // Contrôleurs pour les champs texte
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  
  // État local
  String? _selectedRole;
  bool _isLoading = false;

  // Méthode de nettoyage des contrôleurs
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // Fonction d'inscription
  Future<void> _signUp() async {
    // Déclenche les 'validator' de tous les champs du formulaire
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      // Appel à l'API avec le rôle sélectionné
      User newUser = await authService.register(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        name: _nameController.text.trim(),
        role: _selectedRole!, 
        phone: _phoneController.text.trim(),
      );

      // Sauvegarde locale
      await DatabaseService.instance.createUser(newUser);

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Inscription AgriSmart")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey, // Liaison avec la clé globale
            child: Column(
              children: [
                const SizedBox(height: 10),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: "Nom complet",
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v!.isEmpty ? "Entrez votre nom" : null,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v!.contains('@') ? null : "Email invalide",
                ),
                const SizedBox(height: 15),

                // --- Champ Dropdown Corrigé (Version Flutter 3.33+) ---
                DropdownButtonFormField<String>(
                  initialValue: _selectedRole, // Remplacement de 'value' par 'initialValue'
                  decoration: InputDecoration(
                    labelText: 'Votre Rôle',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'farmer', child: Text('🌾 Agriculteur')),
                    DropdownMenuItem(value: 'breeder', child: Text('🐄 Éleveur')),
                    DropdownMenuItem(value: 'vet', child: Text('🩺 Vétérinaire')),
                    DropdownMenuItem(value: 'agronomist', child: Text('🔬 Agronome')),
                    DropdownMenuItem(value: 'admin', child: Text('⚙️ Administrateur')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedRole = value;
                    });
                  },
                  validator: (value) => value == null ? 'Veuillez choisir un rôle' : null,
                ),
                // ---------------------------------------------------

                const SizedBox(height: 15),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: "Téléphone",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: "Mot de passe",
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (v) => v!.length < 6 ? "Minimum 6 caractères" : null,
                ),
                const SizedBox(height: 30),
                _isLoading
                    ? const CircularProgressIndicator()
                    : SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _signUp,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text("Créer mon compte"),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}