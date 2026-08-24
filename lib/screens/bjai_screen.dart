import 'package:beatjerky/widgets/bjai/bjai_chat_tab.dart';
import 'package:beatjerky/widgets/bjai/bjai_ui.dart';
import 'package:flutter/material.dart';

class BJAI extends StatelessWidget {
  final String? initialPrompt;

  const BJAI({super.key, this.initialPrompt});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bjaiBg,
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: bjaiBg,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              bjaiPurple.withValues(alpha: 0.07),
              bjaiBg,
              bjaiBg,
            ],
            stops: const [0, 0.22, 1],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: BjaiChatTab(initialPrompt: initialPrompt),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: bjaiGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: bjaiPurple.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BJ AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your music assistant',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          bjaiProviderChip(),
        ],
      ),
    );
  }
}
