// lib/widgets/manual_entry_dialog.dart
import 'package:flutter/material.dart';
import '../database/db_helper.dart';

class ManualEntryDialog extends StatefulWidget {
  final int societyId;
  final Map<String, dynamic>? editRow; // अगर एडिट करना हो तो डेटा आएगा, वरना null

  const ManualEntryDialog({Key? key, required this.societyId, this.editRow}) : super(key: key);

  @override
  _ManualEntryDialogState createState() => _ManualEntryDialogState();
}

class _ManualEntryDialogState extends State<ManualEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _particularsController = TextEditingController();
  final _amountController = TextEditingController();
  
  String _selectedType = 'DEBIT';
  String _selectedHead = 'establishment_expense';

  @override
  void initState() {
    super.initState();
    if (widget.editRow != null) {
      _particularsController.text = widget.editRow!['particulars'];
      _amountController.text = widget.editRow!['amount'].toString();
      _selectedType = widget.editRow!['type'];
      _selectedHead = widget.editRow!['account_head'] ?? 'establishment_expense';
    }
  }

  void _saveData() async {
    if (_formKey.currentState!.validate()) {
      Map<String, dynamic> row = {
        'society_id': widget.societyId,
        'date': DateTime.now().toIso8601String().substring(0, 10), // आज की तारीख YYYY-MM-DD
        'particulars': _particularsController.text,
        'amount': double.parse(_amountController.text),
        'type': _selectedType,
        'category': _selectedType == 'DEBIT' ? 'Expense' : 'Income',
        'doc_type': 'Other',
        'account_head': _selectedHead,
        'is_manual': 1, // हाथ से एंट्री मार्क की गई
      };

      if (widget.editRow == null) {
        // नया जोड़ें
        await DatabaseHelper.instance.insertLedgerEntry(row);
      } else {
        // पुराने को सुधारें
        await DatabaseHelper.instance.updateLedgerEntry(widget.editRow!['id'], row);
      }
      Navigator.pop(context, true); // सफलता के साथ वापस जाएँ
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.editRow == null ? '➕ बिना बिल का नया एंट्री जोड़ें' : '📝 प्रविष्टि संशोधित करें'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextFormField(
                controller: _particularsController,
                decoration: const InputDecoration(labelText: 'विवरण (Particulars)'),
                validator: (v) => v!.isEmpty ? 'विवरण भरना आवश्यक है' : null,
              ),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'राशि (Amount ₹)'),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'राशि भरें' : null,
              ),
              DropdownButtonFormField<String>(
                value: _selectedType,
                items: ['DEBIT', 'CREDIT'].map((t) => DropdownMenuItem(value: t, child: Text(t == 'DEBIT' ? 'व्यय / खर्च (DEBIT)' : 'आय / प्राप्ति (CREDIT)'))).toList(),
                onChanged: (v) => setState(() => _selectedType = v!),
              ),
              DropdownButtonFormField<String>(
                value: _selectedHead,
                items: [
                  DropdownMenuItem(value: 'establishment_expense', child: Text('संस्थापन व्यय (Salary/Office)')),
                  DropdownMenuItem(value: 'miscellaneous_income', child: Text('विविध फुटकर आय')),
                  DropdownMenuItem(value: 'milk_purchase', child: Text('दुग्ध खरीद समायोजन')),
                  DropdownMenuItem(value: 'milk_sales', child: Text('दुग्ध बिक्री समायोजन')),
                ],
                onChanged: (v) => setState(() => _selectedHead = v!),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.editRow != null)
          TextButton(
            onChanged: null,
            child: const Text('हटाएं (Delete)', style: TextStyle(color: Colors.red)),
            onPressed: () async {
              await DatabaseHelper.instance.deleteLedgerEntry(widget.editRow!['id']);
              Navigator.pop(context, true);
            },
          ),
        TextButton(child: const Text('रद्द करें'), onPressed: () => Navigator.pop(context)),
        ElevatedButton(child: const Text('सुरक्षित करें'), onPressed: _saveData),
      ],
    );
  }
}
