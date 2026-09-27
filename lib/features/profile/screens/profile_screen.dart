import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/controllers/auth_controller.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthController>(context);
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Meu Perfil'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 46,
                  backgroundColor: AppColors.surfaceLight,
                  backgroundImage: NetworkImage(
                    user?.avatarUrl ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: AppColors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              user?.fullName ?? 'Carlos Mendes',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.black),
            ),
          ),
          Center(
            child: Text(
              user?.email ?? 'carlos@velixgo.com.br',
              style: const TextStyle(fontSize: 14, color: AppColors.grey),
            ),
          ),
          const SizedBox(height: 24),

          // Informações da Conta
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_outlined, color: AppColors.blue),
                  title: const Text('Tipo de Conta'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.blue.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Passageiro',
                      style: TextStyle(
                        color: AppColors.blue,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.phone_outlined, color: AppColors.grey),
                  title: const Text('Telefone'),
                  trailing: Text(
                    user?.phone.isNotEmpty == true ? user!.phone : '(11) 98765-4321',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Informações do App e Suporte
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.security, color: AppColors.green),
                  title: const Text('Segurança e Termos'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.help_outline, color: AppColors.blue),
                  title: const Text('Ajuda e Suporte Velix'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          OutlinedButton.icon(
            onPressed: () async {
              await auth.logout();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
            icon: const Icon(Icons.logout, color: AppColors.red),
            label: const Text('Sair da Conta', style: TextStyle(color: AppColors.red)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.red),
            ),
          ),
        ],
      ),
    );
  }
}
