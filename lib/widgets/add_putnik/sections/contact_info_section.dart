import 'package:flutter/material.dart';

import '../controllers/form_controller.dart';

/// 📞 Sekcija za kontakt informacije putnika
class ContactInfoSection extends StatelessWidget {
  final AddPutnikFormController controller;

  const ContactInfoSection({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.13),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.phone,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '📞 Kontakt informacije',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16,
                        shadows: [
                          Shadow(
                            offset: Offset(1, 1),
                            blurRadius: 3,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Broj telefona (glavni)
              TextField(
                controller: controller.getController('brojTelefona'),
                decoration: InputDecoration(
                  labelText: controller.formData.tip == 'ucenik'
                      ? '📱 Broj telefona učenika'
                      : '📞 Broj telefona',
                  hintText: '064/123-456',
                  border: const OutlineInputBorder(),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                  errorBorder: const OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.red,
                      width: 2,
                    ),
                  ),
                  prefixIcon: const Icon(
                    Icons.phone,
                    color: Colors.white,
                  ),
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  filled: true,
                  labelStyle: const TextStyle(color: Colors.white70),
                  hintStyle: const TextStyle(color: Colors.white54),
                  errorText: controller.getFieldError('telefon'),
                ),
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.phone,
              ),

              // Brojevi telefona roditelja - samo za učenike
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: controller.formData.tip == 'ucenik'
                    ? Container(
                        key: const ValueKey('parent_contacts'),
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.13),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.family_restroom,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Kontakt podaci roditelja',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                          fontSize: 14,
                                          shadows: [
                                            Shadow(
                                              offset: Offset(1, 1),
                                              blurRadius: 2,
                                              color: Colors.black54,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        'Za hitne situacije',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Telefon oca
                            TextField(
                              controller:
                                  controller.getController('brojTelefonaOca'),
                              decoration: InputDecoration(
                                labelText: 'Broj telefona oca',
                                hintText: '064/123-456',
                                border: const OutlineInputBorder(),
                                focusedBorder: const OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                errorBorder: const OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Colors.red,
                                    width: 2,
                                  ),
                                ),
                                prefixIcon: const Icon(
                                  Icons.man,
                                  color: Colors.white,
                                ),
                                fillColor: Colors.white10,
                                filled: true,
                                labelStyle: const TextStyle(
                                  color: Colors.white70,
                                ),
                                hintStyle: const TextStyle(
                                  color: Colors.white54,
                                ),
                                errorText:
                                    controller.getFieldError('telefonOca'),
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                              ),
                              keyboardType: TextInputType.phone,
                            ),

                            const SizedBox(height: 8),

                            // Telefon majke
                            TextField(
                              controller:
                                  controller.getController('brojTelefonaMajke'),
                              decoration: InputDecoration(
                                labelText: 'Broj telefona majke',
                                hintText: '065/789-012',
                                border: const OutlineInputBorder(),
                                focusedBorder: const OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                errorBorder: const OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Colors.red,
                                    width: 2,
                                  ),
                                ),
                                prefixIcon: const Icon(
                                  Icons.woman,
                                  color: Colors.white,
                                ),
                                fillColor: Colors.white10,
                                filled: true,
                                labelStyle: const TextStyle(
                                  color: Colors.white70,
                                ),
                                hintStyle: const TextStyle(
                                  color: Colors.white54,
                                ),
                                errorText:
                                    controller.getFieldError('telefonMajke'),
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                              ),
                              keyboardType: TextInputType.phone,
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }
}
