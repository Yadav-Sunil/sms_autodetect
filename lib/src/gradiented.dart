part of sms_autodetect;

/// Don't forget to set a child foreground color to white
class Gradiented extends StatelessWidget {
  final Gradient gradient;
  final Widget child;

  const Gradiented({required this.child, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(shaderCallback: gradient.createShader, child: child);
  }
}
