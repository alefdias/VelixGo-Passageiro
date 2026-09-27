import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class RatingDialog extends StatefulWidget {
  final String driverName;
  final String? vehicleInfo;
  final bool isAlreadyFavorite;
  final Function(int score, String? comment, bool addToFavorites) onSubmit;

  const RatingDialog({
    super.key,
    required this.driverName,
    this.vehicleInfo,
    this.isAlreadyFavorite = false,
    required this.onSubmit,
  });

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  int _score = 5;
  final _commentController = TextEditingController();
  late bool _addToFavorites;

  @override
  void initState() {
    super.initState();
    _addToFavorites = widget.isAlreadyFavorite;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.green.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              'Viagem Concluída!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Como foi sua experiência com ${widget.driverName}?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.grey),
            ),
            const SizedBox(height: 20),

            // 5 Estrelas
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starNumber = index + 1;
                return IconButton(
                  iconSize: 36,
                  icon: Icon(
                    starNumber <= _score ? Icons.star_rounded : Icons.star_border_rounded,
                    color: AppColors.yellow,
                  ),
                  onPressed: () {
                    setState(() {
                      _score = starNumber;
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 16),

            // Diferencial: Botão ❤️ Adicionar aos Favoritos
            InkWell(
              onTap: () {
                setState(() {
                  _addToFavorites = !_addToFavorites;
                });
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _addToFavorites ? const Color(0xFFFFECEF) : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _addToFavorites ? const Color(0xFFF43F5E) : AppColors.borderLight,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _addToFavorites ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: _addToFavorites ? const Color(0xFFF43F5E) : AppColors.grey,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _addToFavorites
                          ? '❤️ Motorista Favorito Salvo'
                          : 'Adicionar aos Favoritos',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _addToFavorites ? const Color(0xFFF43F5E) : AppColors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _commentController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Deixe um elogio ou observação (opcional)',
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.grey),
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {
                widget.onSubmit(
                  _score,
                  _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
                  _addToFavorites,
                );
                Navigator.of(context).pop();
              },
              child: const Text('Enviar Avaliação'),
            ),
          ],
        ),
      ),
    );
  }
}
