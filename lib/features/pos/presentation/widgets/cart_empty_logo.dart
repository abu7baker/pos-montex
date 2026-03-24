import 'package:flutter/material.dart';

class CartEmptyLogo extends StatelessWidget {
  const CartEmptyLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth * 0.8;
        return Opacity(
          opacity: 0.8,
          child: Center(
            child: Image.asset(
              'assets/images/logo.jpg',
              width: size,
              fit: BoxFit.contain,
            ),
          ),
        );
      },
    );
  }
}
