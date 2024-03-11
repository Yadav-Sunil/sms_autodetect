part of sms_autodetect;

/// Don't forget to set a child foreground color to white
class GradientView extends StatelessWidget {
  final Gradient gradient;
  final Widget child;

  const GradientView({required this.child, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(shaderCallback: gradient.createShader, child: child);
  }
}
