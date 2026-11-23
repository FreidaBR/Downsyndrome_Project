import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/app_state.dart';
import '../widgets/glass_container.dart';
import '../widgets/custom_cursor.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  String _selectedMood = 'curious';

  final List<String> _moods = [
    'Joyful',
    'Calm',
    'Curious',
    'Adventurous',
    'Tired',
    'Silly',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final state = context.read<LuminaAppState>();
      state.submitOnboarding(
        name: _nameController.text.trim(),
        age: _ageController.text.trim(),
        mood: _selectedMood,
      );
      state.setScreen('companion_select');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LuminaAppState>();
    final isDark = state.themeMode == LuminaThemeMode.dark;

    final Color textColor = isDark ? LuminaColors.darkText : LuminaColors.lightText;
    final Color mutedColor = isDark ? LuminaColors.darkMuted : LuminaColors.lightMuted;
    final String themeLabel = isDark ? 'Candy Land' : 'Space Mode';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: GlassContainer(
          width: 440.0,
          padding: const EdgeInsets.symmetric(horizontal: 44.0, vertical: 48.0),
          isDark: isDark,
          borderRadius: BorderRadius.circular(30.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: InteractiveCursorRegion(
                    child: TextButton(
                      onPressed: () => state.toggleTheme(),
                      style: TextButton.styleFrom(
                        backgroundColor: isDark ? LuminaColors.darkSurfaceB : LuminaColors.lightSurfaceB,
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50.0)),
                      ),
                      child: Text(
                        themeLabel,
                        style: LuminaTypography.sans(
                          fontSize: 11.0,
                          fontWeight: FontWeight.w500,
                          color: isDark ? LuminaColors.darkText : LuminaColors.lightText,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18.0),
                // Title
                Text(
                  'Hello there',
                  style: LuminaTypography.heroFont(
                    isDark,
                    fontSize: isDark ? 22.0 : 30.0,
                    fontWeight: FontWeight.w300,
                    color: textColor,
                    letterSpacing: isDark ? 0.06 * 22.0 : 0.0,
                  ),
                ),
                const SizedBox(height: 5.0),
                
                // Subtitle
                Text(
                  'Tell Lumina a little about you',
                  style: LuminaTypography.sans(
                    fontSize: 13.0,
                    color: mutedColor,
                  ),
                ),
                
                const SizedBox(height: 28.0),

                // Name Input Label
                Text(
                  'YOUR NAME',
                  style: LuminaTypography.sans(
                    fontSize: 10.0,
                    fontWeight: FontWeight.w500,
                    color: mutedColor,
                    letterSpacing: 0.16 * 10.0,
                  ),
                ),
                const SizedBox(height: 6.0),
                
                // Name Input Field
                TextFormField(
                  controller: _nameController,
                  maxLength: 28,
                  style: LuminaTypography.sans(fontSize: 14.0, color: textColor),
                  decoration: _inputDecoration(
                    hint: 'What should Lumina call you?',
                    isDark: isDark,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please tell Lumina your name.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16.0),

                // Age Input Label
                Text(
                  'HOW OLD ARE YOU?',
                  style: LuminaTypography.sans(
                    fontSize: 10.0,
                    fontWeight: FontWeight.w500,
                    color: mutedColor,
                    letterSpacing: 0.16 * 10.0,
                  ),
                ),
                const SizedBox(height: 6.0),
                
                // Age Input Field
                TextFormField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  style: LuminaTypography.sans(fontSize: 14.0, color: textColor),
                  decoration: _inputDecoration(
                    hint: 'Your age',
                    isDark: isDark,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please specify your age.';
                    }
                    final age = int.tryParse(value);
                    if (age == null || age < 3 || age > 17) {
                      return 'Age must be between 3 and 17.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16.0),

                // Mood Label
                Text(
                  'HOW ARE YOU FEELING?',
                  style: LuminaTypography.sans(
                    fontSize: 10.0,
                    fontWeight: FontWeight.w500,
                    color: mutedColor,
                    letterSpacing: 0.16 * 10.0,
                  ),
                ),
                const SizedBox(height: 12.0),
                
                // Mood Pills Wrap
                Wrap(
                  spacing: 6.0,
                  runSpacing: 8.0,
                  children: _moods.map((mood) {
                    final isSelected = _selectedMood == mood.toLowerCase();
                    return _MoodPill(
                      label: mood,
                      isSelected: isSelected,
                      isDark: isDark,
                      onTap: () {
                        setState(() {
                          _selectedMood = mood.toLowerCase();
                        });
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 32.0),

                // Submit Button
                InteractiveCursorRegion(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(50.0),
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? LuminaColors.darkBtnSh : LuminaColors.lightBtnSh,
                          blurRadius: 14.0,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(50.0),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _submitForm,
                          splashColor: Colors.white24,
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: isDark
                                  ? LuminaColors.btnGradientDark
                                  : LuminaColors.btnGradientLight,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Choose your companion',
                                    style: LuminaTypography.sans(
                                      fontSize: 13.0,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                      letterSpacing: 0.07 * 13.0,
                                    ),
                                  ),
                                  const SizedBox(width: 9.0),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    color: Colors.white,
                                    size: 14.0,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, required bool isDark}) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(13.0),
      borderSide: BorderSide(
        color: isDark ? LuminaColors.darkInBorder : LuminaColors.lightInBorder,
        width: 1.0,
      ),
    );
    final focusBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(13.0),
      borderSide: BorderSide(
        color: isDark ? LuminaColors.darkA1 : LuminaColors.lightA1,
        width: 1.5,
      ),
    );

    return InputDecoration(
      hintText: hint,
      hintStyle: LuminaTypography.sans(
        fontSize: 14.0,
        color: (isDark ? LuminaColors.darkMuted : LuminaColors.lightMuted).withValues(alpha: 0.55),
      ),
      counterText: "",
      filled: true,
      fillColor: isDark ? LuminaColors.darkInBg : LuminaColors.lightInBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      border: border,
      enabledBorder: border,
      focusedBorder: focusBorder,
      errorStyle: LuminaTypography.sans(fontSize: 12.0, color: Colors.redAccent),
    );
  }
}

class _MoodPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _MoodPill({
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeGradient = isDark ? LuminaColors.btnGradientDark : LuminaColors.btnGradientLight;

    return InteractiveCursorRegion(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 6.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50.0),
            gradient: isSelected ? activeGradient : null,
            color: isSelected ? null : (isDark ? LuminaColors.darkInBg : LuminaColors.lightInBg),
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : (isDark ? LuminaColors.darkInBorder : LuminaColors.lightInBorder),
              width: 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: isDark ? LuminaColors.darkBtnSh : LuminaColors.lightBtnSh,
                      blurRadius: 14.0,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          transform: isSelected ? (Matrix4.identity()..translateByDouble(0.0, -2.0, 0.0, 1.0)) : Matrix4.identity(),
          child: Text(
            label,
            style: LuminaTypography.sans(
              fontSize: 12.0,
              fontWeight: FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : (isDark ? LuminaColors.darkText : LuminaColors.lightText),
            ),
          ),
        ),
      ),
    );
  }
}
