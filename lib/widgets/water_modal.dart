import 'package:flutter/material.dart';

class WaterModal {
  static void show(BuildContext context) {
    int amount = 250;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.blueGrey[800], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              const Text('Add Water', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _amountButton(setModalState, -50, amount, (v) => amount = v),
                  const SizedBox(width: 20),
                  Column(
                    children: [
                      const Icon(Icons.local_drink_rounded, color: Color(0xFF3ABEF9), size: 48),
                      const SizedBox(height: 8),
                      Text('$amount ml', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(width: 20),
                  _amountButton(setModalState, 50, amount, (v) => amount = v),
                ],
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _quickAdd(setModalState, 250, 'Glass', amount, (v) => amount = v),
                  _quickAdd(setModalState, 500, 'Bottle', amount, (v) => amount = v),
                ],
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3ABEF9),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Save Intake', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _amountButton(StateSetter setModalState, int delta, int current, Function(int) onUpdate) {
    return IconButton(
      onPressed: () => setModalState(() => onUpdate((current + delta).clamp(50, 2000))),
      icon: Icon(delta > 0 ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded, color: Colors.blueGrey, size: 32),
    );
  }

  static Widget _quickAdd(StateSetter setModalState, int val, String label, int current, Function(int) onUpdate) {
    bool isSelected = current == val;
    return GestureDetector(
      onTap: () => setModalState(() => onUpdate(val)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3ABEF9).withOpacity(0.1) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? const Color(0xFF3ABEF9) : Colors.transparent),
        ),
        child: Column(
          children: [
            Text('$val ml', style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFF3ABEF9) : Colors.white)),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.blueGrey[400])),
          ],
        ),
      ),
    );
  }
}
